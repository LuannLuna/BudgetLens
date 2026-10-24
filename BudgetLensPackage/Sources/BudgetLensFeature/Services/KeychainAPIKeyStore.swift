import Foundation
import Security

protocol APIKeyStoring {
    func read() throws -> String?
    func save(_ key: String) throws
    func clear() throws
}

enum KeychainFailure: Error {
    case operationFailed(operation: String, status: OSStatus)
    case invalidValue
}

struct KeychainAPIKeyStore: APIKeyStoring {
    let service: String
    private let account = "openai-api-key"

    init(service: String = "com.example.BudgetLens.openai") {
        self.service = service
    }

    private var identifier: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    func read() throws -> String? {
        var query = identifier
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainFailure.operationFailed(operation: "read", status: status) }
        guard let data = item as? Data, let key = String(data: data, encoding: .utf8) else {
            throw KeychainFailure.invalidValue
        }
        return key
    }

    func save(_ key: String) throws {
        guard let data = key.data(using: .utf8), key.isEmpty == false else {
            throw KeychainFailure.invalidValue
        }
        var item = identifier
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(
                identifier as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw KeychainFailure.operationFailed(operation: "replace", status: updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainFailure.operationFailed(operation: "save", status: status)
        }
    }

    func clear() throws {
        let status = SecItemDelete(identifier as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainFailure.operationFailed(operation: "clear", status: status)
        }
    }
}
