import AppKit
import ApplicationServices
import os

private let logger = Logger(subsystem: "app.dimmela.Dimmela", category: "shortcut")

/// Watches the keyboard for the Dictation shortcut, `fn+space` (with or without `shift`), through
/// a CGEventTap: Carbon hot keys cannot see `fn` or the key release. The shortcut's own key
/// events are swallowed so no space reaches the frontmost app. Needs Accessibility, which the
/// paste needs anyway.
@MainActor
final class ShortcutMonitor {
    /// `shift` held at the press; time in seconds since boot.
    var onDown: (_ shift: Bool, _ time: TimeInterval) -> Void = { _, _ in }
    var onUp: (_ time: TimeInterval) -> Void = { _ in }

    private static let space: Int64 = 49

    private var tap: CFMachPort?
    /// The shortcut's space is down: its repeats and release belong to Dimmela.
    private var spaceHeld = false

    var isRunning: Bool { tap != nil }

    /// Starts watching; false while Accessibility is not granted.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)
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
            onDown(flags.contains(.maskShift), Self.seconds(event))
            return true
        case .keyUp where spaceHeld && event.getIntegerValueField(.keyboardEventKeycode) == Self.space:
            // Whatever the modifiers now: `fn` may already be up.
            spaceHeld = false
            onUp(Self.seconds(event))
            return true
        default:
            return false
        }
    }

    private static func seconds(_ event: CGEvent) -> TimeInterval {
        TimeInterval(event.timestamp) / 1_000_000_000
    }
}
