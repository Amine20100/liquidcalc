//
//  TelemetryManager.swift
//  LiquidCalc
//
//  Mobile Telemetry & Crash Reporting Client via Obfuscated Transport
//  Created for LiquidCalc iOS 18+.
//

import Foundation

public final class TelemetryManager: @unchecked Sendable {
    public static let shared = TelemetryManager()

    public var isEnabled: Bool = true
    private let appVersion: String = "2.3.0"
    private var breadcrumbs: [String] = []
    private let maxBreadcrumbs = 20
    private let queue = DispatchQueue(label: "com.liquidcalc.telemetry", qos: .utility)

    public init() {}

    public func addBreadcrumb(_ text: String) {
        queue.async {
            self.breadcrumbs.append("[\(ISO8601DateFormatter().string(from: Date()))] \(text)")
            if self.breadcrumbs.count > self.maxBreadcrumbs {
                self.breadcrumbs.removeFirst(self.breadcrumbs.count - self.maxBreadcrumbs)
            }
        }
    }

    /// Records an analytics or calculation performance event through the obfuscated pipeline.
    public func recordEvent(
        name: String,
        type: String = "usage",
        payload: [String: Any] = [:]
    ) {
        guard isEnabled else { return }

        let deviceId = DeviceSyncManager.shared.deviceId
        let eventPayload: [String: Any] = [
            "name": name,
            "type": type,
            "deviceId": deviceId,
            "appVersion": appVersion,
            "osVersion": "iOS 18+",
            "payload": payload
        ]

        Task.detached(priority: .utility) {
            do {
                _ = try await CryptoTransport.shared.performEncryptedRequest(
                    endpoint: "/api/telemetry/event",
                    method: "POST",
                    jsonPayload: eventPayload
                )
            } catch {
                // Telemetry is non-critical; suppress network drops silently
            }
        }
    }

    /// Submits an encrypted crash or unhandled exception report.
    public func recordCrash(
        error: String,
        stackTrace: String = "",
        additionalContext: [String: Any] = [:]
    ) {
        guard isEnabled else { return }

        let deviceId = DeviceSyncManager.shared.deviceId
        var currentCrumbs: [String] = []
        queue.sync {
            currentCrumbs = self.breadcrumbs
        }

        let crashPayload: [String: Any] = [
            "error": error,
            "stackTrace": stackTrace,
            "deviceId": deviceId,
            "appVersion": appVersion,
            "osVersion": "iOS 18+",
            "breadcrumbs": currentCrumbs,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "context": additionalContext
        ]

        Task.detached(priority: .userInitiated) {
            do {
                _ = try await CryptoTransport.shared.performEncryptedRequest(
                    endpoint: "/api/telemetry/crash",
                    method: "POST",
                    jsonPayload: crashPayload
                )
            } catch {
                // Suppress failure
            }
        }
    }
}
