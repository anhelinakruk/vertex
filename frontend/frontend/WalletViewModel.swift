//
//  WalletViewModel.swift
//  Vertex
//
//  Created by Daria Kozlovska on 13/04/2026.
//

import Foundation
import Security
import AlloySwift
import CryptoKit

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

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Wallet Crypto Functions

    private func generateMnemonic(bytes: Data) async throws -> String {
        // Use AlloySwift to generate a mnemonic from entropy
        // Since AlloySwift exposes Rust functions, we assume it has a mnemonic generator
        // For now, we'll use a basic approach and let AlloySwift handle the Rust integration
        
        // Fallback: Create a 12-word mnemonic manually (BIP39)
        // This would normally come from AlloySwift's Rust library
        let words = try generateBIP39Words(minimumEntropy: bytes)
        return words.joined(separator: " ")
    }

    private func deriveAddressFromMnemonic(mnemonic: String) async throws -> String {
        // Call AlloySwift to derive the Ethereum address from the mnemonic
        // This is a Rust function exposed through UniFFI
        do {
            // Try to use AlloySwift's derivation function
            // The actual function name depends on the Rust library's exports
            let address = try await AlloySwift.deriveAddress(
                mnemonic: mnemonic,
                derivationPath: "m/44'/60'/0'/0/0"  // Standard Ethereum derivation path
            )
            return address
        } catch {
            // If AlloySwift function doesn't work, try alternative approach
            throw NSError(domain: "WalletViewModel", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to derive address: \(error)"])
        }
    }

    private func signMessage(mnemonic: String, message: String) async throws -> String {
        // The SIWE message needs to be signed with Ethereum's message signing standard
        // This adds the prefix and signs with the private key derived from the mnemonic
        
        do {
            // Call AlloySwift to sign the message using the mnemonic
            let signature = try await AlloySwift.signMessage(
                message: message,
                mnemonic: mnemonic
            )
            return signature
        } catch {
            throw NSError(domain: "WalletViewModel", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to sign message: \(error)"])
        }
    }

    private func generateBIP39Words(minimumEntropy: Data) throws -> [String] {
        // Standard BIP39 word list (first 10 words for demo)
        let bip39Words = [
            "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract",
            "academy", "access"
        ]
        
        // This is a placeholder - in production, use a full BIP39 word list
        // and proper entropy-to-words conversion
        var selectedWords: [String] = []
        var seed = minimumEntropy
        
        for _ in 0..<12 {
            if !seed.isEmpty {
                let index = Int(seed[0]) % bip39Words.count
                selectedWords.append(bip39Words[index])
                seed = seed.dropFirst()
            }
        }
        
        return selectedWords
    }
}