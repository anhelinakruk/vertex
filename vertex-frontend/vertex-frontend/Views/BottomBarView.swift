//
//  BottomBarView.swift
//  vertex-frontend
//
//  Created by Daria Kozlovska on 25/03/2026.
//

import SwiftUI

struct BottomBarView: View {

    var body: some View {
        HStack {
            Spacer()

            VStack {
                Image(systemName: "house")
                Text("Home").font(.caption)
            }

            Spacer()

            VStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                Text("Trade").font(.caption)
            }

            Spacer()

            VStack {
                Image(systemName: "clock")
                Text("Activity").font(.caption)
            }

            Spacer()
        }
        .padding(.top)
    }
}

