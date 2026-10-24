import Foundation
import Security

protocol APIKeyStoring {
    func read(providerID: String) throws -> String?
    func save(_ key: String, providerID: String) throws
    func clear(providerID: String) throws
    func migrateLegacyOpenAIKeyIfNeeded() throws
}

enum KeychainFailure: Error {
    case operationFailed(operation: String, status: OSStatus)
    case invalidValue
}

struct KeychainAPIKeyStore: APIKeyStoring {
    let service: String
    private let legacyService: String
    private let legacyAccount = "openai-api-key"
    private let legacyProviderID = "openai"

    init(service: String = "com.example.BudgetLens.llm-keys", legacyService: String = "com.example.BudgetLens.openai") {
        self.service = service
        self.legacyService = legacyService
    }

    private func account(for providerID: String) -> String {
        "llm-key.\(providerID)"
    }

    private func identifier(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    func read(providerID: String) throws -> String? {
        try read(service: service, account: account(for: providerID))
    }

    private func read(service: String, account: String) throws -> String? {
        var query = identifier(service: service, account: account)
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

    func save(_ key: String, providerID: String) throws {
        guard let data = key.data(using: .utf8), key.isEmpty == false else {
            throw KeychainFailure.invalidValue
        }
        var item = identifier(service: service, account: account(for: providerID))
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(
                identifier(service: service, account: account(for: providerID)) as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw KeychainFailure.operationFailed(operation: "replace", status: updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainFailure.operationFailed(operation: "save", status: status)
        }
    }

    func clear(providerID: String) throws {
        let status = SecItemDelete(identifier(service: service, account: account(for: providerID)) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainFailure.operationFailed(operation: "clear", status: status)
        }
    }

    func migrateLegacyOpenAIKeyIfNeeded() throws {
        let newKey = try read(providerID: legacyProviderID)
        let legacyKey = try read(service: legacyService, account: legacyAccount)
        switch LegacyKeyMigration.plan(newKey: newKey, legacyKey: legacyKey) {
        case .none:
            return
        case .copy(let value):
            try save(value, providerID: legacyProviderID)
            let deleteStatus = SecItemDelete(identifier(service: legacyService, account: legacyAccount) as CFDictionary)
            guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
                throw KeychainFailure.operationFailed(operation: "legacy cleanup", status: deleteStatus)
            }
        }
    }
}
