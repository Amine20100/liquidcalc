//
//  AppUpdateManagerTests.swift
//  LiquidCalcTests
//
//  Created for LiquidCalc iOS 18+.
//  Comprehensive Unit Test Suite for Feature F7: GitHub Releases Online Update Checker
//  Covers SemanticVersion parser & comparator, GitHubRelease / Asset JSON decoding,
//  Mock URLProtocol network requests, update availability evaluation, and preferences persistence.
//

import XCTest
import Foundation
#if canImport(LiquidCalcCore)
@testable import LiquidCalcCore
#endif

// MARK: - Mock URL Protocol for Network Isolation

final class MockUpdateURLProtocol: URLProtocol {
    static var mockHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockUpdateURLProtocol.mockHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}

// MARK: - AppUpdateManagerTests

final class AppUpdateManagerTests: XCTestCase {
    
    private var mockSession: URLSession!
    private var testDefaults: UserDefaults!
    private let testSuiteName = "com.liquidcalc.test.update"
    
    override func setUp() {
        super.setUp()
        
        // Configure URLSession with MockUpdateURLProtocol
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockUpdateURLProtocol.self]
        mockSession = URLSession(configuration: config)
        
        // Configure isolated UserDefaults suite
        UserDefaults.standard.removePersistentDomain(forName: testSuiteName)
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        MockUpdateURLProtocol.mockHandler = nil
    }
    
    override func tearDown() {
        MockUpdateURLProtocol.mockHandler = nil
        mockSession = nil
        if let suite = testDefaults {
            UserDefaults.standard.removePersistentDomain(forName: testSuiteName)
        }
        testDefaults = nil
        super.tearDown()
    }
    
    // =========================================================================
    // MARK: - SECTION 1: SemanticVersion Parsing & Initialization
    // =========================================================================
    
    func testSemanticVersionStandardParsing() {
        let v1 = SemanticVersion("1.0.0")
        XCTAssertNotNil(v1)
        XCTAssertEqual(v1?.major, 1)
        XCTAssertEqual(v1?.minor, 0)
        XCTAssertEqual(v1?.patch, 0)
        XCTAssertNil(v1?.prerelease)
        XCTAssertNil(v1?.buildMetadata)
        
        let v2 = SemanticVersion("2.14.8")
        XCTAssertNotNil(v2)
        XCTAssertEqual(v2?.major, 2)
        XCTAssertEqual(v2?.minor, 14)
        XCTAssertEqual(v2?.patch, 8)
        
        let v0 = SemanticVersion("0.0.1")
        XCTAssertNotNil(v0)
        XCTAssertEqual(v0?.major, 0)
        XCTAssertEqual(v0?.minor, 0)
        XCTAssertEqual(v0?.patch, 1)
    }
    
    func testSemanticVersionPrefixHandling() {
        let vLower = SemanticVersion("v1.2.3")
        XCTAssertNotNil(vLower)
        XCTAssertEqual(vLower?.major, 1)
        XCTAssertEqual(vLower?.minor, 2)
        XCTAssertEqual(vLower?.patch, 3)
        
        let vUpper = SemanticVersion("V3.0.0")
        XCTAssertNotNil(vUpper)
        XCTAssertEqual(vUpper?.major, 3)
        XCTAssertEqual(vUpper?.minor, 0)
        XCTAssertEqual(vUpper?.patch, 0)
    }
    
    func testSemanticVersionShortForms() {
        // Two component "1.5" -> major 1, minor 5, patch 0
        let vTwo = SemanticVersion("1.5")
        XCTAssertNotNil(vTwo)
        XCTAssertEqual(vTwo?.major, 1)
        XCTAssertEqual(vTwo?.minor, 5)
        XCTAssertEqual(vTwo?.patch, 0)
        
        // Single component "2" -> major 2, minor 0, patch 0
        let vOne = SemanticVersion("2")
        XCTAssertNotNil(vOne)
        XCTAssertEqual(vOne?.major, 2)
        XCTAssertEqual(vOne?.minor, 0)
        XCTAssertEqual(vOne?.patch, 0)
    }
    
    func testSemanticVersionPrereleaseAndBuildMetadata() {
        let vPre = SemanticVersion("1.0.0-beta.1")
        XCTAssertNotNil(vPre)
        XCTAssertEqual(vPre?.major, 1)
        XCTAssertEqual(vPre?.minor, 0)
        XCTAssertEqual(vPre?.patch, 0)
        XCTAssertEqual(vPre?.prerelease, "beta.1")
        XCTAssertNil(vPre?.buildMetadata)
        
        let vBuild = SemanticVersion("1.0.0+20130313144700")
        XCTAssertNotNil(vBuild)
        XCTAssertEqual(vBuild?.major, 1)
        XCTAssertEqual(vBuild?.minor, 0)
        XCTAssertEqual(vBuild?.patch, 0)
        XCTAssertNil(vBuild?.prerelease)
        XCTAssertEqual(vBuild?.buildMetadata, "20130313144700")
        
        let vBoth = SemanticVersion("2.0.0-rc.2+exp.sha.5114f85")
        XCTAssertNotNil(vBoth)
        XCTAssertEqual(vBoth?.major, 2)
        XCTAssertEqual(vBoth?.minor, 0)
        XCTAssertEqual(vBoth?.patch, 0)
        XCTAssertEqual(vBoth?.prerelease, "rc.2")
        XCTAssertEqual(vBoth?.buildMetadata, "exp.sha.5114f85")
    }
    
    func testSemanticVersionInvalidFormats() {
        XCTAssertNil(SemanticVersion(""))
        XCTAssertNil(SemanticVersion("   "))
        XCTAssertNil(SemanticVersion("invalid"))
        XCTAssertNil(SemanticVersion("a.b.c"))
        XCTAssertNil(SemanticVersion("1.2.3.4.5"))
        XCTAssertNil(SemanticVersion("-1.0.0"))
        XCTAssertNil(SemanticVersion("1.-2.0"))
    }
    
    func testSemanticVersionDirectInitializer() {
        let v = SemanticVersion(major: 2, minor: 3, patch: 4, prerelease: "alpha", buildMetadata: "build123")
        XCTAssertEqual(v.major, 2)
        XCTAssertEqual(v.minor, 3)
        XCTAssertEqual(v.patch, 4)
        XCTAssertEqual(v.prerelease, "alpha")
        XCTAssertEqual(v.buildMetadata, "build123")
        XCTAssertEqual(v.description, "2.3.4-alpha+build123")
    }
    
    // =========================================================================
    // MARK: - SECTION 2: SemanticVersion Precedence & Comparison
    // =========================================================================
    
    func testSemanticVersionMajorMinorPatchPrecedence() {
        let v1_0_0 = SemanticVersion("1.0.0")!
        let v1_0_1 = SemanticVersion("1.0.1")!
        let v1_1_0 = SemanticVersion("1.1.0")!
        let v2_0_0 = SemanticVersion("2.0.0")!
        
        XCTAssertTrue(v1_0_0 < v1_0_1)
        XCTAssertTrue(v1_0_1 < v1_1_0)
        XCTAssertTrue(v1_1_0 < v2_0_0)
        XCTAssertTrue(v2_0_0 > v1_0_0)
        XCTAssertEqual(v1_0_0, SemanticVersion("v1.0.0")!)
    }
    
    func testSemanticVersionPrereleasePrecedence() {
        // Spec: Normal version has HIGHER precedence than prerelease
        let normal = SemanticVersion("1.0.0")!
        let alpha = SemanticVersion("1.0.0-alpha")!
        let alpha1 = SemanticVersion("1.0.0-alpha.1")!
        let beta = SemanticVersion("1.0.0-beta")!
        let beta2 = SemanticVersion("1.0.0-beta.2")!
        let beta11 = SemanticVersion("1.0.0-beta.11")!
        let rc1 = SemanticVersion("1.0.0-rc.1")!
        
        XCTAssertTrue(alpha < normal)
        XCTAssertTrue(alpha < alpha1)
        XCTAssertTrue(alpha1 < beta)
        XCTAssertTrue(beta < beta2)
        XCTAssertTrue(beta2 < beta11, "Numeric identifier 11 must be greater than 2")
        XCTAssertTrue(beta11 < rc1)
        XCTAssertTrue(rc1 < normal)
    }
    
    func testSemanticVersionBuildMetadataIgnoredInPrecedence() {
        // Spec: Build metadata is ignored when determining version precedence
        let v1 = SemanticVersion("1.0.0+build1")!
        let v2 = SemanticVersion("1.0.0+build2")!
        
        XCTAssertFalse(v1 < v2)
        XCTAssertFalse(v2 < v1)
        XCTAssertEqual(v1, v2)
    }
    
    func testSemanticVersionCodableRoundtrip() throws {
        let original = SemanticVersion("1.4.2-beta.3+20260901")!
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SemanticVersion.self, from: data)
        
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(original.description, decoded.description)
    }
    
    // =========================================================================
    // MARK: - SECTION 3: GitHubRelease & Asset JSON Decoding
    // =========================================================================
    
    func testGitHubReleaseJSONDecodingFull() throws {
        let json = """
        {
            "id": 101,
            "tag_name": "v1.2.0",
            "name": "LiquidCalc v1.2.0 - Next-Gen Glass & Vision Update",
            "body": "## What's New\\n- Added dynamic mesh glass gradients\\n- Upgraded Vision OCR with multi-currency receipts\\n- Online update notifications",
            "html_url": "https://github.com/Amine20100/liquidcalc/releases/tag/v1.2.0",
            "published_at": "2026-09-01T07:10:00Z",
            "prerelease": false,
            "draft": false,
            "assets": [
                {
                    "id": 201,
                    "name": "LiquidCalc.ipa",
                    "size": 16148000,
                    "download_count": 42,
                    "browser_download_url": "https://github.com/Amine20100/liquidcalc/releases/download/v1.2.0/LiquidCalc.ipa",
                    "content_type": "application/octet-stream"
                },
                {
                    "id": 202,
                    "name": "Source_Code.zip",
                    "size": 2500000,
                    "download_count": 10,
                    "browser_download_url": "https://github.com/Amine20100/liquidcalc/archive/refs/tags/v1.2.0.zip",
                    "content_type": "application/zip"
                }
            ]
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let release = try decoder.decode(GitHubRelease.self, from: json)
        
        XCTAssertEqual(release.tagName, "v1.2.0")
        XCTAssertEqual(release.displayTitle, "LiquidCalc v1.2.0 - Next-Gen Glass & Vision Update")
        XCTAssertEqual(release.semanticVersion, SemanticVersion("1.2.0"))
        XCTAssertEqual(release.assets.count, 2)
        
        // Check IPA asset resolution
        let ipa = release.ipaAsset
        XCTAssertNotNil(ipa)
        XCTAssertEqual(ipa?.name, "LiquidCalc.ipa")
        XCTAssertEqual(ipa?.browserDownloadURL.absoluteString, "https://github.com/Amine20100/liquidcalc/releases/download/v1.2.0/LiquidCalc.ipa")
        XCTAssertNotNil(ipa?.formattedSize)
        XCTAssertEqual(release.ipaDownloadURL?.absoluteString, "https://github.com/Amine20100/liquidcalc/releases/download/v1.2.0/LiquidCalc.ipa")
        
        // Published date
        XCTAssertNotNil(release.publishedDate)
    }
    
    func testGitHubReleaseMinimalJSON() throws {
        let json = """
        {
            "tag_name": "v2.0.0",
            "html_url": "https://github.com/Amine20100/liquidcalc/releases/tag/v2.0.0",
            "assets": []
        }
        """.data(using: .utf8)!
        
        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        XCTAssertEqual(release.tagName, "v2.0.0")
        XCTAssertEqual(release.displayTitle, "v2.0.0")
        XCTAssertNil(release.body)
        XCTAssertNil(release.ipaAsset)
        XCTAssertNil(release.ipaDownloadURL)
    }
    
    func testGitHubReleaseCaseInsensitiveIPAAssetMatching() {
        let asset = GitHubReleaseAsset(
            name: "liquidcalc.IPA",
            browserDownloadURL: URL(string: "https://example.com/liquidcalc.IPA")!
        )
        let release = GitHubRelease(
            tagName: "v1.0.1",
            htmlURL: URL(string: "https://example.com")!,
            assets: [asset]
        )
        
        XCTAssertNotNil(release.ipaAsset)
        XCTAssertEqual(release.ipaDownloadURL?.absoluteString, "https://example.com/liquidcalc.IPA")
    }
    
    // =========================================================================
    // MARK: - SECTION 4: AppUpdateManager Network & Update Evaluation
    // =========================================================================
    
    func testAppUpdateManagerDetectsNewerVersion() async {
        let currentVersion = "1.0.0"
        let remoteJSON = """
        {
            "tag_name": "v1.1.0",
            "name": "LiquidCalc 1.1.0",
            "body": "Major UI updates and receipt engine",
            "html_url": "https://github.com/Amine20100/liquidcalc/releases/tag/v1.1.0",
            "assets": [
                {
                    "name": "LiquidCalc.ipa",
                    "size": 15000000,
                    "browser_download_url": "https://github.com/Amine20100/liquidcalc/releases/download/v1.1.0/LiquidCalc.ipa"
                }
            ]
        }
        """.data(using: .utf8)!
        
        MockUpdateURLProtocol.mockHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, remoteJSON)
        }
        
        let manager = AppUpdateManager(
            urlSession: mockSession,
            userDefaults: testDefaults,
            customCurrentVersion: currentVersion
        )
        
        let hasUpdate = await manager.checkForUpdates(manual: false)
        
        XCTAssertTrue(hasUpdate)
        XCTAssertTrue(manager.updateAvailable)
        XCTAssertTrue(manager.showUpdateSheet)
        XCTAssertFalse(manager.showNoUpdateAlert)
        XCTAssertNil(manager.errorMessage)
        XCTAssertEqual(manager.latestRelease?.tagName, "v1.1.0")
        XCTAssertNotNil(manager.lastCheckedDate)
    }
    
    func testAppUpdateManagerDetectsAlreadyUpToDate() async {
        let currentVersion = "1.5.0"
        let remoteJSON = """
        {
            "tag_name": "v1.5.0",
            "name": "LiquidCalc 1.5.0",
            "html_url": "https://github.com/Amine20100/liquidcalc/releases/tag/v1.5.0",
            "assets": []
        }
        """.data(using: .utf8)!
        
        MockUpdateURLProtocol.mockHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, remoteJSON)
        }
        
        let manager = AppUpdateManager(
            urlSession: mockSession,
            userDefaults: testDefaults,
            customCurrentVersion: currentVersion
        )
        
        // Manual check when up-to-date should set showNoUpdateAlert to true
        let hasUpdate = await manager.checkForUpdates(manual: true)
        
        XCTAssertFalse(hasUpdate)
        XCTAssertFalse(manager.updateAvailable)
        XCTAssertFalse(manager.showUpdateSheet)
        XCTAssertTrue(manager.showNoUpdateAlert)
        XCTAssertNil(manager.errorMessage)
    }
    
    func testAppUpdateManagerHandles404NoReleases() async {
        MockUpdateURLProtocol.mockHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        
        let manager = AppUpdateManager(
            urlSession: mockSession,
            userDefaults: testDefaults,
            customCurrentVersion: "1.0.0"
        )
        
        let hasUpdate = await manager.checkForUpdates(manual: true)
        
        XCTAssertFalse(hasUpdate)
        XCTAssertFalse(manager.updateAvailable)
        XCTAssertTrue(manager.showNoUpdateAlert)
        XCTAssertEqual(manager.errorMessage, "No releases found in GitHub repository.")
    }
    
    func testAppUpdateManagerHandlesServerError() async {
        MockUpdateURLProtocol.mockHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        
        let manager = AppUpdateManager(
            urlSession: mockSession,
            userDefaults: testDefaults,
            customCurrentVersion: "1.0.0"
        )
        
        let hasUpdate = await manager.checkForUpdates(manual: false)
        
        XCTAssertFalse(hasUpdate)
        XCTAssertFalse(manager.updateAvailable)
        XCTAssertNotNil(manager.errorMessage)
        XCTAssertTrue(manager.errorMessage?.contains("500") == true)
    }
    
    func testAppUpdateManagerHandlesNetworkConnectionFailure() async {
        MockUpdateURLProtocol.mockHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        
        let manager = AppUpdateManager(
            urlSession: mockSession,
            userDefaults: testDefaults,
            customCurrentVersion: "1.0.0"
        )
        
        let hasUpdate = await manager.checkForUpdates(manual: false)
        
        XCTAssertFalse(hasUpdate)
        XCTAssertFalse(manager.updateAvailable)
        XCTAssertNotNil(manager.errorMessage)
    }
    
    // =========================================================================
    // MARK: - SECTION 5: Preferences Persistence & Dismiss Actions
    // =========================================================================
    
    func testAutoCheckOnLaunchPreferencesPersistence() {
        let manager = AppUpdateManager(
            urlSession: mockSession,
            userDefaults: testDefaults,
            customCurrentVersion: "1.0.0"
        )
        
        manager.autoCheckOnLaunch = false
        XCTAssertFalse(testDefaults.bool(forKey: AppUpdateManager.autoCheckDefaultsKey))
        
        manager.autoCheckOnLaunch = true
        XCTAssertTrue(testDefaults.bool(forKey: AppUpdateManager.autoCheckDefaultsKey))
    }
    
    func testLastCheckedDatePersistence() {
        let manager = AppUpdateManager(
            urlSession: mockSession,
            userDefaults: testDefaults,
            customCurrentVersion: "1.0.0"
        )
        
        let testDate = Date(timeIntervalSince1970: 1756713600) // Fixed timestamp
        manager.lastCheckedDate = testDate
        
        let saved = testDefaults.double(forKey: AppUpdateManager.lastCheckDateDefaultsKey)
        XCTAssertEqual(saved, testDate.timeIntervalSince1970, accuracy: 1e-3)
        
        // Re-instantiate from defaults
        let freshManager = AppUpdateManager(
            urlSession: mockSession,
            userDefaults: testDefaults,
            customCurrentVersion: "1.0.0"
        )
        XCTAssertNotNil(freshManager.lastCheckedDate)
        XCTAssertEqual(freshManager.lastCheckedDate?.timeIntervalSince1970 ?? 0, testDate.timeIntervalSince1970, accuracy: 1e-3)
    }
    
    func testDismissSheetAndAlertActions() {
        let manager = AppUpdateManager(
            urlSession: mockSession,
            userDefaults: testDefaults,
            customCurrentVersion: "1.0.0"
        )
        
        manager.showUpdateSheet = true
        manager.showNoUpdateAlert = true
        
        manager.dismissUpdateSheet()
        XCTAssertFalse(manager.showUpdateSheet)
        
        manager.dismissNoUpdateAlert()
        XCTAssertFalse(manager.showNoUpdateAlert)
    }
}
