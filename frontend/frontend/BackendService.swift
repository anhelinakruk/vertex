//
//  BackendService.swift
//  Vertex
//
//  Created by Daria Kozlovska on 13/04/2026.
//

import Foundation

enum BackendError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case decodingError(Error)
}

class BackendService {
    static let shared = BackendService()

    private let baseURL: String

    init(baseURL: String = "http://localhost:3000") {
        self.baseURL = baseURL
    }

    func getNonce() async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/auth/nonce") else {
            throw BackendError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }

        let nonceResponse = try JSONDecoder().decode(NonceResponse.self, from: data)
        return nonceResponse.nonce
    }

    func verifyAndLogin(message: String, signature: String, address: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/api/auth/verify") else {
            throw BackendError.invalidURL
        }

        let body: [String: String] = [
            "message": message,
            "signature": signature,
            "address": address
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorMessage = String(data: data, encoding: .utf8) {
                throw BackendError.apiError(errorMessage)
            }
            throw BackendError.invalidResponse
        }

        do {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            return authResponse
        } catch {
            throw BackendError.decodingError(error)
        }
    }

    func saveTransaction(
        walletId: String,
        txHash: String,
        fromAddress: String,
        toAddress: String,
        amount: String,
        chainId: Int,
        accessToken: String
    ) async throws -> Transaction {
        guard let url = URL(string: "\(baseURL)/api/transactions") else {
            throw BackendError.invalidURL
        }

        let body: [String: Any] = [
            "wallet_id": walletId,
            "tx_hash": txHash,
            "from_address": fromAddress,
            "to_address": toAddress,
            "amount": amount,
            "chain_id": chainId
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw BackendError.invalidResponse
        }

        let transaction = try JSONDecoder().decode(Transaction.self, from: data)
        return transaction
    }

    func getTransactions(walletId: String, accessToken: String) async throws -> [Transaction] {
        guard let url = URL(string: "\(baseURL)/api/transactions/\(walletId)") else {
            throw BackendError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }

        let transactions = try JSONDecoder().decode([Transaction].self, from: data)
        return transactions
    }
}