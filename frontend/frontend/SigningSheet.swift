//
//  SigningSheet.swift
//  Vertex
//
//  Created by Daria Kozlovska on 13/04/2026.
//

import SwiftUI

struct SigningSheet: View {
    let message: String
    let onSign: () -> Void
    let onCancel: () -> Void
    @State private var isSigning = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(.sRGB, red: 0.97, green: 0.97, blue: 0.98)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.05))
                                    .frame(width: 60, height: 60)

                                Image(systemName: "signature")
                                    .font(.system(size: 28))
                                    .foregroundColor(.black)
                            }

                            Text("Sign Message")
                                .font(.title.bold())

                            Text("Please review and sign this message to authenticate")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Message")
                                .font(.subheadline.bold())

                            Text(message)
                                .font(.system(.callout, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white)
                                .cornerRadius(12)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.black)
                                Text("What is this?")
                                    .fontWeight(.semibold)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("• This signature proves you own this wallet")
                                Text("• It does NOT allow access to your funds")
                                Text("• Signing is free and safe")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(12)

                        Button(action: {
                            isSigning = true
                            onSign()
                        }) {
                            HStack {
                                if isSigning {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "signature")
                                    Text("Sign Message")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isSigning)
                        .buttonStyle(.plain)

                        Button(action: onCancel) {
                            Text("Cancel")
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                        .disabled(isSigning)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("")
        }
    }
}