//
//  HeaderView.swift
//  frontend
//
//  Created by Daria Kozlovska on 25/03/2026.
//

import SwiftUI

struct HeaderView: View {
    let randomAccount = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(32)

    var body: some View {
        HStack {
            Text("Account \(randomAccount)")
                .font(.caption)
                .lineLimit(1)

            Spacer()

            Image(systemName: "gearshape")
                .font(.title2)
        }
    }
}
