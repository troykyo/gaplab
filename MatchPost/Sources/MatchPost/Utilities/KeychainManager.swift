import Foundation
import Security

enum KeychainKey: String {
    case anthropicAPIKey      = "anthropic.api_key"
    case knvbAPIKey           = "knvb.api_key"
    case instagramAccessToken = "instagram.access_token"
    case instagramUserID      = "instagram.user_id"
    case instagramAppID       = "instagram.app_id"
    case instagramAppSecret   = "instagram.app_secret"
    case cloudinaryCloudName  = "cloudinary.cloud_name"
    case cloudinaryUploadPreset = "cloudinary.upload_preset"
}

enum KeychainManager {
    private static let service = "com.troykyo.matchpost"

    static func save(_ value: String, for key: KeychainKey) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        var status = SecItemUpdate(query as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        if status != errSecSuccess {
            throw AppError.keychainWriteFailed(key.rawValue)
        }
    }

    static func load(_ key: KeychainKey) throws -> String {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess,
           let data = result as? Data,
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        // Fallback: local credentials file outside the repo (~/.matchpost/credentials)
        if let fileValue = CredentialsFile.value(for: key) {
            return fileValue
        }
        throw AppError.keychainReadFailed(key.rawValue)
    }

    static func delete(_ key: KeychainKey) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func exists(_ key: KeychainKey) -> Bool {
        (try? load(key)) != nil
    }
}

/// Read-only fallback credential store: `~/.matchpost/credentials`.
///
/// Plain-text lines of `keychain.key.name = value`, e.g.
///     anthropic.api_key = sk-ant-...
/// Lives in the home folder, never in the repository. Values saved through
/// the Settings tab go to the Keychain, which always takes precedence.
private enum CredentialsFile {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".matchpost/credentials")

    static func value(for key: KeychainKey) -> String? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        for line in content.split(whereSeparator: \.isNewline) {
            guard !line.hasPrefix("#") else { continue }
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let name  = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            if name == key.rawValue, !value.isEmpty { return value }
        }
        return nil
    }
}
