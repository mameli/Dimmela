import AppKit
import ApplicationServices

/// Puts text in the frontmost app by pasting it: the text goes on the pasteboard, ⌘V is
/// posted, then the pasteboard gets back what it held before. Posting keystrokes needs
/// Accessibility.
@MainActor
enum Paster {
    enum Failure: Error, CustomStringConvertible {
        case accessibilityMissing

        var description: String {
            "Dimmela needs Accessibility to paste (System Settings › Privacy & Security › Accessibility)."
        }
    }

    private static let vKey: CGKeyCode = 9
    /// Tells clipboard managers not to record the text, which only passes through.
    private static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    static func paste(_ text: String) async throws {
        guard AXIsProcessTrusted() else { throw Failure.accessibilityMissing }
        let pasteboard = NSPasteboard.general
        let saved = snapshot(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setData(Data(), forType: transient)
        try? await Task.sleep(for: .milliseconds(60))

        let source = CGEventSource(stateID: .combinedSessionState)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: keyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }

        // The app reads the pasteboard when it handles ⌘V, not when it is posted.
        try? await Task.sleep(for: .milliseconds(300))
        pasteboard.clearContents()
        if !saved.isEmpty { pasteboard.writeObjects(saved) }
    }

    /// A copy of every item on the pasteboard, in every type it offers.
    private static func snapshot(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }
}
