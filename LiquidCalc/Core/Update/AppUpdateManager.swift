//
//  AppUpdateManager.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI
import Foundation

/// Service managing online update checks against GitHub Releases API (`https://api.github.com/repos/Amine20100/liquidcalc/releases/latest`).
@Observable
public final class AppUpdateManager: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = AppUpdateManager()
    
    // MARK: - Constants
    
    public static let defaultRepoAPIURL = URL(string: "https://api.github.com/repos/Amine20100/liquidcalc/releases/latest")!
    public static let autoCheckDefaultsKey = "LC_AutoCheckOnLaunch"
    public static let lastCheckDateDefaultsKey = "LC_LastUpdateCheckDate"
    
    // MARK: - Observable Properties
    
    public var isChecking: Bool = false
    public var updateAvailable: Bool = false
    public var latestRelease: GitHubRelease? = nil
    public var errorMessage: String? = nil
    public var showUpdateSheet: Bool = false
    public var showNoUpdateAlert: Bool = false
    
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
    
    // MARK: - Dependencies
    
    public let apiURL: URL
    private let urlSession: URLSession
    private let userDefaults: UserDefaults
    
    // MARK: - Initializer
    
    public init(
        apiURL: URL = AppUpdateManager.defaultRepoAPIURL,
        urlSession: URLSession = .shared,
        userDefaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        customCurrentVersion: String? = nil
    ) {
        self.apiURL = apiURL
        self.urlSession = urlSession
        self.userDefaults = userDefaults
        
        let version = customCurrentVersion
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "1.0.0"
        let build = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
        
        self.currentVersionString = version
        self.currentBuildString = build
        self.currentSemanticVersion = SemanticVersion(version) ?? SemanticVersion(major: 1, minor: 0, patch: 0)
        
        if userDefaults.object(forKey: Self.autoCheckDefaultsKey) == nil {
            self.autoCheckOnLaunch = true
        } else {
            self.autoCheckOnLaunch = userDefaults.bool(forKey: Self.autoCheckDefaultsKey)
        }
        
        let savedTimestamp = userDefaults.double(forKey: Self.lastCheckDateDefaultsKey)
        if savedTimestamp > 0 {
            self.lastCheckedDate = Date(timeIntervalSince1970: savedTimestamp)
        } else {
            self.lastCheckedDate = nil
        }
    }
    
    // MARK: - Update Checking API
    
    /// Queries the GitHub Releases API for the latest published release and evaluates if an update is available.
    /// - Parameter manual: Set to `true` when triggered from a user button press (e.g., in Settings), or `false` on auto-check.
    /// - Returns: `true` if a newer version is available.
    @MainActor
    @discardableResult
    public func checkForUpdates(manual: Bool = false) async -> Bool {
        isChecking = true
        errorMessage = nil
        
        defer {
            isChecking = false
        }
        
        do {
            var request = URLRequest(url: apiURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 15.0
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.setValue("LiquidCalc-iOS/\(currentVersionString)", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if httpResponse.statusCode == 404 {
                self.errorMessage = "No releases found in GitHub repository."
                self.updateAvailable = false
                if manual {
                    self.showNoUpdateAlert = true
                }
                return false
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorDesc = "GitHub API returned status \(httpResponse.statusCode)"
                self.errorMessage = errorDesc
                return false
            }
            
            let decoder = JSONDecoder()
            let release = try decoder.decode(GitHubRelease.self, from: data)
            
            self.latestRelease = release
            self.lastCheckedDate = Date()
            
            let isNewer = isUpdateAvailable(for: release)
            self.updateAvailable = isNewer
            
            if isNewer {
                self.showUpdateSheet = true
            } else if manual {
                self.showNoUpdateAlert = true
            }
            
            return isNewer
        } catch {
            self.errorMessage = error.localizedDescription
            self.updateAvailable = false
            return false
        }
    }
    
    /// Determines whether the given GitHub release is strictly newer than the currently running app version.
    public func isUpdateAvailable(for release: GitHubRelease) -> Bool {
        guard let releaseSemVer = release.semanticVersion else {
            return false
        }
        return releaseSemVer > currentSemanticVersion
    }
    
    // MARK: - Actions
    
    public func dismissUpdateSheet() {
        showUpdateSheet = false
    }
    
    public func dismissNoUpdateAlert() {
        showNoUpdateAlert = false
    }
}
