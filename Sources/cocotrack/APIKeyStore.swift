import Foundation
import Security

/// Decides how a stored API key is resolved at launch and whether the legacy
/// plaintext copy in `UserDefaults` may be removed.
///
/// Kept as a pure value type so the migration can be tested without touching the
/// real Keychain. The rule that matters: the legacy copy is the user's only
/// credential until the Keychain write is *confirmed*, so it must never be
/// deleted on an unverified write.
struct ResolvedAPIKey: Equatable {
    let apiKey: String
    let removeLegacyKey: Bool
    let keychainWriteFailed: Bool
}

enum APIKeyMigration {
    static func resolve(
        keychainKey: String?,
        legacyKey: String?,
        saveToKeychain: (String) -> Bool
    ) -> ResolvedAPIKey {
        if let keychainKey, !keychainKey.isEmpty {
            // Keychain already holds the credential; the legacy copy is redundant.
            return ResolvedAPIKey(
                apiKey: keychainKey,
                removeLegacyKey: legacyKey != nil,
                keychainWriteFailed: false
            )
        }

        guard let legacyKey, !legacyKey.isEmpty else {
            return ResolvedAPIKey(apiKey: "", removeLegacyKey: false, keychainWriteFailed: false)
        }

        let saved = saveToKeychain(legacyKey)
        return ResolvedAPIKey(
            apiKey: legacyKey,
            removeLegacyKey: saved,
            keychainWriteFailed: !saved
        )
    }
}

enum APIKeyStore {
    static let defaultService = "com.cocolab.cocotrack"
    private static let account = "clockify.apiKey"

    /// Which of the two macOS keychain backends a request targets.
    ///
    /// The data-protection keychain is the better home — no ACL prompts, item
    /// scoped to the app — but it requires a keychain-access-group entitlement
    /// derived from the code signature. A Developer ID build without explicit
    /// entitlements, and every ad-hoc signed build, therefore gets
    /// `errSecMissingEntitlement` (-34018) on *every* write. Falling back to the
    /// classic login keychain keeps the credential in the Keychain rather than
    /// letting it evaporate, which is what happened before: the write failed
    /// silently and the user was signed out on the next launch.
    private enum Backend: CaseIterable {
        case dataProtection
        case classic

        func apply(to query: inout [String: Any]) {
            if case .dataProtection = self {
                query[kSecUseDataProtectionKeychain as String] = true
            }
        }
    }

    private static func baseQuery(_ backend: Backend, service: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        backend.apply(to: &query)
        return query
    }

    static func load(service: String = defaultService) -> String? {
        for backend in Backend.allCases {
            var query = baseQuery(backend, service: service)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecSuccess,
               let data = item as? Data,
               let value = String(data: data, encoding: .utf8),
               !value.isEmpty {
                return value
            }
        }
        return nil
    }

    @discardableResult
    static func save(_ value: String, service: String = defaultService) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        for backend in Backend.allCases where write(data, to: backend, service: service) {
            // Keep exactly one copy so `load()` can't resurrect a stale key from
            // the other backend after the user rotates it.
            for other in Backend.allCases where other != backend {
                SecItemDelete(baseQuery(other, service: service) as CFDictionary)
            }
            return true
        }
        return false
    }

    private static func write(_ data: Data, to backend: Backend, service: String) -> Bool {
        let query = baseQuery(backend, service: service)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus != errSecItemNotFound { return false }

        var addAttrs = query
        for (key, value) in attributes {
            addAttrs[key] = value
        }
        return SecItemAdd(addAttrs as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func delete(service: String = defaultService) -> Bool {
        var removedSomewhere = false
        for backend in Backend.allCases {
            let status = SecItemDelete(baseQuery(backend, service: service) as CFDictionary)
            switch status {
            case errSecSuccess, errSecItemNotFound:
                removedSomewhere = true
            case errSecMissingEntitlement:
                // This backend is simply not reachable for how the app is signed;
                // it cannot be holding a copy, so it is not a deletion failure.
                continue
            default:
                return false
            }
        }
        return removedSomewhere
    }
}
