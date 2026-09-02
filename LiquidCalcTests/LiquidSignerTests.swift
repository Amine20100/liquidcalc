//
//  LiquidSignerTests.swift
//  LiquidCalcTests
//
//  Created for LiquidCalc iOS 18+.
//  Unit Test Suite for Liquid Signer Hidden Vault, Cryptography, and Secret Unlock
//

import XCTest
#if canImport(LiquidCalcCore)
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
}
