//
//  HomeView.swift
//  frontend
//
//  Created by Daria Kozlovska on 25/03/2026.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack {
            HeaderView()
            BalanceView()
            ActionButtonsView()
            TokenListView()
            Spacer()
            BottomBarView()
        }
        .padding()
        .background(Color.black)
        .foregroundColor(.white)
    }
}
