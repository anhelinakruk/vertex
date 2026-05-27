//
//  AlchemyService.swift
//  Vertex
//
//  Created by Daria Kozlovska on 13/04/2026.
//

import Foundation

class AlchemyService {
    static let shared = AlchemyService()

    private let apiKey = "ayXO_gsh9HUbBE-Mm9I_HNdGrIPmrgeI"
    private let network = "eth-sepolia"

    private var baseURL: String {
        "https://\(network).g.alchemy.com/v2/\(apiKey)"
    }

    func getBalance(address: String) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw NSError(domain: "AlchemyService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_getBalance",
            "params": [address, "latest"]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "AlchemyService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request failed"])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let result = json?["result"] as? String else {
            throw NSError(domain: "AlchemyService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        return weiToEth(hexWei: result)
    }

    func getTransactions(address: String) async throws -> [Transaction] {
        print(" AlchemyService: Fetching transactions for \(address)")

        guard let url = URL(string: baseURL) else {
            throw NSError(domain: "AlchemyService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        // Fetch both sent and received transactions
        let fromRequestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "alchemy_getAssetTransfers",
            "params": [
                [
                    "fromAddress": address,
                    "category": ["external"],
                    "maxCount": "0x32",
                    "withMetadata": true
                ]
            ]
        ]

        let toRequestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 2,
            "method": "alchemy_getAssetTransfers",
            "params": [
                [
                    "toAddress": address,
                    "category": ["external"],
                    "maxCount": "0x32",
                    "withMetadata": true
                ]
            ]
        ]

        var fromTransactions: [Transaction] = []
        var toTransactions: [Transaction] = []

        // Fetch "from" transactions
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: fromRequestBody)

        print(" Fetching 'from' transactions...")
        let (fromData, _) = try await URLSession.shared.data(for: request)

        if let json = try JSONSerialization.jsonObject(with: fromData) as? [String: Any] {
            print("'from' response: \(json)")

            if let result = json["result"] as? [String: Any],
               let transfers = result["transfers"] as? [[String: Any]] {
                print("🔍 Found \(transfers.count) 'from' transfers")
                fromTransactions = parseTransfers(transfers, userAddress: address)
            } else if let error = json["error"] {
                print(" Alchemy API error (from): \(error)")
            }
        }

        // Fetch "to" transactions
        request.httpBody = try JSONSerialization.data(withJSONObject: toRequestBody)

        print("Fetching 'to' transactions...")
        let (toData, _) = try await URLSession.shared.data(for: request)

        if let json = try JSONSerialization.jsonObject(with: toData) as? [String: Any] {
            print("'to' response: \(json)")

            if let result = json["result"] as? [String: Any],
               let transfers = result["transfers"] as? [[String: Any]] {
                print("🔍 Found \(transfers.count) 'to' transfers")
                toTransactions = parseTransfers(transfers, userAddress: address)
            } else if let error = json["error"] {
                print(" Alchemy API error (to): \(error)")
            }
        }

        // Combine and sort by block number (most recent first)
        var allTransactions = fromTransactions + toTransactions
        print("🔍 Total transactions before sort: \(allTransactions.count)")

        allTransactions.sort { t1, t2 in
            guard let createdAt1 = t1.createdAt, let createdAt2 = t2.createdAt else {
                return false
            }
            return createdAt1 > createdAt2
        }

        print("🔍 Returning \(allTransactions.count) transactions")
        return allTransactions
    }

    private func parseTransfers(_ transfers: [[String: Any]], userAddress: String) -> [Transaction] {
        return transfers.compactMap { transfer -> Transaction? in
            print("🔍 Parsing transfer: \(transfer)")

            guard let hash = transfer["hash"] as? String else {
                print("Missing hash")
                return nil
            }

            guard let from = transfer["from"] as? String else {
                print("Missing from address")
                return nil
            }

            guard let to = transfer["to"] as? String else {
                print("Missing to address")
                return nil
            }

            // Parse value - can be Double, NSNumber, or nil
            let valueDouble: Double
            if let value = transfer["value"] as? Double {
                valueDouble = value
            } else if let value = transfer["value"] as? NSNumber {
                valueDouble = value.doubleValue
            } else if let value = transfer["value"] as? String, let parsed = Double(value) {
                valueDouble = parsed
            } else {
                print("⚠️ No value found, defaulting to 0. Raw value: \(transfer["value"] ?? "nil")")
                valueDouble = 0
            }

            guard let metadata = transfer["metadata"] as? [String: Any] else {
                print("Missing metadata")
                return nil
            }

            guard let blockTimestamp = metadata["blockTimestamp"] as? String else {
                print("Missing blockTimestamp in metadata")
                return nil
            }

            let amount = String(format: "%.4f", valueDouble)

            print("Parsed transaction: \(hash.prefix(10))... from \(from.prefix(10))... to \(to.prefix(10))... amount: \(amount)")

            return Transaction(
                id: hash,
                walletId: "user:\(userAddress)",
                txHash: hash,
                fromAddress: from,
                toAddress: to,
                amount: amount,
                status: "success",
                chainId: 11155111,
                createdAt: blockTimestamp
            )
        }
    }

    private func weiToEth(hexWei: String) -> String {
        let hexString = hexWei.hasPrefix("0x") ? String(hexWei.dropFirst(2)) : hexWei

        guard let weiValue = UInt64(hexString, radix: 16) else {
            return "0.0000"
        }

        let ethValue = Double(weiValue) / 1_000_000_000_000_000_000.0
        return String(format: "%.4f", ethValue)
    }
}