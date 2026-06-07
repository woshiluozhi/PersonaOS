import Foundation
import Security

protocol APIKeyStore {
    func save(_ apiKey: String) throws
    func load() -> String?
    func delete() throws
}

enum APIKeyStoreError: Error, Equatable {
    case emptyKey
    case unexpectedStatus(OSStatus)
}

struct KeychainAPIKeyStore: APIKeyStore {
    private let service: String
    private let account: String

    init(
        service: String = "com.local.PersonaOS.openai",
        account: String = "openai-api-key"
    ) {
        self.service = service
        self.account = account
    }

    func save(_ apiKey: String) throws {
        let cleanedKey = cleanedAPIKey(apiKey)
        guard !cleanedKey.isEmpty else {
            throw APIKeyStoreError.emptyKey
        }

        let data = Data(cleanedKey.utf8)
        let query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            throw APIKeyStoreError.unexpectedStatus(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw APIKeyStoreError.unexpectedStatus(addStatus)
        }
    }

    func load() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        let apiKey = String(decoding: data, as: UTF8.self)
        let cleanedKey = cleanedAPIKey(apiKey)
        return cleanedKey.isEmpty ? nil : cleanedKey
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIKeyStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func cleanedAPIKey(_ apiKey: String) -> String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
