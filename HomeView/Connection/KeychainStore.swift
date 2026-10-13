import Foundation
import Security

struct Credentials: Equatable {
    var user: String
    var password: String
}

/// Keeps one DVR login in the macOS Keychain as a generic password
/// (service = `service`, account = user, data = password).
///
/// Calls can block while macOS asks the person to allow access (expected
/// after a rebuild, since the ad-hoc signature changes), so they belong off
/// view bodies.
struct KeychainStore {
    struct Error: Swift.Error, Equatable {
        let status: OSStatus
    }

    static let defaultService = "com.carloseduardo.HomeView"

    var service = KeychainStore.defaultService

    /// Replaces any saved login with this one.
    func save(_ credentials: Credentials) throws {
        try delete()
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrLabel as String: service,
            kSecAttrAccount as String: credentials.user,
            kSecValueData as String: Data(credentials.password.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw Error(status: status) }
    }

    /// The saved login, or `nil` when there is none.
    func read() throws -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let item = result as? [String: Any],
              let user = item[kSecAttrAccount as String] as? String,
              let data = item[kSecValueData as String] as? Data,
              let password = String(data: data, encoding: .utf8)
        else { throw Error(status: status == errSecSuccess ? errSecDecode : status) }
        return Credentials(user: user, password: password)
    }

    /// Removes the saved login; does nothing when there is none.
    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Error(status: status) }
    }
}
