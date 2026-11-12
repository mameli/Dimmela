import Foundation

/// A named Provider the user configured in Settings. Post-processing uses the selected one. The
/// API key is not stored here: it lives in the Keychain, under the profile's identifier.
public struct ProviderProfile: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: UUID
    /// As the user wrote it; may be empty (see `displayName`).
    public var name: String
    public var provider: Provider
    /// Tried, in the list's order, when the profile in use fails even after its Retries.
    public var isFallback: Bool

    public init(id: UUID = UUID(), name: String, provider: Provider, isFallback: Bool = false) {
        self.id = id
        self.name = name
        self.provider = provider
        self.isFallback = isFallback
    }

    private enum CodingKeys: String, CodingKey { case id, name, provider, isFallback }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        provider = try container.decode(Provider.self, forKey: .provider)
        isFallback = try container.decodeIfPresent(Bool.self, forKey: .isFallback) ?? false
    }

    /// The name, or what the address says when the user left it empty.
    public var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        return Self.name(for: provider.baseURL) ?? "New Profile"
    }

    /// The servers people commonly use, to start a profile in one click. Model left empty where
    /// it changes too often to suggest one.
    public static let presets: [ProviderProfile] = [
        ProviderProfile(name: "OpenRouter", provider: .openRouter),
        ProviderProfile(name: "Ollama", provider: Provider(baseURL: "http://localhost:11434/v1", model: "")),
    ]

    /// The servers named when a Provider of 0.1.7 becomes a profile: the presets, and the ones
    /// that are no longer offered.
    private static let knownServers: [ProviderProfile] = presets + [
        ProviderProfile(name: "OpenAI", provider: Provider(baseURL: "https://api.openai.com/v1", model: "")),
        ProviderProfile(name: "Mistral", provider: Provider(baseURL: "https://api.mistral.ai/v1", model: "")),
        ProviderProfile(name: "LM Studio", provider: Provider(baseURL: "http://localhost:1234/v1", model: "")),
    ]

    /// A copy of a preset with an identifier of its own.
    public func copy() -> ProviderProfile {
        ProviderProfile(name: name, provider: provider)
    }

    /// The single Provider of Dimmela up to 0.1.7, as the first profile: named after its server.
    public static func migrating(_ provider: Provider) -> ProviderProfile {
        ProviderProfile(name: name(for: provider.baseURL) ?? "Provider", provider: provider)
    }

    /// The name of a known server, else its host; nil without one.
    static func name(for baseURL: String) -> String? {
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces)), let host = url.host()?.lowercased(), !host.isEmpty
        else { return nil }
        if let preset = knownServers.first(where: { preset in
            URL(string: preset.provider.baseURL).map { $0.host() == host && $0.port == url.port } ?? false
        }) {
            return preset.name
        }
        return host
    }
}

/// The profiles in the user's order and the one Post-processing uses, as saved in UserDefaults:
/// one JSON string, so `@AppStorage` can hold it.
public struct ProviderProfiles: Codable, Equatable, Sendable, RawRepresentable {
    public var all: [ProviderProfile]
    /// nil when there are no profiles.
    public var selectedID: UUID?

    public init(all: [ProviderProfile] = [], selectedID: UUID? = nil) {
        self.all = all
        self.selectedID = selectedID
    }

    /// The profile Post-processing uses: the selected one, else the first.
    public var selected: ProviderProfile? {
        all.first { $0.id == selectedID } ?? all.first
    }

    /// The profiles Post-processing tries, in order: the selected one, then the fallback ones in
    /// the list's order.
    public var chain: [ProviderProfile] {
        guard let selected else { return [] }
        return [selected] + all.filter { $0.isFallback && $0.id != selected.id }
    }

    public mutating func add(_ profile: ProviderProfile) {
        all.append(profile)
        if selectedID == nil { selectedID = profile.id }
    }

    /// Removes the profile; if it was selected, the first one left takes its place.
    public mutating func remove(_ id: UUID) {
        all.removeAll { $0.id == id }
        if selectedID == id || !all.contains(where: { $0.id == selectedID }) { selectedID = all.first?.id }
    }

    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.sorted().map { all[$0] }
        var rest = all.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let index = destination - source.filter { $0 < destination }.count
        rest.insert(contentsOf: moving, at: min(max(index, 0), rest.count))
        all = rest
    }

    // Written out: for a RawRepresentable type, Codable would go through `rawValue`, which
    // encodes with Codable, forever.
    private enum CodingKeys: String, CodingKey { case all, selectedID }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        all = try container.decode([ProviderProfile].self, forKey: .all)
        selectedID = try container.decodeIfPresent(UUID.self, forKey: .selectedID)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(all, forKey: .all)
        try container.encodeIfPresent(selectedID, forKey: .selectedID)
    }

    public init?(rawValue: String) {
        guard let decoded = try? JSONDecoder().decode(Self.self, from: Data(rawValue.utf8)) else { return nil }
        self = decoded
    }

    public var rawValue: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }
}
