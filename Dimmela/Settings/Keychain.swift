import Foundation
import Security

/// The Provider profiles' API keys, in the macOS Keychain (never in files or UserDefaults), one
/// per profile under its identifier.
enum Keychain {
    private static let service = "app.dimmela.Dimmela"
    /// Where the key of the single Provider was kept up to 0.1.7: read once to migrate it, and
    /// left in place for an older version still installed.
    private static let legacyAccount = "provider-api-key"

    static func apiKey(for profile: UUID) -> String? {
        read(account: profile.uuidString)
    }

    static var legacyAPIKey: String? {
        read(account: legacyAccount)
    }

    /// Saves the key, or deletes it if empty. The previous key stays until the new one is
    /// saved: if saving fails, both are not lost.
    static func setAPIKey(_ key: String, for profile: UUID) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            deleteAPIKey(for: profile)
            return
        }
        let query = baseQuery(account: profile.uuidString)
        let data = Data(trimmed.utf8)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrLabel as String] = "Dimmela: provider API key"
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    static func deleteAPIKey(for profile: UUID) {
        SecItemDelete(baseQuery(account: profile.uuidString) as CFDictionary)
    }

    private static func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

struct KeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        "Keychain: " + (SecCopyErrorMessageString(status, nil) as String? ?? "code \(status)")
    }
}
