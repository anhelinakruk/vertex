//
//  HomeView.swift
//  Vertex
//
//  Created by Daria Kozlovska on 25/03/2026.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import AlloySwift

struct HomeView: View {
    @ObservedObject var viewModel: WalletViewModel
    @State private var showRecoveryPhrase = false
    @State private var showLogoutAlert = false
    @State private var showSendSheet = false
    @State private var showReceiveSheet = false
    @State private var selectedTransaction: Transaction?

    var body: some View {
        NavigationView {
            ZStack {
                Color(.sRGB, red: 0.97, green: 0.97, blue: 0.98)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        BalanceCard(
                            balance: viewModel.balance,
                            address: viewModel.address
                        )

                        HStack(spacing: 12) {
                            Button(action: {
                                showSendSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                    Text("Send")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                showReceiveSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.circle")
                                    Text("Receive")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)

                        TransactionsList(
                            transactions: viewModel.transactions,
                            selectedTransaction: $selectedTransaction
                        )
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Wallet")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: {
                            showRecoveryPhrase = true
                        }) {
                            Label("Recovery Phrase", systemImage: "key.fill")
                        }

                        Divider()

                        Button(role: .destructive, action: {
                            showLogoutAlert = true
                        }) {
                            Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showRecoveryPhrase) {
                RecoveryPhraseSheet(mnemonic: viewModel.mnemonic, isPresented: $showRecoveryPhrase)
            }
            .sheet(isPresented: $showSendSheet) {
                SendTransactionSheet(viewModel: viewModel, isPresented: $showSendSheet)
            }
            .sheet(isPresented: $showReceiveSheet) {
                ReceiveSheet(address: viewModel.address, isPresented: $showReceiveSheet)
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailSheet(transaction: transaction)
            }
            .alert("Logout", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    viewModel.logout()
                }
            } message: {
                Text("Make sure you have saved your recovery phrase before logging out!")
            }
            .refreshable {
                await viewModel.refreshData()
            }
        }
    }
}

struct BalanceCard: View {
    let balance: String
    let address: String

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Total Balance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(balance)
                        .font(.system(size: 48, weight: .bold, design: .default))
                        .foregroundColor(.primary)

                    Text("ETH")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 8) {
                Text(shortAddress)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(.secondary)

                Button(action: {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(address, forType: .string)
                    #else
                    UIPasteboard.general.string = address
                    #endif
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.05))
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
        .padding(.horizontal, 20)
    }

    private var shortAddress: String {
        guard address.count > 10 else { return address }
        let start = address.prefix(6)
        let end = address.suffix(4)
        return "\(start)...\(end)"
    }
}

struct TransactionsList: View {
    let transactions: [Transaction]
    @Binding var selectedTransaction: Transaction?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .padding(.horizontal, 20)

            if transactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("No transactions yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(transactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .onTapGesture {
                                selectedTransaction = transaction
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundColor(statusColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(shortHash)
                    .font(.system(.body, design: .monospaced))

                Text(transaction.status.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(transaction.amount) ETH")
                .font(.body)
                .fontWeight(.medium)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 5, y: 1)
    }

    private var shortHash: String {
        let hash = transaction.txHash
        guard hash.count > 10 else { return hash }
        let start = hash.prefix(6)
        let end = hash.suffix(4)
        return "\(start)...\(end)"
    }

    private var statusColor: Color {
        switch transaction.status.lowercased() {
        case "success":
            return .green
        case "pending":
            return .orange
        case "failed":
            return .red
        default:
            return .secondary
        }
    }

    private var statusIcon: String {
        switch transaction.status.lowercased() {
        case "success":
            return "checkmark.circle.fill"
        case "pending":
            return "clock.fill"
        case "failed":
            return "xmark.circle.fill"
        default:
            return "circle.fill"
        }
    }
}

struct SendTransactionSheet: View {
    @ObservedObject var viewModel: WalletViewModel
    @Binding var isPresented: Bool
    @State private var recipientAddress = ""
    @State private var amount = ""
    @State private var sending = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    @State private var txHash = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color(.sRGB, red: 0.97, green: 0.97, blue: 0.98)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.05))
                                    .frame(width: 60, height: 60)

                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.black)
                            }

                            Text("Send ETH")
                                .font(.title2.bold())
                        }
                        .padding(.top, 20)

                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recipient Address")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)

                                TextField("0x...", text: $recipientAddress)
                                    .textFieldStyle(.plain)
                                    .font(.system(.body, design: .monospaced))
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .padding(12)
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Amount (ETH)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)

                                TextField("0.0", text: $amount)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 24, weight: .semibold))
                                    .padding(12)
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                    )

                                HStack {
                                    Text("Available: \(viewModel.balance) ETH")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Button("Max") {
                                        amount = viewModel.balance
                                    }
                                    .font(.caption.bold())
                                    .foregroundColor(.black)
                                }
                            }
                        }

                        if !errorMessage.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(errorMessage)
                                    .font(.subheadline)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                        }

                        Button(action: {
                            Task {
                                await sendTransaction()
                            }
                        }) {
                            HStack {
                                if sending {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text("Send Transaction")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isValid ? Color.black : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!isValid || sending)
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
        .alert("Transaction Sent!", isPresented: $showSuccessAlert) {
            Button("View on Explorer") {
                openInExplorer()
                isPresented = false
            }
            Button("Done", role: .cancel) {
                isPresented = false
            }
        } message: {
            Text("Transaction hash:\n\(txHash.prefix(10))...\(txHash.suffix(8))")
        }
    }

    private func openInExplorer() {
        let explorerUrl = "https://sepolia.etherscan.io/tx/\(txHash)"
        #if os(macOS)
        if let url = URL(string: explorerUrl) {
            NSWorkspace.shared.open(url)
        }
        #else
        if let url = URL(string: explorerUrl) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    private var isValid: Bool {
        !recipientAddress.isEmpty && !amount.isEmpty && Double(amount) ?? 0 > 0
    }

    private func sendTransaction() async {
        errorMessage = ""
        sending = true

        // Trim whitespace and clean inputs
        let trimmedAddress = recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate amount is a valid number
        guard Double(cleanedAmount) != nil else {
            errorMessage = "Invalid amount format"
            sending = false
            return
        }

        // Debug: print actual values
        print("📍 Recipient Address Length: \(trimmedAddress.count)")
        print("📍 Recipient Address: \(trimmedAddress)")
        print("📍 Amount: '\(cleanedAmount)'")
        print("📍 Amount characters: \(Array(cleanedAmount))")
        print("📍 Amount length: \(cleanedAmount.count)")
        print("📍 Mnemonic word count: \(viewModel.mnemonic.split(separator: " ").count)")

        // Check if address has correct length (42 chars: "0x" + 40 hex chars)
        guard trimmedAddress.count == 42 else {
            errorMessage = "Invalid address length: \(trimmedAddress.count) characters (need 42). Address: \(trimmedAddress)"
            sending = false
            return
        }

        // Check if address starts with "0x" or "0X"
        guard trimmedAddress.lowercased().hasPrefix("0x") else {
            errorMessage = "Address must start with 0x"
            sending = false
            return
        }

        // Check if rest contains only hex characters
        let hexPart = trimmedAddress.dropFirst(2)
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard hexPart.unicodeScalars.allSatisfy({ hexCharacterSet.contains($0) }) else {
            errorMessage = "Address contains invalid characters"
            sending = false
            return
        }

        do {
            // Try lowercase address in case AlloySwift is sensitive to checksum
            let lowercaseAddress = trimmedAddress.lowercased()
            print("📍 Using lowercase address: \(lowercaseAddress)")
            print("📍 Calling sendEthTransaction with:")
            print("   - to: \(lowercaseAddress)")
            print("   - amount: \(cleanedAmount)")
            print("   - chainId: 11155111")

            let receivedTxHash = try await AlloySwift.sendEthTransaction(
                mnemonic: viewModel.mnemonic,
                to: lowercaseAddress,
                amountEth: cleanedAmount,
                networkRpcUrl: "https://eth-sepolia.g.alchemy.com/v2/ayXO_gsh9HUbBE-Mm9I_HNdGrIPmrgeI",
                chainId: 11155111
            )

            print("📍 Transaction hash received: \(receivedTxHash)")
            print("✅ Transaction sent successfully!")

            // Store transaction hash
            self.txHash = receivedTxHash

            // Try to save to backend (optional - won't fail if backend is down)
            do {
                let walletId = "user:\(viewModel.address)"
                _ = try await BackendService.shared.saveTransaction(
                    walletId: walletId,
                    txHash: receivedTxHash,
                    fromAddress: viewModel.address,
                    toAddress: trimmedAddress,
                    amount: cleanedAmount,
                    chainId: 11155111,
                    accessToken: viewModel.accessToken
                )
                print("📍 Transaction saved to backend")
            } catch {
                print("⚠️ Failed to save to backend (but blockchain tx succeeded): \(error)")
            }

            // Refresh transactions from blockchain
            await viewModel.fetchTransactions()
            await viewModel.fetchBalance()

            sending = false
            showSuccessAlert = true
        } catch {
            print("❌ Transaction error: \(error)")
            errorMessage = "Transaction failed: \(error.localizedDescription)"
            sending = false
        }
    }
}

struct RecoveryPhraseSheet: View {
    let mnemonic: String
    @Binding var isPresented: Bool
    @State private var showCopied = false

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

                                Image(systemName: "key.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.black)
                            }

                            Text("Recovery Phrase")
                                .font(.title.bold())

                            Text("Write down these words in order")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(Array(mnemonicWords.enumerated()), id: \.offset) { index, word in
                                HStack(spacing: 6) {
                                    Text("\(index + 1)")
                                        .font(.caption2.bold())
                                        .foregroundColor(.secondary)
                                        .frame(width: 16)

                                    Text(word)
                                        .font(.system(.callout, design: .monospaced))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .cornerRadius(8)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Important")
                                    .fontWeight(.semibold)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("• Never share your recovery phrase")
                                Text("• Store it in a secure location")
                                Text("• Required to restore your wallet")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)

                        Button(action: {
                            copyToClipboard()
                        }) {
                            HStack {
                                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                Text(showCopied ? "Copied!" : "Copy to Clipboard")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(showCopied ? Color.green : Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(showCopied)
                        .buttonStyle(.plain)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(alignment: .top) {
                if showCopied {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Recovery phrase copied to clipboard")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private var mnemonicWords: [String] {
        mnemonic.split(separator: " ").map(String.init)
    }

    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(mnemonic, forType: .string)
        #else
        UIPasteboard.general.string = mnemonic
        #endif

        withAnimation {
            showCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopied = false
            }
        }
    }
}

struct ReceiveSheet: View {
    let address: String
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color(.sRGB, red: 0.97, green: 0.97, blue: 0.98)
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.05))
                                .frame(width: 60, height: 60)

                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.black)
                        }

                        Text("Receive ETH")
                            .font(.title2.bold())

                        Text("Share your address to receive ETH")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 24) {
                        if let qrImage = generateQRCode(from: address) {
                            #if os(macOS)
                            Image(nsImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 220, height: 220)
                                .padding(20)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.05), radius: 10, y: 2)
                            #else
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 220, height: 220)
                                .padding(20)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.05), radius: 10, y: 2)
                            #endif
                        }

                        VStack(spacing: 12) {
                            Text("Your Address")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)

                            Text(address)
                                .font(.system(.callout, design: .monospaced))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(12)
                        }

                        Button(action: {
                            #if os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(address, forType: .string)
                            #else
                            UIPasteboard.general.string = address
                            #endif
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Address")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    #if os(macOS)
    private func generateQRCode(from string: String) -> NSImage? {
        let data = string.data(using: .utf8)

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)

        let rep = NSCIImageRep(ciImage: scaledImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)

        return nsImage
    }
    #else
    private func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: .utf8)

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }
    #endif
}

struct TransactionDetailSheet: View {
    let transaction: Transaction
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(.sRGB, red: 0.97, green: 0.97, blue: 0.98)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(statusColor.opacity(0.1))
                                    .frame(width: 70, height: 70)

                                Image(systemName: statusIcon)
                                    .font(.system(size: 32))
                                    .foregroundColor(statusColor)
                            }

                            Text(transaction.status.capitalized)
                                .font(.title2.bold())

                            Text("\(transaction.amount) ETH")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                        }
                        .padding(.top, 20)

                        VStack(spacing: 16) {
                            DetailRow(
                                title: "Transaction Hash",
                                value: transaction.txHash,
                                isCopyable: true
                            )

                            Divider()

                            DetailRow(
                                title: "From",
                                value: transaction.fromAddress,
                                isCopyable: true
                            )

                            Divider()

                            DetailRow(
                                title: "To",
                                value: transaction.toAddress,
                                isCopyable: true
                            )

                            Divider()

                            DetailRow(
                                title: "Amount",
                                value: "\(transaction.amount) ETH",
                                isCopyable: false
                            )

                            Divider()

                            DetailRow(
                                title: "Network",
                                value: networkName,
                                isCopyable: false
                            )

                            if let timestamp = transaction.createdAt {
                                Divider()

                                DetailRow(
                                    title: "Timestamp",
                                    value: formatTimestamp(timestamp),
                                    isCopyable: false
                                )
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.03), radius: 8, y: 2)

                        Button(action: {
                            openInExplorer()
                        }) {
                            HStack {
                                Image(systemName: "arrow.up.right.square")
                                Text("View on Explorer")
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
                    .padding(24)
                }
            }
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statusColor: Color {
        switch transaction.status.lowercased() {
        case "success":
            return .green
        case "pending":
            return .orange
        case "failed":
            return .red
        default:
            return .secondary
        }
    }

    private var statusIcon: String {
        switch transaction.status.lowercased() {
        case "success":
            return "checkmark.circle.fill"
        case "pending":
            return "clock.fill"
        case "failed":
            return "xmark.circle.fill"
        default:
            return "circle.fill"
        }
    }

    private var networkName: String {
        switch transaction.chainId {
        case 1:
            return "Ethereum Mainnet"
        case 11155111:
            return "Sepolia Testnet"
        case 5:
            return "Goerli Testnet"
        default:
            return "Chain ID: \(transaction.chainId)"
        }
    }

    private var explorerUrl: String {
        switch transaction.chainId {
        case 1:
            return "https://etherscan.io/tx/\(transaction.txHash)"
        case 11155111:
            return "https://sepolia.etherscan.io/tx/\(transaction.txHash)"
        case 5:
            return "https://goerli.etherscan.io/tx/\(transaction.txHash)"
        default:
            return "https://etherscan.io/tx/\(transaction.txHash)"
        }
    }

    private func openInExplorer() {
        #if os(macOS)
        if let url = URL(string: explorerUrl) {
            NSWorkspace.shared.open(url)
        }
        #else
        if let url = URL(string: explorerUrl) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    private func formatTimestamp(_ timestamp: String) -> String {
        // Format ISO8601 timestamp to readable format
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: timestamp) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return timestamp
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    let isCopyable: Bool
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: isCopyable ? .leading : .center, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: isCopyable ? .leading : .center)

            if isCopyable {
                HStack {
                    Text(value)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button(action: {
                        copyToClipboard(value)
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopied = false
                        }
                    }) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .foregroundColor(showCopied ? .green : .black)
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
