import Foundation
import Security

/// Keeps provider API keys and the Copilot OAuth token in the login keychain.
///
/// Everything lives in a single generic-password item, so after an app update
/// macOS asks for keychain access at most once rather than once per secret.
enum CredentialStore {
    struct Credentials: Codable, Equatable {
        var openAIKey = ""
        var anthropicKey = ""
        var copilotOAuthToken = ""

        var isEmpty: Bool { openAIKey.isEmpty && anthropicKey.isEmpty && copilotOAuthToken.isEmpty }
    }

    enum StoreError: Error, CustomStringConvertible {
        case keychain(OSStatus)

        var description: String {
            switch self {
            case .keychain(let status):
                let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
                return "Keychain error: \(message)"
            }
        }
    }

    private static let service = "com.neelspeak.app"
    private static let account = "cloud-cleanup-credentials"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    /// The stored credentials, or nil when nothing has been saved yet.
    static func load() throws -> Credentials? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw StoreError.keychain(status) }
        return try JSONDecoder().decode(Credentials.self, from: data)
    }

    static func save(_ credentials: Credentials) throws {
        if credentials.isEmpty {
            let status = SecItemDelete(baseQuery as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw StoreError.keychain(status) }
            return
        }
        let data = try JSONEncoder().encode(credentials)
        let update: [String: Any] = [kSecValueData as String: data]
        var status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery
            add[kSecValueData as String] = data
            add[kSecAttrLabel as String] = "NeelSpeak cleanup credentials"
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw StoreError.keychain(status) }
    }
}
