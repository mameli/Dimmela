import DimmelaCore
import Foundation

/// The keys of Dimmela's settings in UserDefaults, shared by the code and the `@AppStorage`
/// of the views.
enum AppSettings {
    static let providerBaseURLKey = "providerBaseURL"
    static let providerModelKey = "providerModel"
    /// Folder paths, one per Mode source, one per line.
    static let modeSourcesKey = "modeSources"
    /// The enabled Modes' identifiers, in the user's order, one per line.
    static let enabledModesKey = "enabledModes"
    static let defaultModeKey = "defaultMode"
    /// Where the Vocabulary was kept before it moved to a file; copied into the file when it is
    /// created, and left in place for older versions still installed.
    private static let legacyVocabularyKey = "vocabulary"
    /// Set when the user closes the welcome window with Done.
    static let onboardingDoneKey = "onboardingDone"
    static let checkForUpdatesKey = "checkForUpdates"
    /// The app chosen to edit the Vocabulary file, by path; empty for the system's default.
    static let vocabularyEditorKey = "vocabularyEditor"

    private static var defaults: UserDefaults { .standard }

    /// The values a setting has before the user changes it. Called once at launch.
    static func registerDefaults() {
        defaults.register(defaults: [checkForUpdatesKey: true])
    }

    static var checkForUpdates: Bool { defaults.bool(forKey: checkForUpdatesKey) }

    static var provider: Provider {
        Provider(
            baseURL: defaults.string(forKey: providerBaseURLKey) ?? Provider.openRouter.baseURL,
            model: defaults.string(forKey: providerModelKey) ?? Provider.openRouter.model
        )
    }

    // Lists are stored one item per line: `@AppStorage` then works with them as plain strings.

    static var modeSources: [String] {
        get { lines(modeSourcesKey) }
        set { defaults.set(newValue.joined(separator: "\n"), forKey: modeSourcesKey) }
    }

    static var enabledModes: [Mode] {
        get { lines(enabledModesKey).map(Mode.init(id:)) }
        set { defaults.set(newValue.map(\.id).joined(separator: "\n"), forKey: enabledModesKey) }
    }

    static func lines(_ key: String) -> [String] {
        lines(of: defaults.string(forKey: key) ?? "")
    }

    static func lines(of stored: String) -> [String] {
        stored.split(separator: "\n").map(String.init)
    }

    /// The Default Mode, if it is still enabled. Set from the menu, Settings, or by choosing a
    /// Mode during a Dictation.
    static var defaultMode: Mode? {
        get {
            guard let id = defaults.string(forKey: defaultModeKey), !id.isEmpty else { return nil }
            return enabledModes.first { $0.id == id }
        }
        set { defaults.set(newValue?.id ?? "", forKey: defaultModeKey) }
    }

    /// The Vocabulary file, one `- term = variants | description` per line, edited in any editor.
    static var vocabularyFile: URL {
        URL.homeDirectory.appending(path: ".dimmela/vocabulary.md")
    }

    /// Read at every Dictation, so edits apply at once.
    static var vocabulary: Vocabulary {
        Vocabulary(text: (try? String(contentsOf: vocabularyFile, encoding: .utf8)) ?? "")
    }

    /// Creates the Vocabulary file if it is missing, with the entries once written in Settings.
    static func createVocabularyFileIfNeeded() throws {
        let path = vocabularyFile.path(percentEncoded: false)
        guard !FileManager.default.fileExists(atPath: path) else { return }
        try FileManager.default.createDirectory(at: vocabularyFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        let legacy = defaults.string(forKey: legacyVocabularyKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let text = Vocabulary.fileTemplate + (legacy.isEmpty ? "" : legacy + "\n")
        try text.write(to: vocabularyFile, atomically: true, encoding: .utf8)
    }

    /// The Modes found in the Mode sources now.
    static var availableModes: [Mode] {
        ModeCatalog.modes(in: modeSources.map { URL(fileURLWithPath: $0, isDirectory: true) })
    }
}
