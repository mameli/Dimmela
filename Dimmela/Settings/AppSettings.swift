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
    /// The Vocabulary as the user writes it: one `- term = variants | description` per line.
    static let vocabularyKey = "vocabulary"
    /// Set when the user closes the welcome window with Done.
    static let onboardingDoneKey = "onboardingDone"

    private static var defaults: UserDefaults { .standard }

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

    /// The Default Mode, if it is still enabled.
    static var defaultMode: Mode? {
        guard let id = defaults.string(forKey: defaultModeKey), !id.isEmpty else { return nil }
        return enabledModes.first { $0.id == id }
    }

    static var vocabulary: Vocabulary {
        Vocabulary(text: defaults.string(forKey: vocabularyKey) ?? "")
    }

    /// The Modes found in the Mode sources now.
    static var availableModes: [Mode] {
        ModeCatalog.modes(in: modeSources.map { URL(fileURLWithPath: $0, isDirectory: true) })
    }
}
