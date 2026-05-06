//
//  WalletViewModel.swift
//  Vertex
//
//  Created by Daria Kozlovska on 13/04/2026.
//

import Foundation
import Security
import AlloySwift

@MainActor
class WalletViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var loading = false
    @Published var initializing = true
    @Published var errorMessage = ""
    @Published var mnemonic = ""
    @Published var address = ""
    @Published var balance = "0.0000"
    @Published var transactions: [Transaction] = []
    @Published var pendingSIWEMessage: String?

    private let backendService = BackendService.shared
    var accessToken = ""
    private var pendingNonce: String?
    private var pendingWalletAddress: String?
    private var pendingMnemonic: String?

    private let keychainService = "com.swaply.wallet"
    private let mnemonicKey = "wallet_mnemonic"
    private let addressKey = "wallet_address"
    private let tokenKey = "access_token"

    init() {
        Task {
            await loadWalletData()
        }
    }

    func prepareWalletCreation() async {
        loading = true
        errorMessage = ""

        do {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let result = SecRandomCopyBytes(kSecRandomDefault, 16, &randomBytes)
            guard result == errSecSuccess else {
                errorMessage = "Failed to generate random bytes"
                loading = false
                return
            }

            let generatedMnemonic = try await generateMnemonic(bytes: Data(randomBytes))
            let walletAddress = try await deriveAddressFromMnemonic(mnemonic: generatedMnemonic)

            let nonce = try await backendService.getNonce()

            let siweMessage = SIWEMessage(
                domain: "localhost",
                address: walletAddress,
                statement: "Sign in to Swaply Wallet",
                uri: "http://localhost:3000",
                version: "1",
                chainId: 11155111,
                nonce: nonce
            )

            pendingMnemonic = generatedMnemonic
            pendingWalletAddress = walletAddress
            pendingNonce = nonce
            pendingSIWEMessage = siweMessage.format()

            loading = false
        } catch {
            errorMessage = "Failed to prepare wallet: \(error.localizedDescription)"
            loading = false
        }
    }

    func completeWalletCreation() async {
        guard let generatedMnemonic = pendingMnemonic,
              let walletAddress = pendingWalletAddress,
              let message = pendingSIWEMessage else {
            errorMessage = "No pending wallet to complete"
            return
        }

        loading = true

        do {
            let signature = try await signMessage(mnemonic: generatedMnemonic, message: message)

            let authResponse = try await backendService.verifyAndLogin(
                message: message,
                signature: signature,
                address: walletAddress
            )

            accessToken = authResponse.accessToken
            mnemonic = generatedMnemonic
            address = walletAddress

            saveToKeychain(key: mnemonicKey, value: generatedMnemonic)
            saveToKeychain(key: addressKey, value: walletAddress)
            saveToKeychain(key: tokenKey, value: accessToken)

            pendingSIWEMessage = nil
            pendingMnemonic = nil
            pendingWalletAddress = nil
            pendingNonce = nil

            isAuthenticated = true
            await fetchBalance()
            loading = false
        } catch {
            errorMessage = "Failed to complete wallet creation: \(error.localizedDescription)"
            loading = false
        }
    }

    func prepareWalletImport(seedPhrase: String) async {
        loading = true
        errorMessage = ""

        do {
            let trimmedPhrase = seedPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
            let words = trimmedPhrase.split(separator: " ")

            guard words.count == 12 || words.count == 24 else {
                errorMessage = "Seed phrase must be 12 or 24 words"
                loading = false
                return
            }

            let walletAddress = try await deriveAddressFromMnemonic(mnemonic: trimmedPhrase)

            let nonce = try await backendService.getNonce()

            let siweMessage = SIWEMessage(
                domain: "localhost",
                address: walletAddress,
                statement: "Sign in to Swaply Wallet",
                uri: "http://localhost:3000",
                version: "1",
                chainId: 11155111,
                nonce: nonce
            )

            pendingMnemonic = trimmedPhrase
            pendingWalletAddress = walletAddress
            pendingNonce = nonce
            pendingSIWEMessage = siweMessage.format()

            loading = false
        } catch {
            errorMessage = "Failed to prepare import: \(error.localizedDescription)"
            loading = false
        }
    }

    func completeWalletImport() async {
        guard let importedMnemonic = pendingMnemonic,
              let walletAddress = pendingWalletAddress,
              let message = pendingSIWEMessage else {
            errorMessage = "No pending wallet to complete"
            return
        }

        loading = true

        do {
            let signature = try await signMessage(mnemonic: importedMnemonic, message: message)

            let authResponse = try await backendService.verifyAndLogin(
                message: message,
                signature: signature,
                address: walletAddress
            )

            accessToken = authResponse.accessToken
            mnemonic = importedMnemonic
            address = walletAddress

            saveToKeychain(key: mnemonicKey, value: importedMnemonic)
            saveToKeychain(key: addressKey, value: walletAddress)
            saveToKeychain(key: tokenKey, value: accessToken)

            pendingSIWEMessage = nil
            pendingMnemonic = nil
            pendingWalletAddress = nil
            pendingNonce = nil

            isAuthenticated = true
            await fetchBalance()
            loading = false
        } catch {
            errorMessage = "Failed to complete import: \(error.localizedDescription)"
            loading = false
        }
    }

    func loadWalletData() async {
        initializing = true

        guard let storedMnemonic = getFromKeychain(key: mnemonicKey),
              let storedAddress = getFromKeychain(key: addressKey),
              let storedToken = getFromKeychain(key: tokenKey) else {
            initializing = false
            return
        }

        mnemonic = storedMnemonic
        address = storedAddress
        accessToken = storedToken
        isAuthenticated = true

        await fetchBalance()
        await fetchTransactions()

        initializing = false
    }

    func logout() {
        deleteFromKeychain(key: mnemonicKey)
        deleteFromKeychain(key: addressKey)
        deleteFromKeychain(key: tokenKey)

        mnemonic = ""
        address = ""
        accessToken = ""
        balance = "0.0000"
        transactions = []
        isAuthenticated = false
    }

    func fetchBalance() async {
        guard !address.isEmpty else { return }

        do {
            let fetchedBalance = try await AlchemyService.shared.getBalance(address: address)
            balance = fetchedBalance
        } catch {
            print("Failed to fetch balance: \(error)")
        }
    }

    func fetchTransactions() async {
        guard !address.isEmpty else {
            print("⚠️ Cannot fetch transactions - address is empty")
            return
        }

        print("Fetching transactions for address: \(address)")

        do {
            let fetchedTransactions = try await AlchemyService.shared.getTransactions(address: address)
            print("Fetched \(fetchedTransactions.count) transactions from Alchemy")
            transactions = fetchedTransactions

            if fetchedTransactions.isEmpty {
                print("No transactions found for this address")
            } else {
                print("Transactions updated: \(fetchedTransactions.count)")
                fetchedTransactions.forEach { tx in
                    print("  - \(tx.txHash.prefix(10))... (\(tx.amount) ETH)")
                }
            }
        } catch {
            // Ignore "cancelled" errors (Code -999)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("Transaction fetch cancelled (this is OK)")
                return
            }
            print("Failed to fetch transactions: \(error)")
        }
    }

    func refreshData() async {
        await fetchBalance()
        await fetchTransactions()
    }

    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    // MARK: - Wallet Crypto Functions

    private func generateMnemonic(bytes: Data) async throws -> String {
        return try await AlloySwift.generateMnemonic(bytes: [UInt8](bytes))
    }

    private func deriveAddressFromMnemonic(mnemonic: String) async throws -> String {
        return try await AlloySwift.deriveAddressFromMnemonic(mnemonic: mnemonic)
    }

    private func signMessage(mnemonic: String, message: String) async throws -> String {
        return try await AlloySwift.signMessage(mnemonic: mnemonic, message: message)
    }
}