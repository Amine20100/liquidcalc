//
//  AppUpdateManager.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Multi-Tier Updating Engine: Dual-Source Verification, In-App Background Downloading,
//  1-Tap Wireless OTA Installation, and Liquid Signer Handoff.
//

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// State of an in-app download operation.
public enum UpdateDownloadState: Equatable, Sendable {
    case idle
    case downloading(progress: Double, bytesWritten: Int64, totalBytes: Int64, speedString: String)
    case completed(fileURL: URL)
    case failed(error: String)
    
    public var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }
    
    public var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }
    
    public var progressValue: Double {
        switch self {
        case .downloading(let progress, _, _, _): return progress
        case .completed: return 1.0
        default: return 0.0
        }
    }
}

/// Service managing online update checks against LiquidCalc Serverless Backend and GitHub Releases API.
@Observable
public final class AppUpdateManager: NSObject, @unchecked Sendable, URLSessionDownloadDelegate {
    
    // MARK: - Singleton
    
    public static let shared = AppUpdateManager()
    
    // MARK: - Endpoints & Constants
    
    public static let primaryBackendAPIURL = URL(string: "https://liquidcalc-backend.vercel.app/api/updates/latest")!
    public static let defaultRepoAPIURL = URL(string: "https://api.github.com/repos/Amine20100/liquidcalc/releases/latest")!
    public static let defaultOTAHost = "https://liquidcalc-backend.vercel.app"
    
    public static let autoCheckDefaultsKey = "LC_AutoCheckOnLaunch"
    public static let lastCheckDateDefaultsKey = "LC_LastUpdateCheckDate"
    public static let updateChannelDefaultsKey = "LC_UpdateChannelSelection"
    
    // MARK: - Observable State
    
    public var isChecking: Bool = false
    public var updateAvailable: Bool = false
    public var latestRelease: GitHubRelease? = nil
    public var errorMessage: String? = nil
    
    // Presentation States
    public var showUpdateSheet: Bool = false
    public var showNoUpdateAlert: Bool = false
    public var hasPendingUpdateBanner: Bool = false
    public var isBannerDismissed: Bool = false
    public var showShareSheet: Bool = false
    
    // In-App Download State
    public var downloadState: UpdateDownloadState = .idle
    public var downloadedFileURL: URL? = nil
    
    // Update Channel (Stable vs Pre-release / Beta)
    public var includePreReleases: Bool {
        didSet {
            userDefaults.set(includePreReleases, forKey: Self.updateChannelDefaultsKey)
        }
    }
    
    public var autoCheckOnLaunch: Bool {
        didSet {
            userDefaults.set(autoCheckOnLaunch, forKey: Self.autoCheckDefaultsKey)
        }
    }
    
    public var lastCheckedDate: Date? {
        didSet {
            if let date = lastCheckedDate {
                userDefaults.set(date.timeIntervalSince1970, forKey: Self.lastCheckDateDefaultsKey)
            } else {
                userDefaults.removeObject(forKey: Self.lastCheckDateDefaultsKey)
            }
        }
    }
    
    // MARK: - App Version Metadata
    
    public let currentVersionString: String
    public let currentBuildString: String
    public let currentSemanticVersion: SemanticVersion
    
    // MARK: - Dependencies & Download Engine
    
    public let primaryAPIURL: URL
    public let fallbackAPIURL: URL
    private var urlSession: URLSession
    private let userDefaults: UserDefaults
    
    private var downloadTask: URLSessionDownloadTask? = nil
    private var lastSpeedSampleTime: TimeInterval = 0
    private var lastBytesWrittenSample: Int64 = 0
    private var currentSpeedString: String = "0 KB/s"
    
    // MARK: - Initializer
    
    public init(
        primaryAPIURL: URL = AppUpdateManager.primaryBackendAPIURL,
        fallbackAPIURL: URL = AppUpdateManager.defaultRepoAPIURL,
        urlSession: URLSession? = nil,
        userDefaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        customCurrentVersion: String? = nil
    ) {
        self.primaryAPIURL = primaryAPIURL
        self.fallbackAPIURL = fallbackAPIURL
        self.userDefaults = userDefaults
        
        let version = customCurrentVersion
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "2.7.0"
        let build = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "27"
        
        self.currentVersionString = version
        self.currentBuildString = build
        self.currentSemanticVersion = SemanticVersion(version) ?? SemanticVersion(major: 2, minor: 7, patch: 0)
        
        self.autoCheckOnLaunch = userDefaults.object(forKey: Self.autoCheckDefaultsKey) == nil ? true : userDefaults.bool(forKey: Self.autoCheckDefaultsKey)
        self.includePreReleases = userDefaults.bool(forKey: Self.updateChannelDefaultsKey)
        
        let savedTimestamp = userDefaults.double(forKey: Self.lastCheckDateDefaultsKey)
        self.lastCheckedDate = savedTimestamp > 0 ? Date(timeIntervalSince1970: savedTimestamp) : nil
        
        // Initial dummy session until super.init() completes
        self.urlSession = urlSession ?? .shared
        super.init()
        
        // Set up delegate-enabled session for download tracking if default
        if urlSession == nil {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30.0
            config.waitsForConnectivity = true
            self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        }
    }
    
    // MARK: - Dual-Source Update Checking
    
    /// Queries the primary Vercel serverless backend, falling back seamlessly to GitHub Releases REST API.
    @MainActor
    @discardableResult
    public func checkForUpdates(manual: Bool = false) async -> Bool {
        isChecking = true
        errorMessage = nil
        
        defer {
            isChecking = false
        }
        
        // 1. Try Primary Vercel Backend
        if let release = await fetchRelease(from: primaryAPIURL) {
            return processFetchedRelease(release, manual: manual)
        }
        
        // 2. Fallback to GitHub API
        if let release = await fetchRelease(from: fallbackAPIURL) {
            return processFetchedRelease(release, manual: manual)
        }
        
        // Both failed
        if errorMessage == nil {
            errorMessage = "Unable to connect to update servers. Check your internet connection."
        }
        
        if manual {
            SoundAndHapticManager.shared.triggerHaptic(.error)
        }
        return false
    }
    
    private func fetchRelease(from url: URL) async -> GitHubRelease? {
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 12.0
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("LiquidCalc-iOS/\(currentVersionString)", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(GitHubRelease.self, from: data)
        } catch {
            return nil
        }
    }
    
    @MainActor
    private func processFetchedRelease(_ release: GitHubRelease, manual: Bool) -> Bool {
        self.latestRelease = release
        self.lastCheckedDate = Date()
        
        let isNewer = isUpdateAvailable(for: release)
        self.updateAvailable = isNewer
        
        if isNewer {
            if manual {
                self.showUpdateSheet = true
                SoundAndHapticManager.shared.triggerHaptic(.success)
            } else if !isBannerDismissed {
                self.hasPendingUpdateBanner = true
            }
        } else if manual {
            self.showNoUpdateAlert = true
            SoundAndHapticManager.shared.triggerHaptic(.light)
        }
        
        return isNewer
    }
    
    /// Evaluates if release version is strictly higher than current running version.
    public func isUpdateAvailable(for release: GitHubRelease) -> Bool {
        if release.isPrerelease == true && !includePreReleases {
            return false
        }
        guard let releaseSemVer = release.semanticVersion else {
            return false
        }
        return releaseSemVer > currentSemanticVersion
    }
    
    // MARK: - In-App Background Download Engine
    
    /// Starts in-app download of the IPA installation package with live progress and speed reporting.
    public func startDownload(for release: GitHubRelease? = nil) {
        let targetRelease = release ?? latestRelease
        guard let ipaUrl = targetRelease?.ipaDownloadURL else {
            Task { @MainActor in
                self.downloadState = .failed(error: "No downloadable IPA package found for this release.")
            }
            return
        }
        
        // Cancel existing task if running
        downloadTask?.cancel()
        
        SoundAndHapticManager.shared.triggerHaptic(.medium)
        Task { @MainActor in
            self.downloadState = .downloading(progress: 0.0, bytesWritten: 0, totalBytes: targetRelease?.ipaAsset?.size.map(Int64.init) ?? 0, speedString: "Connecting...")
        }
        lastSpeedSampleTime = CACurrentMediaTime()
        lastBytesWrittenSample = 0
        
        downloadTask = urlSession.downloadTask(with: ipaUrl)
        downloadTask?.resume()
    }
    
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        Task { @MainActor in
            self.downloadState = .idle
        }
        SoundAndHapticManager.shared.triggerHaptic(.light)
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let now = CACurrentMediaTime()
        let elapsed = now - lastSpeedSampleTime
        
        if elapsed >= 0.5 {
            let bytesDiff = totalBytesWritten - lastBytesWrittenSample
            let bytesPerSec = Double(bytesDiff) / elapsed
            currentSpeedString = formatSpeed(bytesPerSec)
            lastSpeedSampleTime = now
            lastBytesWrittenSample = totalBytesWritten
        }
        
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0.0
        
        DispatchQueue.main.async {
            self.downloadState = .downloading(
                progress: progress,
                bytesWritten: totalBytesWritten,
                totalBytes: totalBytesExpectedToWrite,
                speedString: self.currentSpeedString
            )
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let destination = tempDir.appendingPathComponent("LiquidCalc_Update_\(latestRelease?.tagName ?? "latest").ipa")
        
        try? fileManager.removeItem(at: destination)
        
        do {
            try fileManager.moveItem(at: location, to: destination)
            DispatchQueue.main.async {
                self.downloadedFileURL = destination
                self.downloadState = .completed(fileURL: destination)
                SoundAndHapticManager.shared.triggerHaptic(.success)
                SoundAndHapticManager.shared.playSuccessSound()
            }
        } catch {
            DispatchQueue.main.async {
                self.downloadState = .failed(error: "Failed to save downloaded update: \(error.localizedDescription)")
                SoundAndHapticManager.shared.triggerHaptic(.error)
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error, (error as NSError).code != NSURLErrorCancelled {
            DispatchQueue.main.async {
                self.downloadState = .failed(error: error.localizedDescription)
                SoundAndHapticManager.shared.triggerHaptic(.error)
            }
        }
    }
    
    // MARK: - Multi-Channel Installation Actions
    
    /// Generates dynamic 1-tap wireless OTA installation URL using Vercel backend.
    public func getOtaInstallURL(for release: GitHubRelease? = nil) -> URL {
        let target = release ?? latestRelease
        let version = target?.tagName.replacingOccurrences(of: "v", with: "") ?? currentVersionString
        let rawDownload = target?.ipaDownloadURL?.absoluteString ?? "https://github.com/Amine20100/liquidcalc/releases/download/\(target?.tagName ?? "v2.4.0")/LiquidCalc.ipa"
        
        let manifestEndpoint = "\(Self.defaultOTAHost)/api/ota/manifest?bundleId=com.liquidcalc.app&name=LiquidCalc&version=\(version)&url=\(rawDownload.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rawDownload)"
        let itmsUrl = "itms-services://?action=download-manifest&url=\(manifestEndpoint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? manifestEndpoint)"
        
        return URL(string: itmsUrl) ?? URL(string: "itms-services://?action=download-manifest&url=\(Self.defaultOTAHost)/manifest.plist")!
    }
    
    /// Launches 1-tap wireless installation dialog directly on iOS.
    public func installWirelesslyOTA(for release: GitHubRelease? = nil) {
        SoundAndHapticManager.shared.triggerHaptic(.heavy)
        let otaUrl = getOtaInstallURL(for: release)
        #if canImport(UIKit)
        UIApplication.shared.open(otaUrl, options: [:], completionHandler: nil)
        #endif
    }
    
    /// Generates TrollStore direct installation URL.
    public func getTrollStoreInstallURL(for release: GitHubRelease? = nil) -> URL? {
        guard let ipa = (release ?? latestRelease)?.ipaDownloadURL else { return nil }
        let encoded = ipa.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ipa.absoluteString
        return URL(string: "apple-magnifier://install?url=\(encoded)") ?? URL(string: "trollstore://install?url=\(encoded)")
    }
    
    /// Launches installation in TrollStore if installed on device.
    public func openInTrollStore(for release: GitHubRelease? = nil) {
        if let tsUrl = getTrollStoreInstallURL(for: release) {
            #if canImport(UIKit)
            UIApplication.shared.open(tsUrl, options: [:], completionHandler: nil)
            #endif
        }
    }
    
    // MARK: - Helpers
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_048_576 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_048_576)
        } else if bytesPerSecond >= 1024 {
            return String(format: "%.0f KB/s", bytesPerSecond / 1024)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }
    
    public func dismissUpdateSheet() {
        showUpdateSheet = false
    }
    
    public func dismissNoUpdateAlert() {
        showNoUpdateAlert = false
    }
    
    public func dismissBanner() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            hasPendingUpdateBanner = false
            isBannerDismissed = true
        }
    }
}
