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
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw AppError.keychainReadFailed(key.rawValue)
        }
        return string
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
