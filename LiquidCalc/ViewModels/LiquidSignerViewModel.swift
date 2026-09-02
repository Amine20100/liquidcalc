//
//  LiquidSignerViewModel.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Liquid Signer Hidden Vault ViewModel
//

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

public enum SignerTab: String, CaseIterable, Identifiable {
    case apps = "Apps"
    case certificates = "Certificates"
    case tweaks = "Tweaks"
    case terminal = "Terminal"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .apps: return "app.badge.checkmark"
        case .certificates: return "lock.shield.fill"
        case .tweaks: return "puzzlepiece.extension.fill"
        case .terminal: return "terminal.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

@Observable
public final class LiquidSignerViewModel: @unchecked Sendable {
    public static let shared = LiquidSignerViewModel()
    
    public var apps: [SignedApp] = []
    public var tweaks: [DylibTweak] = []
    public var logs: [SignerLogMessage] = []
    public var selectedTab: SignerTab = .apps
    
    public var isSigning: Bool = false
    public var signingProgress: Double = 0.0
    public var signingStage: String = ""
    public var activeSigningApp: SignedApp? = nil
    
    public var showSignConfigSheet: Bool = false
    public var selectedAppForConfig: SignedApp? = nil
    
    public var showShareSheet: Bool = false
    public var shareUrl: URL? = nil
    
    public var showInstallAlert: Bool = false
    public var installedAppName: String = ""
    
    private let fileManager = FileManager.default
    private let appsStorageKey = "LiquidSigner_Apps_v1"
    private let tweaksStorageKey = "LiquidSigner_Tweaks_v1"
    
    public init() {
        loadSavedData()
        
        // If empty, add a sample demo app so the user can test immediately
        if apps.isEmpty {
            createSampleDemoApp()
        }
        
        appendLog("✓ Liquid Signer Vault initialized (Security Subsystem Active)", .terminal)
    }
    
    // MARK: - Logging
    
    public func appendLog(_ text: String, _ level: SignerLogMessage.LogLevel = .info) {
        let msg = SignerLogMessage(text: text, level: level)
        DispatchQueue.main.async {
            self.logs.append(msg)
        }
    }
    
    public func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
            self.appendLog("✓ Terminal session reset", .terminal)
        }
    }
    
    // MARK: - App Import & Management
    
    public func importIPA(from url: URL) {
        SoundAndHapticManager.shared.triggerHaptic(.medium)
        
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let ipasDir = appSupport.appendingPathComponent("LiquidSigner/IPAs", isDirectory: true)
        try? fileManager.createDirectory(at: ipasDir, withIntermediateDirectories: true)
        
        let destUrl = ipasDir.appendingPathComponent("\(UUID().uuidString)_\(url.lastPathComponent)")
        
        do {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                try fileManager.copyItem(at: url, to: destUrl)
            } else {
                try fileManager.copyItem(at: url, to: destUrl)
            }
            
            let name = url.deletingPathExtension().lastPathComponent
            let size = (try? fileManager.attributesOfItem(atPath: destUrl.path)[.size] as? Int64) ?? 0
            
            let newApp = SignedApp(
                name: name,
                bundleIdentifier: "com.custom.\(name.lowercased().replacingOccurrences(of: " ", with: ""))",
                version: "1.0",
                originalIpaUrl: destUrl,
                sizeBytes: size,
                status: .readyToSign
            )
            
            DispatchQueue.main.async {
                self.apps.append(newApp)
                self.saveData()
                self.appendLog("✓ Imported IPA: \(name) (\(newApp.formattedSize))", .success)
                SoundAndHapticManager.shared.triggerHaptic(.success)
            }
        } catch {
            appendLog("Error importing IPA: \(error.localizedDescription)", .error)
            SoundAndHapticManager.shared.triggerHaptic(.error)
        }
    }
    
    public func deleteApp(_ app: SignedApp) {
        if let original = app.originalIpaUrl { try? fileManager.removeItem(at: original) }
        if let signed = app.signedIpaUrl { try? fileManager.removeItem(at: signed) }
        apps.removeAll { $0.id == app.id }
        saveData()
        appendLog("Deleted app entry: \(app.name)", .info)
        SoundAndHapticManager.shared.triggerHaptic(.light)
    }
    
    // MARK: - Tweak Import & Management
    
    public func importDylib(from url: URL) {
        SoundAndHapticManager.shared.triggerHaptic(.medium)
        
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let tweaksDir = appSupport.appendingPathComponent("LiquidSigner/Tweaks", isDirectory: true)
        try? fileManager.createDirectory(at: tweaksDir, withIntermediateDirectories: true)
        
        let destUrl = tweaksDir.appendingPathComponent(url.lastPathComponent)
        try? fileManager.removeItem(at: destUrl)
        
        do {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                try fileManager.copyItem(at: url, to: destUrl)
            } else {
                try fileManager.copyItem(at: url, to: destUrl)
            }
            
            let size = (try? fileManager.attributesOfItem(atPath: destUrl.path)[.size] as? Int64) ?? 0
            let tweak = DylibTweak(filename: url.lastPathComponent, fileUrl: destUrl, isEnabled: true, sizeBytes: size)
            
            DispatchQueue.main.async {
                self.tweaks.append(tweak)
                self.saveData()
                self.appendLog("✓ Imported Dylib Tweak: \(tweak.filename) (\(tweak.formattedSize))", .success)
                SoundAndHapticManager.shared.triggerHaptic(.success)
            }
        } catch {
            appendLog("Error importing Dylib: \(error.localizedDescription)", .error)
            SoundAndHapticManager.shared.triggerHaptic(.error)
        }
    }
    
    public func toggleTweak(_ tweak: DylibTweak) {
        if let idx = tweaks.firstIndex(where: { $0.id == tweak.id }) {
            tweaks[idx].isEnabled.toggle()
            saveData()
            SoundAndHapticManager.shared.triggerHaptic(.light)
        }
    }
    
    public func deleteTweak(_ tweak: DylibTweak) {
        try? fileManager.removeItem(at: tweak.fileUrl)
        tweaks.removeAll { $0.id == tweak.id }
        saveData()
        appendLog("Removed tweak: \(tweak.filename)", .info)
        SoundAndHapticManager.shared.triggerHaptic(.light)
    }
    
    // MARK: - Signing Execution
    
    public func startSigning(app: SignedApp, config: SigningConfig) {
        guard let ipaUrl = app.originalIpaUrl else {
            appendLog("Error: Original IPA file not found for \(app.name)", .error)
            return
        }
        
        DispatchQueue.main.async {
            self.isSigning = true
            self.signingProgress = 0.0
            self.signingStage = "Initializing..."
            self.activeSigningApp = app
        }
        
        SoundAndHapticManager.shared.triggerHaptic(.medium)
        
        Task {
            do {
                let signedUrl = try await LiquidSignEngine.shared.signIPA(
                    inputIpaUrl: ipaUrl,
                    config: config,
                    progress: { [weak self] pct, stage in
                        DispatchQueue.main.async {
                            self?.signingProgress = pct
                            self?.signingStage = stage
                        }
                    },
                    log: { [weak self] text, level in
                        self?.appendLog(text, level)
                    }
                )
                
                await MainActor.run {
                    if let idx = self.apps.firstIndex(where: { $0.id == app.id }) {
                        self.apps[idx].name = config.customName.isEmpty ? self.apps[idx].name : config.customName
                        self.apps[idx].bundleIdentifier = config.customBundleId.isEmpty ? self.apps[idx].bundleIdentifier : config.customBundleId
                        self.apps[idx].version = config.customVersion.isEmpty ? self.apps[idx].version : config.customVersion
                        self.apps[idx].signedIpaUrl = signedUrl
                        self.apps[idx].dateSigned = Date()
                        self.apps[idx].status = .signed
                        self.apps[idx].injectedDylibs = config.dylibs.filter { $0.isEnabled }.map { $0.filename }
                        self.saveData()
                    }
                    
                    self.isSigning = false
                    self.signingProgress = 1.0
                    self.activeSigningApp = self.apps.first(where: { $0.id == app.id })
                    SoundAndHapticManager.shared.triggerHaptic(.success)
                    SoundAndHapticManager.shared.playSuccessSound()
                }
            } catch {
                await MainActor.run {
                    self.isSigning = false
                    self.appendLog("Signing failed: \(error.localizedDescription)", .error)
                    if let idx = self.apps.firstIndex(where: { $0.id == app.id }) {
                        self.apps[idx].status = .failed
                    }
                    SoundAndHapticManager.shared.triggerHaptic(.error)
                }
            }
        }
    }
    
    // MARK: - Direct 1-Tap Install & Share
    
    public func installApp(_ app: SignedApp) {
        guard let signedUrl = app.signedIpaUrl ?? app.originalIpaUrl else {
            appendLog("Cannot install: No signed package available.", .error)
            return
        }
        
        appendLog("🚀 Launching local OTA installation server for: \(app.name)...", .info)
        LocalInstallServer.shared.installApp(
            signedIpaUrl: signedUrl,
            bundleId: app.bundleIdentifier,
            appName: app.name
        )
        
        self.installedAppName = app.name
        self.showInstallAlert = true
    }
    
    public func installWithTrollStore(_ app: SignedApp) {
        guard let signedUrl = app.signedIpaUrl ?? app.originalIpaUrl else {
            appendLog("Cannot install: No signed package available.", .error)
            return
        }
        
        let path = signedUrl.path
        let escapedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
        let tsUrlString = "apple-magnifier://install?url=file://\(escapedPath)"
        
        #if canImport(UIKit)
        if let url = URL(string: tsUrlString) {
            UIApplication.shared.open(url, options: [:]) { [weak self] success in
                if success {
                    self?.appendLog("✓ Dispatched installation to TrollStore", .success)
                    SoundAndHapticManager.shared.triggerHaptic(.success)
                } else {
                    let fallbackUrlString = "trollstore://install?url=file://\(escapedPath)"
                    if let altUrl = URL(string: fallbackUrlString) {
                        UIApplication.shared.open(altUrl, options: [:]) { altSuccess in
                            if altSuccess {
                                self?.appendLog("✓ Dispatched to TrollStore fallback scheme", .success)
                                SoundAndHapticManager.shared.triggerHaptic(.success)
                            } else {
                                self?.appendLog("TrollStore scheme not found. Try 1-Tap Wireless OTA or Share Sheet.", .warning)
                                SoundAndHapticManager.shared.triggerHaptic(.warning)
                            }
                        }
                    }
                }
            }
        }
        #endif
    }
    
    public func shareApp(_ app: SignedApp) {
        guard let url = app.signedIpaUrl ?? app.originalIpaUrl else { return }
        self.shareUrl = url
        self.showShareSheet = true
        SoundAndHapticManager.shared.triggerHaptic(.light)
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(encoded, forKey: appsStorageKey)
        }
        if let encoded = try? JSONEncoder().encode(tweaks) {
            UserDefaults.standard.set(encoded, forKey: tweaksStorageKey)
        }
    }
    
    private func loadSavedData() {
        if let data = UserDefaults.standard.data(forKey: appsStorageKey),
           let decoded = try? JSONDecoder().decode([SignedApp].self, from: data) {
            self.apps = decoded
        }
        if let data = UserDefaults.standard.data(forKey: tweaksStorageKey),
           let decoded = try? JSONDecoder().decode([DylibTweak].self, from: data) {
            self.tweaks = decoded
        }
    }
    
    private func createSampleDemoApp() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let demoUrl = appSupport.appendingPathComponent("LiquidSigner/IPAs/FlappyBird.ipa")
        try? fileManager.createDirectory(at: demoUrl.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        // Write minimal dummy binary archive so user can immediately test signing
        let dummyData = Data([0x50, 0x4B, 0x03, 0x04]) + Data(repeating: 0x00, count: 512)
        try? dummyData.write(to: demoUrl)
        
        let sampleApp = SignedApp(
            name: "Flappy Bird Classic",
            bundleIdentifier: "com.dotgears.flappybird",
            version: "1.2",
            originalIpaUrl: demoUrl,
            sizeBytes: 8_420_000,
            status: .readyToSign
        )
        
        let sampleTweak = DylibTweak(
            filename: "libLiquidSpeedUp.dylib",
            fileUrl: appSupport.appendingPathComponent("LiquidSigner/Tweaks/libLiquidSpeedUp.dylib"),
            isEnabled: true,
            sizeBytes: 124_000
        )
        
        self.apps = [sampleApp]
        self.tweaks = [sampleTweak]
        saveData()
    }
}
