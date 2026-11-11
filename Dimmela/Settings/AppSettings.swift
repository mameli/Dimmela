import DimmelaCore
import Foundation

/// The keys of Dimmela's settings in UserDefaults, shared by the code and the `@AppStorage`
/// of the views.
enum AppSettings {
    /// The Provider profiles and the selected one, as `ProviderProfiles` JSON.
    static let providerProfilesKey = "providerProfiles"
    // The single Provider of 0.1.7, read once to migrate it and left for an older version.
    private static let legacyBaseURLKey = "providerBaseURL"
    private static let legacyModelKey = "providerModel"
    private static let legacyReasoningKey = "providerReasoning"
    private static let legacyExtraParametersKey = "providerExtraParameters"
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
    /// A `SpeechModelChoice` raw value; v3 when missing.
    static let speechModelKey = "speechModel"
    /// Off unless the user turns it on: the Post-processing log holds what they dictate.
    static let keepsPostProcessingLogKey = "keepsPostProcessingLog"

    private static var defaults: UserDefaults { .standard }

    /// The values a setting has before the user changes it. Called once at launch.
    static func registerDefaults() {
        defaults.register(defaults: [checkForUpdatesKey: true])
    }

    static var checkForUpdates: Bool { defaults.bool(forKey: checkForUpdatesKey) }

    static var keepsPostProcessingLog: Bool { defaults.bool(forKey: keepsPostProcessingLogKey) }

    /// Each Post-processing as one line of JSON, to improve the Modes' prompts: next to the
    /// Vocabulary, where the user edits their own files. Two files of 512 KB at most.
    static let postProcessingLog = LogFile(url: URL.homeDirectory.appending(path: ".dimmela/post-processing.jsonl"))

    static var providerProfiles: ProviderProfiles {
        get { defaults.string(forKey: providerProfilesKey).flatMap(ProviderProfiles.init(rawValue:)) ?? ProviderProfiles() }
        set { defaults.set(newValue.rawValue, forKey: providerProfilesKey) }
    }

    /// The profile Post-processing uses.
    static var selectedProviderProfile: ProviderProfile? { providerProfiles.selected }

    /// Once, at the first launch of a version with profiles: the Provider set up until then
    /// becomes the first profile, with its key; a new install gets an OpenRouter profile waiting
    /// for its key, as the single Provider did.
    static func migrateProviderIfNeeded() {
        guard defaults.string(forKey: providerProfilesKey) == nil else { return }
        let legacyKey = Keychain.legacyAPIKey
        let wasSetUp = legacyKey != nil || defaults.string(forKey: legacyBaseURLKey) != nil
        let profile = wasSetUp ? ProviderProfile.migrating(Provider(
            baseURL: defaults.string(forKey: legacyBaseURLKey) ?? Provider.openRouter.baseURL,
            model: defaults.string(forKey: legacyModelKey) ?? Provider.openRouter.model,
            reasoning: defaults.string(forKey: legacyReasoningKey).flatMap(Provider.ReasoningEffort.init(rawValue:)),
            extraParameters: defaults.string(forKey: legacyExtraParametersKey).flatMap { $0.isEmpty ? nil : $0 }
        )) : ProviderProfile.presets[0].copy()
        if let legacyKey { try? Keychain.setAPIKey(legacyKey, for: profile.id) }
        providerProfiles = ProviderProfiles(all: [profile], selectedID: profile.id)
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

    /// The built-in Modes' folder, next to the Vocabulary: the user edits them as their own.
    static let builtInModesFolder = URL.homeDirectory.appending(path: ".dimmela/modes")
    private static let builtInModesInstalledKey = "builtInModesInstalled"

    /// At every launch. The first time, the built-in Modes are written, their folder becomes a
    /// Mode source and they are enabled after the user's own Modes, whose digits do not change;
    /// later, the files Dimmela wrote get the current prompts (see `BuiltInModes`).
    static func installBuiltInModes() throws {
        let firstTime = !defaults.bool(forKey: builtInModesInstalledKey)
        try BuiltInModes.install(in: builtInModesFolder, firstTime: firstTime)
        guard firstTime else { return }
        defaults.set(true, forKey: builtInModesInstalledKey)
        let folder = builtInModesFolder.standardizedFileURL.path(percentEncoded: false)
        let trimmed = { (path: String) in path.hasSuffix("/") ? String(path.dropLast()) : path }
        if !modeSources.contains(where: { trimmed($0) == folder }) { modeSources.append(folder) }
        let names = Set(BuiltInModes.files.map(\.name))
        let builtIn = ModeCatalog.modes(in: [builtInModesFolder]).filter { names.contains($0.url.lastPathComponent) }
        enabledModes += builtIn.filter { !enabledModes.contains($0) }
    }

    /// The Modes found in the Mode sources now.
    static var availableModes: [Mode] {
        ModeCatalog.modes(in: modeSources.map { URL(fileURLWithPath: $0, isDirectory: true) })
    }
}
