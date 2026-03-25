//
//  TokenListView.swift
//  frontend
//
//  Created by Daria Kozlovska on 25/03/2026.
//

import SwiftUI

struct TokenListView: View {

    @State private var selected = "Ethereum"

    let tokens = ["Ethereum", "Bitcoin", "Solana"]

    var body: some View {
        VStack(alignment: .leading) {

            Text("Tokens")
                .font(.headline)

            Picker("Select Token", selection: $selected) {
                ForEach(tokens, id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(MenuPickerStyle())

            VStack(spacing: 12) {

                TokenRow(name: "Ethereum", price: "$2166.03", change: "+0.80%", balance: "0.5 ETH")

                TokenRow(name: "Bitcoin", price: "$43,000", change: "+1.2%", balance: "0.1 BTC")

            }
        }
    }
}

struct TokenRow: View {
    let name: String
    let price: String
    let change: String
    let balance: String

    var body: some View {
        HStack {
            Circle()
                .frame(width: 40, height: 40)
                .foregroundColor(.gray)

            VStack(alignment: .leading) {
                Text(name)
                Text(price + " • " + change)
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Spacer()

            Text(balance)
        }
    }
}
