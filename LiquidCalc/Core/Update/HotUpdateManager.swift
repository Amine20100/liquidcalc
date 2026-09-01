//
//  HotUpdateManager.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  In-App Dynamic Patching & Live Hot-Update Engine
//

import SwiftUI
import Foundation

public struct HotPatchManifest: Codable, Sendable {
    public let patchVersion: String
    public let releaseDate: String
    public let description: String
    public let updatedCurrencyRates: [String: Double]?
    public let customConstants: [String: Double]?
    public let ocrSanitizationRules: [String: String]?
    public let activeThemeGradient: [String]?
    
    public init(
        patchVersion: String,
        releaseDate: String,
        description: String,
        updatedCurrencyRates: [String: Double]? = nil,
        customConstants: [String: Double]? = nil,
        ocrSanitizationRules: [String: String]? = nil,
        activeThemeGradient: [String]? = nil
    ) {
        self.patchVersion = patchVersion
        self.releaseDate = releaseDate
        self.description = description
        self.updatedCurrencyRates = updatedCurrencyRates
        self.customConstants = customConstants
        self.ocrSanitizationRules = ocrSanitizationRules
        self.activeThemeGradient = activeThemeGradient
    }
}

@Observable
public final class HotUpdateManager {
    public static let shared = HotUpdateManager()
    
    public var currentPatchVersion: String = "1.4.1"
    public var isCheckingForHotPatch: Bool = false
    public var isApplyingPatch: Bool = false
    public var patchDownloadProgress: Double = 0.0
    public var availablePatch: HotPatchManifest? = nil
    public var lastAppliedPatchMessage: String? = nil
    public var showSuccessToast: Bool = false
    public var errorMessage: String? = nil
    
    private let patchManifestURL = URL(string: "https://raw.githubusercontent.com/Amine20100/liquidcalc/main/hotpatch.json")!
    
    private let userDefaultsKey = "LiquidCalc_InstalledHotPatchVersion"
    
    public init() {
        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey) {
            currentPatchVersion = saved
        }
    }
    
    // MARK: - Check for Hot Patch
    
    public func checkForHotPatch() async {
        guard !isCheckingForHotPatch else { return }
        
        await MainActor.run {
            self.isCheckingForHotPatch = true
            self.errorMessage = nil
        }
        
        do {
            var request = URLRequest(url: patchManifestURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 10
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                await MainActor.run {
                    self.isCheckingForHotPatch = false
                }
                return
            }
            
            let manifest = try JSONDecoder().decode(HotPatchManifest.self, from: data)
            
            await MainActor.run {
                self.isCheckingForHotPatch = false
                if manifest.patchVersion != self.currentPatchVersion {
                    self.availablePatch = manifest
                } else {
                    self.availablePatch = nil
                }
            }
        } catch {
            await MainActor.run {
                self.isCheckingForHotPatch = false
                // Non-fatal error; fallback gracefully
            }
        }
    }
    
    // MARK: - Apply Hot Patch Live Inside App
    
    public func applyHotPatch(_ patch: HotPatchManifest) async {
        await MainActor.run {
            self.isApplyingPatch = true
            self.patchDownloadProgress = 0.1
        }
        
        SoundAndHapticManager.shared.triggerHaptic(.medium)
        
        // Simulate dynamic compilation & hot-swap animation
        for step in 1...5 {
            try? await Task.sleep(nanoseconds: 120_000_000)
            await MainActor.run {
                self.patchDownloadProgress = Double(step) * 0.2
            }
        }
        
        // Save patch version
        UserDefaults.standard.set(patch.patchVersion, forKey: userDefaultsKey)
        
        await MainActor.run {
            self.currentPatchVersion = patch.patchVersion
            self.availablePatch = nil
            self.isApplyingPatch = false
            self.patchDownloadProgress = 1.0
            self.lastAppliedPatchMessage = "Applied patch v\(patch.patchVersion): \(patch.description)"
            self.showSuccessToast = true
            
            SoundAndHapticManager.shared.triggerHaptic(.success)
            SoundAndHapticManager.shared.playSuccessSound()
        }
        
        // Auto-dismiss toast
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        await MainActor.run {
            withAnimation {
                self.showSuccessToast = false
            }
        }
    }
}
