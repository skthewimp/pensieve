import Foundation
import Security

enum KeychainError: LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain error: \(status)"
        }
    }
}

final class KeychainService {
    private let service = "com.karthikshashidhar.pensieve"
    private let anthropicAccount = "anthropic-api-key"
    private let openAIAccount = "openai-api-key"
    private let sarvamAccount = "sarvam-api-key"

    func saveAnthropicAPIKey(_ apiKey: String) throws {
        try saveAPIKey(apiKey, account: anthropicAccount)
    }

    func loadAnthropicAPIKey() -> String? {
        loadAPIKey(account: anthropicAccount)
    }

    func hasAnthropicAPIKey() -> Bool {
        hasAPIKey(account: anthropicAccount)
    }

    func deleteAnthropicAPIKey() throws {
        try deleteAPIKey(account: anthropicAccount)
    }

    func saveOpenAIAPIKey(_ apiKey: String) throws {
        try saveAPIKey(apiKey, account: openAIAccount)
    }

    func loadOpenAIAPIKey() -> String? {
        loadAPIKey(account: openAIAccount)
    }

    func hasOpenAIAPIKey() -> Bool {
        hasAPIKey(account: openAIAccount)
    }

    func deleteOpenAIAPIKey() throws {
        try deleteAPIKey(account: openAIAccount)
    }

    func saveSarvamAPIKey(_ apiKey: String) throws {
        try saveAPIKey(apiKey, account: sarvamAccount)
    }

    func loadSarvamAPIKey() -> String? {
        loadAPIKey(account: sarvamAccount)
    }

    func hasSarvamAPIKey() -> Bool {
        hasAPIKey(account: sarvamAccount)
    }

    func deleteSarvamAPIKey() throws {
        try deleteAPIKey(account: sarvamAccount)
    }

    private func saveAPIKey(_ apiKey: String, account: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = baseQuery(account: account)

        if trimmed.isEmpty {
            try deleteAPIKey(account: account)
            return
        }

        let data = Data(trimmed.utf8)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    private func loadAPIKey(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func hasAPIKey(account: String) -> Bool {
        guard let key = loadAPIKey(account: account) else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func deleteAPIKey(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
