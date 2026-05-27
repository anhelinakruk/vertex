//
//  ContentView.swift
//  Vertex
//
//  Created by Daria Kozlovska on 13/04/2026.
//

import SwiftUI
import AlloySwift

struct ContentView: View {
    @StateObject private var viewModel = WalletViewModel()
    @State private var isBiometricAuthenticated = false
    @State private var showAuthError = false
    @State private var authErrorMessage = ""

    var body: some View {
        Group {
            if viewModel.initializing {
                VStack {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            } else if viewModel.isAuthenticated {
                // User has wallet - require biometric auth
                if isBiometricAuthenticated {
                    HomeView(viewModel: viewModel)
                } else {
                    BiometricAuthView(
                        onAuthenticate: {
                            Task {
                                await authenticateWithBiometrics()
                            }
                        },
                        errorMessage: authErrorMessage
                    )
                }
            } else {
                // No wallet yet - show welcome screen
                WelcomeView(viewModel: viewModel)
            }
        }
        .alert("Authentication Failed", isPresented: $showAuthError) {
            Button("Try Again") {
                Task {
                    await authenticateWithBiometrics()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(authErrorMessage)
        }
        .task {
            // Auto-authenticate when user has wallet
            if viewModel.isAuthenticated && !isBiometricAuthenticated {
                await authenticateWithBiometrics()
            }
        }
        .onChange(of: viewModel.isAuthenticated) { oldValue, newValue in
            if newValue && !isBiometricAuthenticated {
                Task {
                    await authenticateWithBiometrics()
                }
            }
        }
    }

    private func authenticateWithBiometrics() async {
        do {
            let success = try await BiometricAuthService.shared.authenticate(
                reason: "Unlock your wallet"
            )
            if success {
                isBiometricAuthenticated = true
            }
        } catch {
            authErrorMessage = error.localizedDescription
            showAuthError = true
        }
    }
}

struct BiometricAuthView: View {
    let onAuthenticate: () -> Void
    let errorMessage: String
    
    var body: some View {
        ZStack {
            Color(.sRGB, red: 0.97, green: 0.97, blue: 0.98)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.05))
                            .frame(width: 100, height: 100)

                        Image(systemName: biometricIcon)
                            .font(.system(size: 50))
                            .foregroundColor(.black)
                    }

                    Text("Unlock Wallet")
                        .font(.title.bold())

                    Text("Use \(BiometricAuthService.shared.biometricTypeString) to access your wallet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                VStack(spacing: 16) {
                    if !errorMessage.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }

                    Button(action: onAuthenticate) {
                        HStack {
                            Image(systemName: biometricIcon)
                            Text("Authenticate")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        }
        
        private var biometricIcon: String {
            switch BiometricAuthService.shared.biometricType {
            case .faceID:
                return "faceid"
            case .touchID:
                return "touchid"
            case .none:
                return "lock.fill"
            }
        }
    }
    
    #Preview {
        ContentView()
    }

