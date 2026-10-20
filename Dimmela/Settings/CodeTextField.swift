import AppKit
import SwiftUI

/// Text field for code such as JSON: monospaced, with no smart quotes, smart dashes or text
/// replacements, which SwiftUI's TextField takes from the system settings.
struct CodeTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        // Same look as SwiftUI fields in a grouped Form: borderless.
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        field.lineBreakMode = .byTruncatingTail
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        // The field editor is shared by every field of the window: set it each time editing starts.
        func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
            if let editor = fieldEditor as? NSTextView {
                // With the system's smart quotes, a typed " becomes “ and the JSON is no longer valid.
                editor.isAutomaticQuoteSubstitutionEnabled = false
                editor.isAutomaticDashSubstitutionEnabled = false
                editor.isAutomaticTextReplacementEnabled = false
            }
            return true
        }

        // Other fields get the user's system settings back.
        func controlTextDidEndEditing(_ notification: Notification) {
            guard let editor = notification.userInfo?["NSFieldEditor"] as? NSTextView else { return }
            editor.isAutomaticQuoteSubstitutionEnabled = NSSpellChecker.isAutomaticQuoteSubstitutionEnabled
            editor.isAutomaticDashSubstitutionEnabled = NSSpellChecker.isAutomaticDashSubstitutionEnabled
            editor.isAutomaticTextReplacementEnabled = NSSpellChecker.isAutomaticTextReplacementEnabled
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}
