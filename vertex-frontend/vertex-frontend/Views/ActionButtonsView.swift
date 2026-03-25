//
//  ActionButtonsView.swift.swift
//  vertex-frontend
//
//  Created by Daria Kozlovska on 25/03/2026.
//

import SwiftUI

struct ActionButtonsView: View {

    let buttons = [
        ("Send", "paperplane"),
        ("Receive", "arrow.down.left")
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(buttons, id: \.0) { item in
                VStack {
                    Image(systemName: item.1)
                    Text(item.0)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
            }
        }
    }
}
