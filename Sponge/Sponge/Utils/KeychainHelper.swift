//
//  KeychainHelper.swift
//  Sponge
//
//  Created by Claude on 2026-02-03.
//

import Foundation
import Security

class KeychainHelper {

    static let shared = KeychainHelper()

    private init() {}

    // MARK: - Save to Keychain

    func save(_ data: Data, service: String, account: String) -> Bool {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data
        ] as CFDictionary

        // Delete any existing item
        SecItemDelete(query)

        // Add new item
        let status = SecItemAdd(query, nil)
        return status == errSecSuccess
    }

    func save(_ string: String, service: String, account: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(data, service: service, account: account)
    }

    // MARK: - Read from Keychain

    func read(service: String, account: String) -> Data? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary

        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func readString(service: String, account: String) -> String? {
        guard let data = read(service: service, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete from Keychain

    func delete(service: String, account: String) -> Bool {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary

        let status = SecItemDelete(query)
        return status == errSecSuccess
    }

    // MARK: - Convenience Methods for Gemini API Key

    private let geminiService = "com.classtranscriber.gemini"
    private let geminiAccount = "apiKey"

    func saveGeminiAPIKey(_ key: String) -> Bool {
        return save(key, service: geminiService, account: geminiAccount)
    }

    func getGeminiAPIKey() -> String? {
        return readString(service: geminiService, account: geminiAccount)
    }

    func deleteGeminiAPIKey() -> Bool {
        return delete(service: geminiService, account: geminiAccount)
    }
}
