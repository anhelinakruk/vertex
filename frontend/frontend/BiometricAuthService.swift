//
//  BiometricAuthService.swift
//  Vertex
//
//  Created by Daria Kozlovska on 13/04/2026.
//

import Foundation
import LocalAuthentication

class BiometricAuthService {
    static let shared = BiometricAuthService()

    private init() {}

    enum BiometricType {
        case faceID
        case touchID
        case none
    }

    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        #if os(iOS)
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
        #else
        // macOS always uses Touch ID if available
        return .touchID
        #endif
    }

    var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticate(reason: String = "Authenticate to access your wallet") async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // If biometrics not available, try device passcode
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                return try await authenticateWithPolicy(.deviceOwnerAuthentication, context: context, reason: reason)
            }
            throw error ?? NSError(domain: "BiometricAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Biometric authentication not available"])
        }

        return try await authenticateWithPolicy(.deviceOwnerAuthenticationWithBiometrics, context: context, reason: reason)
    }

    private func authenticateWithPolicy(_ policy: LAPolicy, context: LAContext, reason: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { success, error in
                if success {
                    continuation.resume(returning: true)
                } else {
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    var biometricTypeString: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .none:
            return "Passcode"
        }
    }
}