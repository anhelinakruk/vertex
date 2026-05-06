//
//  WelcomeView.swift
//  Vertex
//
//  Created by Daria Kozlovska on 13/04/2026.
//

import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: WalletViewModel
    @State private var showImportSheet = false
    @State private var showRecoveryPhrase = false
    @State private var showSigningSheet = false

    var body: some View {
        ZStack {
            Color(.sRGB, red: 0.97, green: 0.97, blue: 0.98)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.black)

                    Text("Swaply")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Ethereum Wallet")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(spacing: 14) {
                    if !viewModel.errorMessage.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(viewModel.errorMessage)
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal, 32)
                    }

                    Button(action: {
                        Task {
                            await viewModel.prepareWalletCreation()
                            if viewModel.pendingSIWEMessage != nil {
                                showSigningSheet = true
                            }
                        }
                    }) {
                        HStack(spacing: 10) {
                            if viewModel.loading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("Create New Wallet")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.loading)
                    .buttonStyle(.plain)

                    Button(action: {
                        showImportSheet = true
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.down.circle")
                            Text("Import Wallet")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .disabled(viewModel.loading)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $showImportSheet) {
            ImportWalletSheet(viewModel: viewModel, isPresented: $showImportSheet, showRecoveryPhrase: $showRecoveryPhrase)
        }
        .sheet(isPresented: $showRecoveryPhrase) {
            RecoveryPhraseSheet(mnemonic: viewModel.mnemonic, isPresented: $showRecoveryPhrase)
        }
        .sheet(isPresented: $showSigningSheet) {
            if let message = viewModel.pendingSIWEMessage {
                SigningSheet(
                    message: message,
                    onSign: {
                        Task {
                            await viewModel.completeWalletCreation()
                            showSigningSheet = false
                            if viewModel.isAuthenticated {
                                showRecoveryPhrase = true
                            }
                        }
                    },
                    onCancel: {
                        viewModel.pendingSIWEMessage = nil
                        showSigningSheet = false
                    }
                )
            }
        }
    }
}

struct ImportWalletSheet: View {
    @ObservedObject var viewModel: WalletViewModel
    @Binding var isPresented: Bool
    @Binding var showRecoveryPhrase: Bool
    @State private var seedPhrase = ""
    @State private var showSigningSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(.sRGB, red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.05))
                                    .frame(width: 60, height: 60)

                                Image(systemName: "arrow.down.doc.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.black)
                            }
                            .padding(.top, 20)

                            Text("Import Wallet")
                                .font(.title2.bold())

                            Text("Enter your recovery phrase to restore your wallet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recovery Phrase")
                                .font(.headline)
                                .foregroundColor(.primary)

                            ZStack(alignment: .topLeading) {
                                if seedPhrase.isEmpty {
                                    Text("word1 word2 word3...")
                                        .foregroundColor(.secondary.opacity(0.5))
                                        .padding(12)
                                }

                                TextEditor(text: $seedPhrase)
                                    .frame(minHeight: 140)
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.05))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                    )
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.black)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Supported formats")
                                    .font(.subheadline.bold())
                                Text("12 or 24 word phrases, separated by spaces")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(10)

                        if !viewModel.errorMessage.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(viewModel.errorMessage)
                                    .font(.subheadline)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }

                        Button(action: {
                            Task {
                                await viewModel.prepareWalletImport(seedPhrase: seedPhrase)
                                if viewModel.pendingSIWEMessage != nil {
                                    showSigningSheet = true
                                }
                            }
                        }) {
                            HStack {
                                if viewModel.loading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("Import Wallet")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(seedPhrase.isEmpty ? Color.gray : Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(seedPhrase.isEmpty || viewModel.loading)
                        .buttonStyle(.plain)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showSigningSheet) {
            if let message = viewModel.pendingSIWEMessage {
                SigningSheet(
                    message: message,
                    onSign: {
                        Task {
                            await viewModel.completeWalletImport()
                            showSigningSheet = false
                            if viewModel.isAuthenticated {
                                isPresented = false
                            }
                        }
                    },
                    onCancel: {
                        viewModel.pendingSIWEMessage = nil
                        showSigningSheet = false
                    }
                )
            }
        }
    }
}