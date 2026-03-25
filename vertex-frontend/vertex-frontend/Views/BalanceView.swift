//
//  BalanceView.swift
//  vertex-frontend
//
//  Created by Daria Kozlovska on 25/03/2026.
//

import SwiftUI

struct BalanceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("0.00 USD")
                .font(.largeTitle)
                .bold()

            Text("+$0 (0.00%)")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical)
    }
}
