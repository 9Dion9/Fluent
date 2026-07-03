//
//  DeviceAuthProvider.swift
//  Fluent
//
//  AuthProvider seam (CLAUDE.md §2, §12) — v1's sole implementation is
//  anonymous device accounts. v2 attaches Sign in with Apple to the same
//  user_id without touching call sites.
//

import Foundation
import Security

protocol AuthProvider {
    /// Ensures a device identity exists (generating one on first launch),
    /// authenticates it against the Worker, and returns the resulting profile.
    func ensureAuthenticated() async throws -> Profile
}

struct DeviceAuthProvider: AuthProvider {
    private let apiClient: APIClient
    private let pubidKey = "device_pubid"
    private let secretKey = "device_secret"

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func ensureAuthenticated() async throws -> Profile {
        let pubid = Keychain.get(pubidKey) ?? Self.generateAndStore(key: pubidKey)
        let secret = Keychain.get(secretKey) ?? Self.generateAndStore(key: secretKey)

        _ = try await apiClient.authenticateDevice(pubid: pubid, secret: secret)
        return try await apiClient.getProfile()
    }

    @discardableResult
    private static func generateAndStore(key: String) -> String {
        let value = randomHex(byteCount: 32)
        Keychain.set(value, forKey: key)
        return value
    }

    private static func randomHex(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
