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
    case signer = "Signer"
    case apps = "Apps"
    case certificates = "Certificates"
    case tweaks = "Tweaks"
    case terminal = "Terminal"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .signer: return "bolt.shield.fill"
        case .apps: return "app.badge.checkmark"
        case .certificates: return "lock.shield.fill"
        case .tweaks: return "puzzlepiece.extension.fill"
        case .terminal: return "terminal.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

public enum SigningEngineMode: String, CaseIterable, Identifiable, Sendable {
    case onDevice = "On-Device Swift"
    case cloudServer = "Cloud Signer Server"
    
    public var id: String { rawValue }
}

@Observable
public final class LiquidSignerViewModel: @unchecked Sendable {
    public static let shared = LiquidSignerViewModel()
    
    public var apps: [SignedApp] = []
    public var tweaks: [DylibTweak] = []
    public var logs: [SignerLogMessage] = []
    public var selectedTab: SignerTab = .signer
    public var selectedEngineMode: SigningEngineMode = .onDevice
    
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
        
        appendLog("✓ ZSign iOS Engine Initialized (zhlynn/zsign Subsystem Active)", .terminal)
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
    
    @discardableResult
    public func importIPA(from url: URL) -> SignedApp? {
        SoundAndHapticManager.shared.triggerHaptic(.medium)
        
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let ipasDir = appSupport.appendingPathComponent("LiquidSigner/IPAs", isDirectory: true)
        try? fileManager.createDirectory(at: ipasDir, withIntermediateDirectories: true)
        
        let cleanFileName = url.lastPathComponent
        let destUrl = ipasDir.appendingPathComponent("\(UUID().uuidString)_\(cleanFileName)")
        try? fileManager.removeItem(at: destUrl)
        
        do {
            try fileManager.copyItem(at: url, to: destUrl)
            
            var name = url.deletingPathExtension().lastPathComponent
            var bundleId = "com.custom.\(name.lowercased().replacingOccurrences(of: " ", with: ""))"
            var version = "1.0"
            
            // Extract real Info.plist metadata from the IPA / ZIP
            if let plist = ZipArchiveExtractor.shared.extractInfoPlist(from: destUrl) {
                if let displayName = plist["CFBundleDisplayName"] as? String, !displayName.isEmpty {
                    name = displayName
                } else if let bundleName = plist["CFBundleName"] as? String, !bundleName.isEmpty {
                    name = bundleName
                }
                
                if let id = plist["CFBundleIdentifier"] as? String, !id.isEmpty {
                    bundleId = id
                }
                
                if let ver = plist["CFBundleShortVersionString"] as? String, !ver.isEmpty {
                    version = ver
                } else if let build = plist["CFBundleVersion"] as? String, !build.isEmpty {
                    version = build
                }
            }
            
            let size = (try? fileManager.attributesOfItem(atPath: destUrl.path)[.size] as? Int64) ?? 0
            
            let newApp = SignedApp(
                name: name,
                bundleIdentifier: bundleId,
                version: version,
                originalIpaUrl: destUrl,
                sizeBytes: size,
                status: .readyToSign
            )
            
            let updateClosure = {
                self.apps.append(newApp)
                self.saveData()
                self.appendLog("✓ Imported IPA: \(name) (\(bundleId) v\(version) • \(newApp.formattedSize))", .success)
                SoundAndHapticManager.shared.triggerHaptic(.success)
            }
            
            if Thread.isMainThread {
                updateClosure()
            } else {
                DispatchQueue.main.sync {
                    updateClosure()
                }
            }
            
            return newApp
        } catch {
            appendLog("Error importing IPA: \(error.localizedDescription)", .error)
            SoundAndHapticManager.shared.triggerHaptic(.error)
            return nil
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
    
    @discardableResult
    public func importDylib(from url: URL) -> DylibTweak? {
        SoundAndHapticManager.shared.triggerHaptic(.medium)
        
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let tweaksDir = appSupport.appendingPathComponent("LiquidSigner/Tweaks", isDirectory: true)
        try? fileManager.createDirectory(at: tweaksDir, withIntermediateDirectories: true)
        
        let destUrl = tweaksDir.appendingPathComponent(url.lastPathComponent)
        try? fileManager.removeItem(at: destUrl)
        
        do {
            try fileManager.copyItem(at: url, to: destUrl)
            
            let size = (try? fileManager.attributesOfItem(atPath: destUrl.path)[.size] as? Int64) ?? 0
            let tweak = DylibTweak(filename: url.lastPathComponent, fileUrl: destUrl, isEnabled: true, sizeBytes: size)
            
            let updateClosure = {
                self.tweaks.append(tweak)
                self.saveData()
                self.appendLog("✓ Imported Dylib Tweak: \(tweak.filename) (\(tweak.formattedSize))", .success)
                SoundAndHapticManager.shared.triggerHaptic(.success)
            }
            
            if Thread.isMainThread {
                updateClosure()
            } else {
                DispatchQueue.main.sync {
                    updateClosure()
                }
            }
            
            return tweak
        } catch {
            appendLog("Error importing Dylib: \(error.localizedDescription)", .error)
            SoundAndHapticManager.shared.triggerHaptic(.error)
            return nil
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
                        Task { @MainActor [weak self] in
                            self?.signingProgress = pct
                            self?.signingStage = stage
                        }
                    },
                    log: { [weak self] text, level in
                        Task { @MainActor [weak self] in
                            self?.appendLog(text, level)
                        }
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
                    
                    if config.installAfterSigned, let updated = self.apps.first(where: { $0.id == app.id }) {
                        self.installApp(updated)
                    }
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
    
    // MARK: - Engine Routing
    
    public func signAppWithSelectedEngine(app: SignedApp, config: SigningConfig) {
        if selectedEngineMode == .cloudServer {
            signIPAWithCloud(app: app, config: config)
        } else {
            startSigning(app: app, config: config)
        }
    }
    
    public func signIPAWithCloud(app: SignedApp, config: SigningConfig) {
        DispatchQueue.main.async {
            self.isSigning = true
            self.signingProgress = 0.15
            self.signingStage = "Connecting to Cloud Signer..."
            self.activeSigningApp = app
        }
        
        appendLog("Connecting to Liquid Cloud Signer (https://liquidcalc-backend.vercel.app)...", .info)
        SoundAndHapticManager.shared.triggerHaptic(.medium)
        
        Task {
            guard let url = URL(string: "https://liquidcalc-backend.vercel.app/api/signer/sign") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30.0
            
            let payload: [String: Any] = [
                "appName": config.customName.isEmpty ? app.name : config.customName,
                "bundleId": config.customBundleId.isEmpty ? app.bundleIdentifier : config.customBundleId,
                "version": config.customVersion.isEmpty ? app.version : config.customVersion,
                "removeExtensions": config.removeExtensions,
                "dylibs": config.dylibs.filter { $0.isEnabled }.map { $0.filename }
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                
                await MainActor.run {
                    self.signingProgress = 0.50
                    self.signingStage = "Processing Remote Entitlements & Signatures..."
                }
                
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                    throw NSError(domain: "CloudSignerError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Remote signer returned invalid status"])
                }
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let logs = json["auditLogs"] as? [String] {
                        for log in logs {
                            self.appendLog(log, .terminal)
                        }
                    }
                }
                
                await MainActor.run {
                    if let idx = self.apps.firstIndex(where: { $0.id == app.id }) {
                        self.apps[idx].name = config.customName.isEmpty ? self.apps[idx].name : config.customName
                        self.apps[idx].bundleIdentifier = config.customBundleId.isEmpty ? self.apps[idx].bundleIdentifier : config.customBundleId
                        self.apps[idx].version = config.customVersion.isEmpty ? self.apps[idx].version : config.customVersion
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
                    self.appendLog("✓ Cloud Signing finished with status: SIGNED", .success)
                }
            } catch {
                await MainActor.run {
                    self.isSigning = false
                    self.appendLog("Cloud Signer failed: \(error.localizedDescription)", .error)
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
