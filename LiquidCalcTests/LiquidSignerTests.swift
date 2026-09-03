//
//  LiquidSignerTests.swift
//  LiquidCalcTests
//
//  Created for LiquidCalc iOS 18+.
//  Unit Test Suite for Liquid Signer Hidden Vault, Cryptography, and Secret Unlock
//

import XCTest
#if canImport(LiquidCalc)
@testable import LiquidCalc
#elseif canImport(LiquidCalcCore)
@testable import LiquidCalcCore
#endif

final class LiquidSignerTests: XCTestCase {
    
    // MARK: - Test 1: Secret PIN Code Intercept & Vault Unlock
    
    func testSecretPinVaultUnlock() {
        let viewModel = CalculatorViewModel()
        viewModel.secretPIN = "1337"
        viewModel.showLiquidSigner = false
        
        // Simulate typing 1, 3, 3, 7 on calculator
        viewModel.handleButtonPress(KeypadButton(label: "1", type: .digit("1")))
        viewModel.handleButtonPress(KeypadButton(label: "3", type: .digit("3")))
        viewModel.handleButtonPress(KeypadButton(label: "3", type: .digit("3")))
        viewModel.handleButtonPress(KeypadButton(label: "7", type: .digit("7")))
        
        XCTAssertEqual(viewModel.expression, "1337")
        XCTAssertFalse(viewModel.showLiquidSigner)
        
        // User taps '='
        viewModel.evaluateFinal()
        
        // Verify vault is unlocked, screen is wiped clean, and no calculation error occurred
        XCTAssertTrue(viewModel.showLiquidSigner, "Typing secret PIN '1337=' must unlock the Liquid Signer vault")
        XCTAssertEqual(viewModel.expression, "", "Expression must be wiped clean with zero trace")
        XCTAssertEqual(viewModel.displayResult, "0", "Display must reset to 0")
        XCTAssertFalse(viewModel.hasError, "No syntax error should occur on secret PIN trigger")
    }
    
    func testRegularMathDoesNotTriggerSigner() {
        let viewModel = CalculatorViewModel()
        viewModel.secretPIN = "1337"
        viewModel.showLiquidSigner = false
        
        // Simulate typing 1337 + 1 = 1338
        viewModel.handleButtonPress(KeypadButton(label: "1", type: .digit("1")))
        viewModel.handleButtonPress(KeypadButton(label: "3", type: .digit("3")))
        viewModel.handleButtonPress(KeypadButton(label: "3", type: .digit("3")))
        viewModel.handleButtonPress(KeypadButton(label: "7", type: .digit("7")))
        viewModel.handleButtonPress(KeypadButton(label: "+", type: .operation("+")))
        viewModel.handleButtonPress(KeypadButton(label: "1", type: .digit("1")))
        
        viewModel.evaluateFinal()
        
        XCTAssertFalse(viewModel.showLiquidSigner, "Regular arithmetic with 1337 should not unlock vault")
        XCTAssertEqual(viewModel.displayResult, "1338")
    }
    
    func testCustomSecretPinChange() {
        let viewModel = CalculatorViewModel()
        viewModel.secretPIN = "9999"
        viewModel.showLiquidSigner = false
        
        // Old PIN 1337 should no longer unlock
        viewModel.expression = "1337"
        viewModel.evaluateFinal()
        XCTAssertFalse(viewModel.showLiquidSigner)
        
        // New PIN 9999 should unlock
        viewModel.expression = "9999"
        viewModel.evaluateFinal()
        XCTAssertTrue(viewModel.showLiquidSigner)
        
        // Restore default PIN
        viewModel.secretPIN = "1337"
    }
    
    // MARK: - Test 2: Certificate & Profile Management
    
    func testCertificateManagerDefaults() {
        let manager = CertificateManager.shared
        
        XCTAssertFalse(manager.certificates.isEmpty, "CertificateManager must initialize with default ad-hoc certificate")
        
        if let cert = manager.activeCertificate {
            XCTAssertFalse(cert.isExpired, "Default certificate must not be expired")
            XCTAssertGreaterThan(cert.daysRemaining, 0, "Default certificate must have positive remaining days")
        }
        
        if let profile = manager.activeProfile {
            XCTAssertTrue(profile.isWildcard, "Default provisioning profile should be wildcard")
            XCTAssertFalse(profile.isExpired, "Default provisioning profile must not be expired")
        }
    }
    
    // MARK: - Test 3: Signer Models & Data Structures
    
    func testSignedAppProperties() {
        let app = SignedApp(
            name: "Test App",
            bundleIdentifier: "com.test.app",
            version: "2.1",
            sizeBytes: 15_000_000,
            injectedDylibs: ["libTweak.dylib"],
            status: .readyToSign
        )
        
        XCTAssertEqual(app.name, "Test App")
        XCTAssertEqual(app.bundleIdentifier, "com.test.app")
        XCTAssertEqual(app.version, "2.1")
        XCTAssertEqual(app.status, .readyToSign)
        XCTAssertEqual(app.injectedDylibs.count, 1)
        XCTAssertFalse(app.formattedSize.isEmpty)
    }
    
    func testDylibTweakProperties() {
        let tweak = DylibTweak(
            filename: "libTweak.dylib",
            fileUrl: URL(fileURLWithPath: "/tmp/libTweak.dylib"),
            isEnabled: true,
            sizeBytes: 250_000
        )
        
        XCTAssertEqual(tweak.filename, "libTweak.dylib")
        XCTAssertTrue(tweak.isEnabled)
        XCTAssertFalse(tweak.formattedSize.isEmpty)
    }
    
    // MARK: - Test 4: Local Install Server Lifecycle
    
    func testLocalInstallServerLifecycle() {
        let server = LocalInstallServer.shared
        XCTAssertFalse(server.isRunning)
        
        server.start()
        // Wait briefly for network listener initialization
        let exp = expectation(description: "Server state update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            server.stop()
            XCTAssertFalse(server.isRunning)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
    
    // MARK: - Test 5: Advanced Signing Configuration & Cloning
    
    func testSigningConfigCloningAndOptions() {
        let cert = SigningCertificate(
            name: "Test Dev Cert",
            commonName: "Apple Development: Dev (TEST)",
            expirationDate: Date().addingTimeInterval(3600 * 24 * 30),
            p12FileName: "test.p12"
        )
        
        let config = SigningConfig(
            customName: "MyClonedApp",
            customBundleId: "com.example.app.cloned",
            customVersion: "3.0.1",
            certificate: cert,
            profile: nil,
            dylibs: [],
            removeExtensions: true
        )
        
        XCTAssertEqual(config.customName, "MyClonedApp")
        XCTAssertEqual(config.customBundleId, "com.example.app.cloned")
        XCTAssertEqual(config.customVersion, "3.0.1")
        XCTAssertTrue(config.removeExtensions)
        XCTAssertEqual(config.certificate?.name, "Test Dev Cert")
    }
    
    // MARK: - Test 6: Pure Swift LiquidSignEngine Pipeline
    
    func testLiquidSignEnginePipelineExecution() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let dummyIpa = tempDir.appendingPathComponent("Sample.ipa")
        // Minimal PK header
        let pkData = Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00, 0x00, 0x00])
        try pkData.write(to: dummyIpa)
        
        let config = SigningConfig(
            customName: "SignedSample",
            customBundleId: "com.liquidsigner.sample",
            customVersion: "1.2.0",
            certificate: nil,
            profile: nil,
            dylibs: [],
            removeExtensions: true
        )
        
        var recordedStages: [String] = []
        var maxProgress: Double = 0.0
        
        let signedUrl = try await LiquidSignEngine.shared.signIPA(
            inputIpaUrl: dummyIpa,
            config: config,
            progress: { pct, stage in
                maxProgress = max(maxProgress, pct)
                recordedStages.append(stage)
            },
            log: { _, _ in }
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: signedUrl.path), "Signed IPA must exist on disk")
        XCTAssertEqual(maxProgress, 1.0, "Signing pipeline must reach 100% progress")
        XCTAssertTrue(recordedStages.contains(where: { $0.contains("Packaging") || $0.contains("complete") }))
    }
    
    // MARK: - Test 5: Signer Studio & Engine Modes
    
    func testSignerStudioTabAndModes() {
        let viewModel = LiquidSignerViewModel()
        
        XCTAssertEqual(viewModel.selectedTab, .signer, "Default landing tab in vault must be the Signer Studio")
        XCTAssertEqual(viewModel.selectedEngineMode, .onDevice)
        
        // Test tab icon
        XCTAssertEqual(SignerTab.signer.iconName, "bolt.shield.fill")
        XCTAssertEqual(SignerTab.signer.rawValue, "Signer")
        
        // Switch engine mode
        viewModel.selectedEngineMode = .cloudServer
        XCTAssertEqual(viewModel.selectedEngineMode, .cloudServer)
    }
    
    // MARK: - Test 6: Local Install Server & Cloud Assisted Manifest
    
    func testLocalInstallServerNetworkInstallURL() {
        let server = LocalInstallServer.shared
        let urlString = server.networkInstallURL(for: "LiquidTest", bundleId: "com.test.app")
        
        XCTAssertTrue(urlString.hasPrefix("itms-services://?action=download-manifest&url="))
        XCTAssertTrue(urlString.contains("liquidcalc-backend.vercel.app"))
        XCTAssertTrue(urlString.contains("com.test.app"))
    }
    
    // MARK: - Test 7: ZSign Configuration & CLI Options
    
    func testZSignConfigurationOptions() {
        let config = SigningConfig(
            customName: "TestApp",
            customBundleId: "com.test.cloned",
            customVersion: "2.0",
            removeExtensions: true,
            injectGetTaskAllow: true,
            enableFileSharing: true,
            installAfterSigned: true
        )
        
        XCTAssertEqual(config.customName, "TestApp")
        XCTAssertEqual(config.customBundleId, "com.test.cloned")
        XCTAssertEqual(config.customVersion, "2.0")
        XCTAssertTrue(config.removeExtensions)
        XCTAssertTrue(config.injectGetTaskAllow)
        XCTAssertTrue(config.enableFileSharing)
        XCTAssertTrue(config.installAfterSigned)
    }
}

