import AppKit
import ApplicationServices
import os

private let logger = Logger(subsystem: "app.dimmela.Dimmela", category: "shortcut")

/// Watches the keyboard for the Dictation shortcut, `fn+space`, and while a Dictation is in
/// progress for `Esc`, the digits, `shift`, the arrows and `Return`, through
/// a CGEventTap: Carbon hot keys cannot see `fn` or the key release. The shortcut's own key
/// events are swallowed so no space reaches the frontmost app. Needs Accessibility, which the
/// paste needs anyway.
@MainActor
final class ShortcutMonitor {
    /// Time in seconds since boot.
    var onDown: (_ time: TimeInterval) -> Void = { _ in }
    var onUp: (_ time: TimeInterval) -> Void = { _ in }
    var onEscape: () -> Void = {}
    /// Whether `Esc` cancels a Dictation now; otherwise it goes to the frontmost app.
    var capturesEscape: () -> Bool = { false }
    var onDigit: (Int) -> Void = { _ in }
    /// Whether the digit keys choose a Mode now; otherwise they go to the frontmost app.
    var capturesDigits: () -> Bool = { false }
    /// `shift` went down (its release is of no interest).
    var onShift: () -> Void = {}
    /// ↑ is -1, ↓ is +1.
    var onArrow: (_ offset: Int) -> Void = { _ in }
    var onReturn: () -> Void = {}
    /// Whether the arrows and `Return` move through the Mode list now.
    var capturesModeListKeys: () -> Bool = { false }

    private static let space: Int64 = 49
    private static let escape: Int64 = 53
    private static let arrows: [Int64: Int] = [126: -1, 125: 1]
    /// Return and the keypad's Enter.
    private static let returns: Set<Int64> = [36, 76]
    /// The digit keys of the top row, by key code (the same position on every layout).
    private static let digits: [Int64: Int] = [29: 0, 18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9]

    private var tap: CFMachPort?
    /// The shortcut's space is down: its repeats and release belong to Dimmela.
    private var spaceHeld = false
    /// `Esc` went down as Dimmela's: its release must not reach the frontmost app alone.
    private var escapeHeld = false
    /// Digit keys that went down as Dimmela's: their releases are swallowed too.
    private var digitsHeld: Set<Int64> = []
    /// Arrow and Return keys that went down as Dimmela's.
    private var listKeysHeld: Set<Int64> = []
    private var isShiftDown = false

    var isRunning: Bool { tap != nil }

    /// Starts watching; false while Accessibility is not granted.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, monitor in
                // The tap is on the main run loop.
                let swallow = MainActor.assumeIsolated {
                    Unmanaged<ShortcutMonitor>.fromOpaque(monitor!).takeUnretainedValue().swallows(type, event)
                }
                return swallow ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logger.info("Event tap refused: Accessibility not granted yet")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        logger.info("Watching fn+space")
        return true
    }

    /// Whether the event is the shortcut's own and must not reach the frontmost app.
    private func swallows(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS turns a slow or interrupted tap off; turn it back on.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .keyDown where event.getIntegerValueField(.keyboardEventKeycode) == Self.space:
            if spaceHeld { return true }  // key repeat while held
            let flags = event.flags
            guard flags.contains(.maskSecondaryFn),
                  flags.isDisjoint(with: [.maskCommand, .maskControl, .maskAlternate])
            else { return false }
            spaceHeld = true
            onDown(Self.seconds(event))
            return true
        case .keyUp where spaceHeld && event.getIntegerValueField(.keyboardEventKeycode) == Self.space:
            // Whatever the modifiers now: `fn` may already be up.
            spaceHeld = false
            onUp(Self.seconds(event))
            return true
        case .keyDown where event.getIntegerValueField(.keyboardEventKeycode) == Self.escape:
            guard escapeHeld || capturesEscape() else { return false }
            if !escapeHeld {
                escapeHeld = true
                onEscape()
            }
            return true
        case .keyUp where escapeHeld && event.getIntegerValueField(.keyboardEventKeycode) == Self.escape:
            escapeHeld = false
            return true
        case .keyDown where Self.digits[event.getIntegerValueField(.keyboardEventKeycode)] != nil:
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            guard digitsHeld.contains(code) || capturesDigits() else { return false }
            if digitsHeld.insert(code).inserted { onDigit(Self.digits[code]!) }
            return true
        case .keyUp where digitsHeld.contains(event.getIntegerValueField(.keyboardEventKeycode)):
            digitsHeld.remove(event.getIntegerValueField(.keyboardEventKeycode))
            return true
        case .keyDown where Self.arrows[event.getIntegerValueField(.keyboardEventKeycode)] != nil
            || Self.returns.contains(event.getIntegerValueField(.keyboardEventKeycode)):
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            guard listKeysHeld.contains(code) || capturesModeListKeys() else { return false }
            listKeysHeld.insert(code)
            // Arrows repeat while held, to run down the list.
            if let offset = Self.arrows[code] {
                onArrow(offset)
            } else if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                onReturn()
            }
            return true
        case .keyUp where listKeysHeld.contains(event.getIntegerValueField(.keyboardEventKeycode)):
            listKeysHeld.remove(event.getIntegerValueField(.keyboardEventKeycode))
            return true
        case .flagsChanged:
            let shift = event.flags.contains(.maskShift)
            if shift && !isShiftDown { onShift() }
            isShiftDown = shift
            return false
        default:
            return false
        }
    }

    private static func seconds(_ event: CGEvent) -> TimeInterval {
        TimeInterval(event.timestamp) / 1_000_000_000
    }
}
