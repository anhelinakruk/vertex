//
//  Models.swift
//  Vertex
//
//  Created by Daria Kozlovska on 13/04/2026.
//

import Foundation

struct Transaction: Identifiable, Codable {
    let id: String?
    let walletId: String
    let txHash: String
    let fromAddress: String
    let toAddress: String
    let amount: String
    let status: String
    let chainId: Int
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case walletId = "wallet_id"
        case txHash = "tx_hash"
        case fromAddress = "from_address"
        case toAddress = "to_address"
        case amount
        case status
        case chainId = "chain_id"
        case createdAt = "created_at"
    }
}

struct User: Codable {
    let id: String?
    let address: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case address
        case createdAt = "created_at"
    }
}

struct AuthResponse: Codable {
    let accessToken: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case userId = "user_id"
    }
}

struct NonceResponse: Codable {
    let nonce: String
}

struct SIWEMessage {
    let domain: String
    let address: String
    let statement: String
    let uri: String
    let version: String
    let chainId: Int
    let nonce: String

    func format() -> String {
        return """
        \(domain) wants you to sign in with your Ethereum account:
        \(address)

        \(statement)

        URI: \(uri)
        Version: \(version)
        Chain ID: \(chainId)
        Nonce: \(nonce)
        """
    }
}