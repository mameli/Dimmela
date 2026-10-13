import Foundation
import Security

/// The provider's API key, in the macOS Keychain (never in files or UserDefaults).
enum Keychain {
    private static let service = "app.dimmela.Dimmela"
    private static let account = "provider-api-key"

    static var apiKey: String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Saves the key, or deletes it if empty. The previous key stays until the new one is
    /// saved: if saving fails, both are not lost.
    static func setAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            SecItemDelete(baseQuery as CFDictionary)
            return
        }
        let data = Data(trimmed.utf8)
        var status = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = baseQuery
            item[kSecValueData as String] = data
            item[kSecAttrLabel as String] = "Dimmela: provider API key"
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    private static var baseQuery: [String: Any] {
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
