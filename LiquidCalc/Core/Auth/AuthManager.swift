//
//  AuthManager.swift
//  LiquidCalc
//
//  Authentication & Guest Identity Management Engine
//  Login is NOT forced: Unauthenticated users run 100% anonymously in Guest Mode.
//  Provides seamless zero-data-loss guest-to-account linking via CryptoTransport.
//  Created for LiquidCalc iOS 18+.
//

import Foundation

// MARK: - Models

public struct UserProfile: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let email: String
    public let name: String?
    public let role: String
    public let tier: String

    public init(id: String, email: String, name: String? = nil, role: String = "user", tier: String = "FREE") {
        self.id = id
        self.email = email
        self.name = name
        self.role = role
        self.tier = tier
    }
}

public struct AuthTokens: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let tokenType: String
    public let expiresIn: Int

    public init(accessToken: String, refreshToken: String? = nil, tokenType: String = "Bearer", expiresIn: Int = 604800) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
    }
}

public struct LinkAccountResult: Sendable {
    public let success: Bool
    public let message: String
    public let user: UserProfile
    public let migratedCalculations: Int
    public let migratedNotes: Int
    public let migratedSubscriptions: Int

    public init(
        success: Bool,
        message: String,
        user: UserProfile,
        migratedCalculations: Int = 0,
        migratedNotes: Int = 0,
        migratedSubscriptions: Int = 0
    ) {
        self.success = success
        self.message = message
        self.user = user
        self.migratedCalculations = migratedCalculations
        self.migratedNotes = migratedNotes
        self.migratedSubscriptions = migratedSubscriptions
    }
}

public enum AuthStatus: Equatable, Sendable {
    case guest(deviceId: String)
    case authenticated(user: UserProfile)

    public var isGuest: Bool {
        switch self {
        case .guest: return true
        case .authenticated: return false
        }
    }
}

// MARK: - AuthManager

@Observable
public final class AuthManager: @unchecked Sendable {
    public static let shared = AuthManager()

    public private(set) var currentUser: UserProfile?
    public private(set) var tokens: AuthTokens?
    public private(set) var isLoading: Bool = false
    public private(set) var lastErrorMessage: String? = nil

    private let userProfileKey = "LiquidCalc_User_Profile_v1"
    private let accessTokenKey = "LiquidCalc_AccessToken_v1"
    private let refreshTokenKey = "LiquidCalc_RefreshToken_v1"

    public var isGuest: Bool {
        return currentUser == nil
    }

    public var deviceId: String {
        return DeviceSyncManager.shared.deviceId
    }

    public var authStatus: AuthStatus {
        if let user = currentUser {
            return .authenticated(user: user)
        } else {
            return .guest(deviceId: deviceId)
        }
    }

    public init() {
        loadPersistedSession()
    }

    // MARK: - Session Persistence

    private func loadPersistedSession() {
        if let token = UserDefaults.standard.string(forKey: accessTokenKey), !token.isEmpty {
            let refresh = UserDefaults.standard.string(forKey: refreshTokenKey)
            self.tokens = AuthTokens(accessToken: token, refreshToken: refresh)
        }

        if let userData = UserDefaults.standard.data(forKey: userProfileKey),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: userData) {
            self.currentUser = profile
        }
    }

    private func persistSession(user: UserProfile, tokens: AuthTokens) {
        self.currentUser = user
        self.tokens = tokens
        UserDefaults.standard.set(tokens.accessToken, forKey: accessTokenKey)
        if let refresh = tokens.refreshToken {
            UserDefaults.standard.set(refresh, forKey: refreshTokenKey)
        }
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userProfileKey)
        }
    }

    private func clearPersistedSession() {
        self.currentUser = nil
        self.tokens = nil
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: userProfileKey)
    }

    // MARK: - Headers for API Requests

    public func authHeaders() -> [String: String] {
        var headers: [String: String] = [
            "X-Device-Token": DeviceSyncManager.shared.deviceToken ?? deviceId
        ]
        if let token = tokens?.accessToken, !token.isEmpty {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }

    // MARK: - Guest Account Linking (Seamless Data Migration)

    /// Links the current anonymous guest device to a permanent registered account.
    /// Preserves all on-device calculations, notes, and subscriptions without data loss.
    @discardableResult
    public func linkGuestAccount(
        email: String,
        password: String,
        name: String? = nil
    ) async throws -> LinkAccountResult {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = name?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanEmail.isEmpty, cleanEmail.contains("@"), cleanEmail.contains(".") else {
            throw CryptoTransportError.serializationError("Please enter a valid email address.")
        }
        guard cleanPassword.count >= 6 else {
            throw CryptoTransportError.serializationError("Password must be at least 6 characters.")
        }

        await MainActor.run {
            self.isLoading = true
            self.lastErrorMessage = nil
        }

        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }

        var payload: [String: Any] = [
            "deviceId": deviceId,
            "email": cleanEmail,
            "password": cleanPassword
        ]
        if let name = cleanName, !name.isEmpty {
            payload["name"] = name
        }

        do {
            let (data, _) = try await CryptoTransport.shared.performEncryptedRequest(
                endpoint: "/api/auth/link-account",
                method: "POST",
                jsonPayload: payload,
                headers: authHeaders()
            )

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CryptoTransportError.serializationError("Invalid response received from auth server")
            }

            guard let userJson = json["user"] as? [String: Any],
                  let userId = userJson["id"] as? String,
                  let userEmail = userJson["email"] as? String else {
                let err = json["error"] as? String ?? "Failed to link account"
                throw CryptoTransportError.invalidResponse(400, err)
            }

            let userName = userJson["name"] as? String
            let userRole = userJson["role"] as? String ?? "user"
            let userTier = userJson["tier"] as? String ?? "FREE"

            let user = UserProfile(
                id: userId,
                email: userEmail,
                name: userName,
                role: userRole,
                tier: userTier
            )

            // Extract tokens
            var newTokens = AuthTokens(accessToken: "linked_token_\(userId)")
            if let tokensJson = json["tokens"] as? [String: Any],
               let access = tokensJson["accessToken"] as? String {
                let refresh = tokensJson["refreshToken"] as? String
                let tokenType = tokensJson["tokenType"] as? String ?? "Bearer"
                let expires = tokensJson["expiresIn"] as? Int ?? 604800
                newTokens = AuthTokens(accessToken: access, refreshToken: refresh, tokenType: tokenType, expiresIn: expires)
            }

            // Extract migration counts
            var migratedCalcs = 0
            var migratedNotes = 0
            var migratedSubs = 0
            if let migratedJson = json["migrated"] as? [String: Any] {
                migratedCalcs = migratedJson["calculations"] as? Int ?? 0
                migratedNotes = migratedJson["notes"] as? Int ?? 0
                migratedSubs = migratedJson["subscriptions"] as? Int ?? 0
            }

            let msg = json["message"] as? String ?? "Device successfully linked to account"

            await MainActor.run {
                self.persistSession(user: user, tokens: newTokens)
            }

            // Notify SubscriptionManager of user update
            await SubscriptionManager.shared.syncWithAuth(user: user)

            return LinkAccountResult(
                success: true,
                message: msg,
                user: user,
                migratedCalculations: migratedCalcs,
                migratedNotes: migratedNotes,
                migratedSubscriptions: migratedSubs
            )
        } catch {
            await MainActor.run {
                self.lastErrorMessage = error.localizedDescription
            }
            throw error
        }
    }

    // MARK: - Sign Out (Reverts to Anonymous Guest Mode)

    /// Signs out the active user session.
    /// Reverts to 100% anonymous Guest Mode without destroying on-device data.
    public func signOut() {
        clearPersistedSession()
        Task {
            await SubscriptionManager.shared.fetchSubscriptionStatus()
        }
    }
}
