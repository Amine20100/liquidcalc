//
//  DeviceSyncManager.swift
//  LiquidCalc
//
//  Manages Mobile Client Device Identity & Token Verification via Obfuscated Transport
//  Created for LiquidCalc iOS 18+.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

@Observable
public final class DeviceSyncManager: @unchecked Sendable {
    public static let shared = DeviceSyncManager()

    public private(set) var deviceId: String
    public private(set) var deviceToken: String?
    public private(set) var isVerified: Bool = false
    public private(set) var lastSyncDate: Date? = nil

    private let deviceIdKey = "LiquidCalc_DeviceID_v1"
    private let deviceTokenKey = "LiquidCalc_DeviceToken_v1"

    public init() {
        if let storedId = UserDefaults.standard.string(forKey: deviceIdKey), !storedId.isEmpty {
            self.deviceId = storedId
        } else {
            let newId = "ios_\(Int64(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8).lowercased())"
            self.deviceId = newId
            UserDefaults.standard.set(newId, forKey: deviceIdKey)
        }
        self.deviceToken = UserDefaults.standard.string(forKey: deviceTokenKey)
    }

    /// Obtains an authenticated mobile device token from the backend through the encrypted pipeline.
    @discardableResult
    public func bootstrapDeviceToken() async throws -> String {
        #if canImport(UIKit)
        let deviceName = UIDevice.current.name
        #else
        let deviceName = "Apple Client Device"
        #endif

        let payload: [String: Any] = [
            "deviceId": deviceId,
            "platform": "ios",
            "name": deviceName
        ]

        let (data, _) = try await CryptoTransport.shared.performEncryptedRequest(
            endpoint: "/api/auth/device",
            method: "POST",
            jsonPayload: payload
        )

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["deviceToken"] as? String else {
            throw CryptoTransportError.serializationError("Invalid device token response")
        }

        await MainActor.run {
            self.deviceToken = token
            self.isVerified = true
            self.lastSyncDate = Date()
            UserDefaults.standard.set(token, forKey: self.deviceTokenKey)
        }

        return token
    }

    /// Verifies the current device token against the backend.
    public func verifyDeviceToken() async throws -> Bool {
        guard let token = deviceToken, !token.isEmpty else {
            _ = try await bootstrapDeviceToken()
            return true
        }

        let payload: [String: Any] = ["token": token]
        let headers = ["X-Device-Token": token]

        do {
            let (data, _) = try await CryptoTransport.shared.performEncryptedRequest(
                endpoint: "/api/auth/device/verify",
                method: "POST",
                jsonPayload: payload,
                headers: headers
            )

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let valid = json["valid"] as? Bool {
                await MainActor.run {
                    self.isVerified = valid
                    self.lastSyncDate = Date()
                }
                return valid
            }
        } catch let CryptoTransportError.invalidResponse(code, _) where code == 401 || code == 404 {
            // Token invalidated or expired on backend; auto-recover and re-bootstrap
            _ = try await bootstrapDeviceToken()
            return true
        }

        return false
    }
}
