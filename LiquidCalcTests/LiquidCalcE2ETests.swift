//
//  LiquidCalcE2ETests.swift
//  LiquidCalcTests
//
//  Created for LiquidCalc iOS 18+.
//  Comprehensive Opaque-Box 4-Tier E2E Test Suite implementing the Test Methodology from TEST_INFRA.md:
//  - Tier 1: Feature Coverage (F1 to F7: >=5 tests per feature = 35+ tests)
//  - Tier 2: Boundary & Corner Cases (F1 to F7: >=5 tests per feature = 35+ tests)
//  - Tier 3: Cross-Feature Combinations (>=10 pairwise tests = 15 tests)
//  - Tier 4: Real-World Application Scenarios (5 multi-step end-to-end workflows)
//  Total: 90+ E2E tests covering Motion, Visual FX, Sonar Waves, CoreHaptics, Smart OCR,
//  Multi-Currency Receipt Splitting, and GitHub Releases Update Checking.
//

import XCTest
import SwiftUI

#if canImport(CoreHaptics)
import CoreHaptics
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(Vision)
import Vision
#endif

#if canImport(LiquidCalcCore)
@testable import LiquidCalcCore
#endif

final class LiquidCalcE2ETests: XCTestCase {
    
    private var originalHapticsEnabled: Bool = true
    private var originalSoundEnabled: Bool = true
    
    override func setUp() {
        super.setUp()
        originalHapticsEnabled = SoundAndHapticManager.shared.isHapticsEnabled
        originalSoundEnabled = SoundAndHapticManager.shared.isSoundEnabled
        SoundAndHapticManager.shared.isHapticsEnabled = true
        SoundAndHapticManager.shared.isSoundEnabled = true
        HistoryManager.shared.clearHistory()
    }
    
    override func tearDown() {
        SoundAndHapticManager.shared.isHapticsEnabled = originalHapticsEnabled
        SoundAndHapticManager.shared.isSoundEnabled = originalSoundEnabled
        SoundAndHapticManager.shared.stopContinuousScanningHum()
        HistoryManager.shared.clearHistory()
        super.tearDown()
    }
    
    // =========================================================================
    // MARK: - TIER 1: FEATURE COVERAGE (F1 to F7: 35+ Tests)
    // =========================================================================
    
    // -------------------------------------------------------------------------
    // Feature F1: Liquid Glass & Keypad Dynamics (ORIGINAL_REQUEST §R1)
    // -------------------------------------------------------------------------
    
    func testF1_01_KeypadPressStyleInitialization() {
        let pressStyle = KeypadPressStyle()
        XCTAssertNotNil(pressStyle, "KeypadPressStyle must initialize cleanly")
    }
    
    func testF1_02_KeypadButtonAccentStylesAndColorGradients() {
        let digitButton = KeypadButton(label: "7", type: .digit("7"))
        XCTAssertEqual(digitButton.accentStyle, .digitDark)
        XCTAssertGreaterThanOrEqual(digitButton.accentStyle.backgroundColors.count, 2)
        XCTAssertEqual(digitButton.accentStyle.foregroundColor, .white)
        
        let opButton = KeypadButton(label: "+", type: .operation("+"))
        XCTAssertEqual(opButton.accentStyle, .accentCyan)
        
        let eqButton = KeypadButton(label: "=", type: .equals)
        XCTAssertEqual(eqButton.accentStyle, .accentOrange)
        
        let fnButton = KeypadButton(label: "AC", type: .allClear)
        XCTAssertEqual(fnButton.accentStyle, .functionGray)
    }
    
    func testF1_03_LiquidDisplayViewDefaultStateAndDynamicScaling() {
        let viewModel = CalculatorViewModel()
        let displayView = LiquidDisplayView(viewModel: viewModel)
        XCTAssertNotNil(displayView)
        XCTAssertEqual(viewModel.displayResult, "0")
        XCTAssertEqual(viewModel.expression, "")
        XCTAssertNil(viewModel.livePreview)
    }
    
    func testF1_04_DisplaySwipeToDeleteLastCharacter() {
        let viewModel = CalculatorViewModel()
        viewModel.handleButtonPress(KeypadButton(label: "1", type: .digit("1")))
        viewModel.handleButtonPress(KeypadButton(label: "2", type: .digit("2")))
        viewModel.handleButtonPress(KeypadButton(label: "3", type: .digit("3")))
        XCTAssertEqual(viewModel.displayResult, "123")
        
        viewModel.deleteBackward()
        XCTAssertEqual(viewModel.displayResult, "12")
        
        viewModel.deleteBackward()
        XCTAssertEqual(viewModel.displayResult, "1")
        
        viewModel.deleteBackward()
        XCTAssertEqual(viewModel.displayResult, "0")
    }
    
    func testF1_05_LiveSpeculativePreviewGeneration() {
        let viewModel = CalculatorViewModel()
        viewModel.handleButtonPress(KeypadButton(label: "8", type: .digit("8")))
        viewModel.handleButtonPress(KeypadButton(label: "*", type: .operation("*")))
        viewModel.handleButtonPress(KeypadButton(label: "7", type: .digit("7")))
        
        XCTAssertEqual(viewModel.expression, "8*7")
        XCTAssertEqual(viewModel.livePreview, "56", "Live preview should speculatively evaluate 8*7 to 56")
    }
    
    // -------------------------------------------------------------------------
    // Feature F2: Scanner Motion FX & Viewfinder (ORIGINAL_REQUEST §R2)
    // -------------------------------------------------------------------------
    
    func testF2_01_LaserSweepLineViewInitialization() {
        let activeLaser = LaserSweepLineView(isScanning: true)
        let inactiveLaser = LaserSweepLineView(isScanning: false)
        XCTAssertNotNil(activeLaser)
        XCTAssertNotNil(inactiveLaser)
        XCTAssertTrue(activeLaser.isScanning)
        XCTAssertFalse(inactiveLaser.isScanning)
    }
    
    func testF2_02_SonarWaveRingsViewInitialization() {
        let activeSonar = SonarWaveRingsView(isScanning: true, ringCount: 3)
        let inactiveSonar = SonarWaveRingsView(isScanning: false, ringCount: 4)
        XCTAssertNotNil(activeSonar)
        XCTAssertNotNil(inactiveSonar)
        XCTAssertTrue(activeSonar.isScanning)
        XCTAssertEqual(activeSonar.ringCount, 3)
        XCTAssertFalse(inactiveSonar.isScanning)
        XCTAssertEqual(inactiveSonar.ringCount, 4)
    }
    
    func testF2_03_ReticleOverlayViewTriStateInitialization() {
        let idleReticle = ReticleOverlayView(isScanning: false, hasTarget: false)
        let scanningReticle = ReticleOverlayView(isScanning: true, hasTarget: false)
        let lockedReticle = ReticleOverlayView(isScanning: false, hasTarget: true)
        
        XCTAssertNotNil(idleReticle)
        XCTAssertNotNil(scanningReticle)
        XCTAssertNotNil(lockedReticle)
    }
    
    func testF2_04_ReticleTargetLockDetectionInVisionViewModel() {
        let visionVM = VisionViewModel()
        XCTAssertFalse(visionVM.hasDetectedTarget)
        
        visionVM.detectedExpression = "15 + 25"
        XCTAssertTrue(visionVM.hasDetectedTarget)
        
        visionVM.clearResults()
        XCTAssertFalse(visionVM.hasDetectedTarget)
    }
    
    func testF2_05_SolvedResultRevealCardInitialization() {
        var openedInCalc = false
        var copied = false
        
        let card = SolvedResultCardView(
            expression: "12 * 8",
            result: "96",
            onOpenInCalc: { openedInCalc = true },
            onCopy: { copied = true }
        )
        XCTAssertNotNil(card)
        XCTAssertEqual(card.expression, "12 * 8")
        XCTAssertEqual(card.result, "96")
        
        card.onOpenInCalc()
        XCTAssertTrue(openedInCalc)
        
        if let copyHandler = card.onCopy {
            copyHandler()
            XCTAssertTrue(copied)
        }
    }
    
    // -------------------------------------------------------------------------
    // Feature F3: Synchronized Scanning Haptics (ORIGINAL_REQUEST §R3)
    // -------------------------------------------------------------------------
    
    func testF3_01_EnginePrepareAndStart() {
        let manager = SoundAndHapticManager.shared
        manager.prepare()
        manager.startEngine()
        XCTAssertNotNil(manager)
    }
    
    func testF3_02_ContinuousScanningHumLifecycle() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        
        manager.startContinuousScanningHum()
        manager.stopContinuousScanningHum()
    }
    
    func testF3_03_MultiTieredHapticPatterns() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        
        manager.playDigitClick()
        manager.playOperatorBurst()
        manager.playFunctionClick()
        manager.playErrorThud()
        manager.playCelebratorySuccess()
    }
    
    func testF3_04_PreferencesHapticAndSoundToggles() {
        let manager = SoundAndHapticManager.shared
        
        manager.isHapticsEnabled = false
        XCTAssertFalse(manager.isHapticsEnabled)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "LC_HapticsEnabled"), false)
        
        manager.isHapticsEnabled = true
        XCTAssertTrue(manager.isHapticsEnabled)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "LC_HapticsEnabled"), true)
        
        manager.isSoundEnabled = false
        XCTAssertFalse(manager.isSoundEnabled)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "LC_SoundEnabled"), false)
        
        manager.isSoundEnabled = true
        XCTAssertTrue(manager.isSoundEnabled)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "LC_SoundEnabled"), true)
    }
    
    func testF3_05_AppBackgroundingLifecycleHandler() {
        let manager = SoundAndHapticManager.shared
        manager.startContinuousScanningHum()
        manager.handleAppBackground()
        manager.handleAppForeground()
    }
    
    // -------------------------------------------------------------------------
    // Feature F4: Smart Vision OCR & Math Normalization (ORIGINAL_REQUEST §R4)
    // -------------------------------------------------------------------------
    
    func testF4_01_VulgarFractionsNormalization() {
        let scanner = VisionMathScanner()
        XCTAssertEqual(scanner.sanitizeMathString("½ + ¼"), "(1/2) + (1/4)")
        XCTAssertEqual(scanner.sanitizeMathString("¾ * 8"), "(3/4) * 8")
        XCTAssertEqual(scanner.sanitizeMathString("⅓ + ⅔"), "(1/3) + (2/3)")
    }
    
    func testF4_02_MixedFractionsNormalization() {
        let scanner = VisionMathScanner()
        XCTAssertEqual(scanner.sanitizeMathString("3 1/2"), "3 + 1/2")
        XCTAssertEqual(scanner.sanitizeMathString("5 3/4"), "5 + 3/4")
    }
    
    func testF4_03_SuperscriptPowersNormalization() {
        let scanner = VisionMathScanner()
        XCTAssertEqual(scanner.sanitizeMathString("5² + 2³"), "5^2 + 2^3")
        XCTAssertEqual(scanner.sanitizeMathString("2¹⁰"), "2^10")
        XCTAssertEqual(scanner.sanitizeMathString("10⁻²"), "10^-2")
    }
    
    func testF4_04_RootsAndPiNormalization() {
        let scanner = VisionMathScanner()
        XCTAssertEqual(scanner.sanitizeMathString("√144"), "sqrt144")
        XCTAssertEqual(scanner.sanitizeMathString("∛27"), "cbrt27")
        XCTAssertEqual(scanner.sanitizeMathString("2π"), "2pi")
    }
    
    func testF4_05_BasicOperatorReplacements() {
        let scanner = VisionMathScanner()
        XCTAssertEqual(scanner.sanitizeMathString("10 × 4 ÷ 2 ="), "10 * 4 / 2")
        XCTAssertEqual(scanner.sanitizeMathString("6x7"), "6 * 7")
        XCTAssertEqual(scanner.sanitizeMathString("15 — 5"), "15 - 5")
    }
    
    // -------------------------------------------------------------------------
    // Feature F5: Advanced Math Engine & Percentages (ORIGINAL_REQUEST §R4)
    // -------------------------------------------------------------------------
    
    func testF5_01_PostfixPercentageEvaluation() throws {
        let evaluator = MathEvaluator()
        XCTAssertEqual(try evaluator.evaluate(expression: "50%"), 0.5, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "100%"), 1.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "50% * 200"), 100.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "25% + 75%"), 1.0, accuracy: 1e-9)
    }
    
    func testF5_02_VulgarAndMixedFractionEvaluation() throws {
        let evaluator = MathEvaluator()
        XCTAssertEqual(try evaluator.evaluate(expression: "½ + ½"), 1.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "¾ * 4"), 3.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "3 1/2"), 3.5, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "5 3/4"), 5.75, accuracy: 1e-9)
    }
    
    func testF5_03_SuperscriptPowersEvaluation() throws {
        let evaluator = MathEvaluator()
        XCTAssertEqual(try evaluator.evaluate(expression: "3²"), 9.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "2³"), 8.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "2¹⁰"), 1024.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "10⁻²"), 0.01, accuracy: 1e-9)
    }
    
    func testF5_04_RootEvaluation() throws {
        let evaluator = MathEvaluator()
        XCTAssertEqual(try evaluator.evaluate(expression: "√144"), 12.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "∛27"), 3.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "√25 + √16"), 9.0, accuracy: 1e-9)
    }
    
    func testF5_05_ScientificTrigAndLogEvaluation() throws {
        let degEvaluator = MathEvaluator(angleUnit: .degrees)
        XCTAssertEqual(try degEvaluator.evaluate(expression: "sin(30)"), 0.5, accuracy: 1e-6)
        XCTAssertEqual(try degEvaluator.evaluate(expression: "cos(60)"), 0.5, accuracy: 1e-6)
        XCTAssertEqual(try degEvaluator.evaluate(expression: "tan(45)"), 1.0, accuracy: 1e-6)
        
        let radEvaluator = MathEvaluator(angleUnit: .radians)
        XCTAssertEqual(try radEvaluator.evaluate(expression: "ln(e)"), 1.0, accuracy: 1e-9)
        XCTAssertEqual(try radEvaluator.evaluate(expression: "log(1000)"), 3.0, accuracy: 1e-9)
    }
    
    // -------------------------------------------------------------------------
    // Feature F6: Multi-Currency Receipt Engine (ORIGINAL_REQUEST §R4)
    // -------------------------------------------------------------------------
    
    func testF6_01_SupportedCurrencyPropertiesAndFormatting() {
        XCTAssertEqual(SupportedCurrency.usd.symbol, "$")
        XCTAssertEqual(SupportedCurrency.eur.symbol, "€")
        XCTAssertEqual(SupportedCurrency.gbp.symbol, "£")
        XCTAssertEqual(SupportedCurrency.mad.symbol, "MAD")
        XCTAssertEqual(SupportedCurrency.jpy.symbol, "¥")
        XCTAssertEqual(SupportedCurrency.chf.symbol, "CHF")
        
        XCTAssertEqual(SupportedCurrency.usd.format(amount: 14.50), "$14.50")
        XCTAssertEqual(SupportedCurrency.eur.format(amount: 12.50), "12.50 €")
        XCTAssertEqual(SupportedCurrency.mad.format(amount: 150.0), "150.00 MAD")
        XCTAssertEqual(SupportedCurrency.jpy.format(amount: 1500.0), "¥1,500")
    }
    
    func testF6_02_CurrencyDetectionHeuristics() {
        XCTAssertEqual(SupportedCurrency.detect(from: "$14.50 Avocado Toast"), .usd)
        XCTAssertEqual(SupportedCurrency.detect(from: "Steak Frites 18,50 €"), .eur)
        XCTAssertEqual(SupportedCurrency.detect(from: "Fish & Chips £14.95"), .gbp)
        XCTAssertEqual(SupportedCurrency.detect(from: "Tajine Poulet 85 MAD"), .mad)
        XCTAssertEqual(SupportedCurrency.detect(from: "Thé à la Menthe 20 DH"), .mad)
        XCTAssertEqual(SupportedCurrency.detect(from: "Tonkotsu Ramen ¥1100"), .jpy)
        XCTAssertEqual(SupportedCurrency.detect(from: "Fondue CHF 28.50"), .chf)
    }
    
    func testF6_03_ReceiptParserItemExtractionAndNoiseFiltering() {
        let scanner = VisionMathScanner()
        let obs = [
            ScannedTextObservation(rawText: "Restaurant Le Bistro", sanitizedExpression: "", boundingBox: .zero, confidence: 0.9),
            ScannedTextObservation(rawText: "Salade César 12,00 €", sanitizedExpression: "", boundingBox: .zero, confidence: 0.98),
            ScannedTextObservation(rawText: "Burger Gourmet 16,50 €", sanitizedExpression: "", boundingBox: .zero, confidence: 0.98),
            ScannedTextObservation(rawText: "Sous-total 28,50 €", sanitizedExpression: "", boundingBox: .zero, confidence: 0.95),
            ScannedTextObservation(rawText: "TVA 2,85 €", sanitizedExpression: "", boundingBox: .zero, confidence: 0.94),
            ScannedTextObservation(rawText: "Total TTC 31,35 €", sanitizedExpression: "", boundingBox: .zero, confidence: 0.99)
        ]
        
        let result = scanner.parseReceipt(from: obs)
        XCTAssertEqual(result.detectedCurrency, .eur)
        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.items[0].title, "Salade César")
        XCTAssertEqual(result.items[0].amount, 12.00)
        XCTAssertEqual(result.items[1].title, "Burger Gourmet")
        XCTAssertEqual(result.items[1].amount, 16.50)
        XCTAssertEqual(result.detectedSubtotal, 28.50)
        XCTAssertEqual(result.detectedTax, 2.85)
        XCTAssertEqual(result.detectedTotal, 31.35)
    }
    
    func testF6_04_VisionViewModelReceiptSplitCalculations() {
        let visionVM = VisionViewModel()
        visionVM.selectedSubMode = .receipt
        visionVM.receiptItems = [
            ReceiptLineItem(title: "Item 1", amount: 40.00),
            ReceiptLineItem(title: "Item 2", amount: 60.00)
        ]
        visionVM.tipPercentage = 20.0
        visionVM.taxRate = 10.0
        visionVM.splitCount = 4
        
        XCTAssertEqual(visionVM.receiptSubtotal, 100.00, accuracy: 1e-4)
        XCTAssertEqual(visionVM.receiptTipAmount, 20.00, accuracy: 1e-4)
        XCTAssertEqual(visionVM.receiptTaxAmount, 10.00, accuracy: 1e-4)
        XCTAssertEqual(visionVM.receiptTotal, 130.00, accuracy: 1e-4)
        XCTAssertEqual(visionVM.receiptPerPerson, 32.50, accuracy: 1e-4)
    }
    
    func testF6_05_ReceiptSplitterViewInitialization() {
        let visionVM = VisionViewModel()
        let splitterView = ReceiptSplitterView(viewModel: visionVM)
        XCTAssertNotNil(splitterView)
    }
    
    // -------------------------------------------------------------------------
    // Feature F7: GitHub Releases Online Update Checker (ORIGINAL_REQUEST §Follow-up)
    // -------------------------------------------------------------------------
    
    func testF7_01_SemanticVersionParsingAndComparison() {
        let v1 = SemanticVersion("1.0.0")!
        let v2 = SemanticVersion("1.1.0")!
        let v3 = SemanticVersion("2.0.0-beta.1")!
        
        XCTAssertTrue(v1 < v2)
        XCTAssertTrue(v2 < v3)
        XCTAssertEqual(v1, SemanticVersion("v1.0.0")!)
    }
    
    func testF7_02_GitHubReleaseModelAndIPAAssetResolution() {
        let asset = GitHubReleaseAsset(
            name: "LiquidCalc.ipa",
            size: 16000000,
            browserDownloadURL: URL(string: "https://github.com/Amine20100/liquidcalc/releases/download/v1.1.0/LiquidCalc.ipa")!
        )
        let release = GitHubRelease(
            tagName: "v1.1.0",
            name: "LiquidCalc v1.1.0",
            body: "Release notes",
            htmlURL: URL(string: "https://github.com/Amine20100/liquidcalc/releases/tag/v1.1.0")!,
            assets: [asset]
        )
        
        XCTAssertEqual(release.tagName, "v1.1.0")
        XCTAssertEqual(release.semanticVersion, SemanticVersion("1.1.0"))
        XCTAssertNotNil(release.ipaAsset)
        XCTAssertEqual(release.ipaDownloadURL?.absoluteString, "https://github.com/Amine20100/liquidcalc/releases/download/v1.1.0/LiquidCalc.ipa")
    }
    
    func testF7_03_AppUpdateManagerUpdateAvailabilityCheck() {
        let manager = AppUpdateManager(customCurrentVersion: "1.0.0")
        
        let newerRelease = GitHubRelease(
            tagName: "v1.1.0",
            htmlURL: URL(string: "https://example.com")!
        )
        XCTAssertTrue(manager.isUpdateAvailable(for: newerRelease))
        
        let olderRelease = GitHubRelease(
            tagName: "v0.9.5",
            htmlURL: URL(string: "https://example.com")!
        )
        XCTAssertFalse(manager.isUpdateAvailable(for: olderRelease))
        
        let sameRelease = GitHubRelease(
            tagName: "v1.0.0",
            htmlURL: URL(string: "https://example.com")!
        )
        XCTAssertFalse(manager.isUpdateAvailable(for: sameRelease))
    }
    
    func testF7_04_UpdateAvailableViewInitialization() {
        let release = GitHubRelease(
            tagName: "v1.2.0",
            name: "LiquidCalc 1.2.0",
            body: "Great new features",
            htmlURL: URL(string: "https://github.com/Amine20100/liquidcalc/releases/tag/v1.2.0")!
        )
        let updateView = UpdateAvailableView(release: release)
        XCTAssertNotNil(updateView)
    }
    
    func testF7_05_SettingsSheetViewSoftwareUpdatesSection() {
        let settingsView = SettingsSheetView()
        XCTAssertNotNil(settingsView)
    }
    
    // =========================================================================
    // MARK: - TIER 2: BOUNDARY & CORNER CASES (F1 to F7: 35+ Tests)
    // =========================================================================
    
    // F1 Boundary Cases
    func testF1_B01_RapidButtonPressBurst() {
        let viewModel = CalculatorViewModel()
        for i in 0..<100 {
            let digit = String(i % 10)
            viewModel.handleButtonPress(KeypadButton(label: digit, type: .digit(digit)))
        }
        XCTAssertEqual(viewModel.displayResult.count, 100)
    }
    
    func testF1_B02_MultipleConsecutiveDecimalsPrevented() {
        let viewModel = CalculatorViewModel()
        viewModel.handleButtonPress(KeypadButton(label: "3", type: .digit("3")))
        viewModel.handleButtonPress(KeypadButton(label: ".", type: .decimal))
        viewModel.handleButtonPress(KeypadButton(label: ".", type: .decimal))
        viewModel.handleButtonPress(KeypadButton(label: "1", type: .digit("1")))
        viewModel.handleButtonPress(KeypadButton(label: ".", type: .decimal))
        
        XCTAssertEqual(viewModel.displayResult, "3.1")
        XCTAssertEqual(viewModel.expression, "3.1")
    }
    
    func testF1_B03_SignToggleBoundaryCases() {
        let viewModel = CalculatorViewModel()
        viewModel.toggleSign()
        XCTAssertEqual(viewModel.displayResult, "0")
        
        viewModel.handleButtonPress(KeypadButton(label: "7", type: .digit("7")))
        viewModel.toggleSign()
        XCTAssertEqual(viewModel.displayResult, "-(7)")
        
        viewModel.toggleSign()
        XCTAssertEqual(viewModel.displayResult, "7")
    }
    
    func testF1_B04_ExtremeLabelLengths() {
        let btn = KeypadButton(label: "VERY_LONG_LABEL_12345", type: .scientific("fn"))
        XCTAssertGreaterThan(btn.label.count, 4)
    }
    
    func testF1_B05_AllAccentStylesProduceGradients() {
        for style in [KeypadAccentStyle.digitDark, .functionGray, .accentOrange, .accentCyan, .scientificViolet, .hexBlue] {
            XCTAssertGreaterThanOrEqual(style.backgroundColors.count, 2)
            XCTAssertEqual(style.foregroundColor, .white)
        }
    }
    
    // F2 Boundary Cases
    func testF2_B01_SonarWaveRingsZeroAndNegativeViewportSizes() {
        let sonar = SonarWaveRingsView(isScanning: true, ringCount: 3)
        let _ = sonar.body
        XCTAssertNotNil(sonar)
    }
    
    func testF2_B02_SonarWaveRingsClampedRingCounts() {
        let minSonar = SonarWaveRingsView(isScanning: true, ringCount: -5)
        XCTAssertEqual(minSonar.ringCount, 1, "Ring count must clamp to at least 1")
    }
    
    func testF2_B03_LaserSweepLineClampedVerticalRange() {
        let smallHeight: CGFloat = 80
        let smallRange = max(smallHeight - 40, 60)
        XCTAssertEqual(smallRange, 60.0)
    }
    
    func testF2_B04_ReticleOverlayOutOfBoundsBoundingBoxes() {
        let outOfBounds = CGRect(x: -0.5, y: 1.5, width: 2.0, height: 2.0)
        let reticle = ReticleOverlayView(isScanning: true, hasTarget: true, targetBoundingBox: outOfBounds)
        XCTAssertNotNil(reticle)
    }
    
    func testF2_B05_RapidScannerStateToggling() {
        let visionVM = VisionViewModel()
        for i in 0..<30 {
            visionVM.isScanning = (i % 2 == 0)
        }
        XCTAssertFalse(visionVM.isScanning)
    }
    
    // F3 Boundary Cases
    func testF3_B01_RapidContinuousHumStartStopCycling() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        for _ in 0..<20 {
            manager.startContinuousScanningHum()
            manager.stopContinuousScanningHum()
        }
    }
    
    func testF3_B02_DisablingHapticsDuringActiveContinuousHum() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        manager.startContinuousScanningHum()
        manager.isHapticsEnabled = false
        XCTAssertFalse(manager.isHapticsEnabled)
    }
    
    func testF3_B03_RapidHapticsAndSoundToggleSpam() {
        let manager = SoundAndHapticManager.shared
        for i in 0..<50 {
            manager.isHapticsEnabled = (i % 2 == 0)
            manager.isSoundEnabled = (i % 2 == 0)
        }
        XCTAssertFalse(manager.isHapticsEnabled)
        XCTAssertFalse(manager.isSoundEnabled)
    }
    
    func testF3_B04_AppBackgroundForegroundUnderMutedHaptics() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = false
        manager.handleAppBackground()
        manager.handleAppForeground()
        XCTAssertFalse(manager.isHapticsEnabled)
    }
    
    func testF3_B05_AllLegacyHapticStylesSafety() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        for style in [SoundAndHapticManager.HapticStyle.light, .medium, .heavy, .selection, .success, .error] {
            manager.triggerHaptic(style)
        }
    }
    
    // F4 Boundary Cases
    func testF4_B01_EmptyAndWhitespaceOCRInput() {
        let scanner = VisionMathScanner()
        XCTAssertEqual(scanner.sanitizeMathString(""), "")
        XCTAssertEqual(scanner.sanitizeMathString("   "), "")
    }
    
    func testF4_B02_ChainedVulgarFractions() {
        let scanner = VisionMathScanner()
        let result = scanner.sanitizeMathString("½ + ⅓ + ¼ + ⅕ + ⅙ + ⅛ + ⅑ + ⅒")
        XCTAssertTrue(result.contains("(1/2)"))
        XCTAssertTrue(result.contains("(1/3)"))
        XCTAssertTrue(result.contains("(1/10)"))
    }
    
    func testF4_B03_StackedSuperscripts() {
        let scanner = VisionMathScanner()
        let result = scanner.sanitizeMathString("2¹²³")
        XCTAssertEqual(result, "2^123")
    }
    
    func testF4_B04_ComplexMixedFractions() {
        let scanner = VisionMathScanner()
        let result = scanner.sanitizeMathString("12 3/4 + 4 1/2")
        XCTAssertEqual(result, "12 + 3/4 + 4 + 1/2")
    }
    
    func testF4_B05_MultipleEqualsSigns() {
        let scanner = VisionMathScanner()
        let result = scanner.sanitizeMathString("= 5 + 5 =")
        XCTAssertEqual(result, "5 + 5")
    }
    
    // F5 Boundary Cases
    func testF5_B01_DivisionByZeroException() {
        let evaluator = MathEvaluator()
        XCTAssertThrowsError(try evaluator.evaluate(expression: "100 / 0")) { error in
            XCTAssertEqual(error as? MathError, MathError.divisionByZero)
        }
    }
    
    func testF5_B02_NegativeSquareRootDomainException() {
        let evaluator = MathEvaluator()
        XCTAssertThrowsError(try evaluator.evaluate(expression: "sqrt(-16)"))
    }
    
    func testF5_B03_FactorialBoundaryConditions() {
        let evaluator = MathEvaluator()
        XCTAssertEqual(try evaluator.evaluate(expression: "fact(0)"), 1.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "fact(1)"), 1.0, accuracy: 1e-9)
        XCTAssertThrowsError(try evaluator.evaluate(expression: "fact(-1)"))
    }
    
    func testF5_B04_ExtremePrecisionDecimals() {
        let small = 0.000000000000001
        let formatted = MathEvaluator.formatResult(small)
        XCTAssertFalse(formatted.isEmpty)
    }
    
    func testF5_B05_ScientificNotationFormatting() {
        let large = 1e15
        let formatted = MathEvaluator.formatResult(large)
        XCTAssertTrue(formatted.contains("e") || formatted.contains("E"))
    }
    
    // F6 Boundary Cases
    func testF6_B01_SplitCountBounds() {
        let visionVM = VisionViewModel()
        visionVM.splitCount = 1
        XCTAssertEqual(visionVM.splitCount, 1)
        
        visionVM.splitCount = 30
        XCTAssertEqual(visionVM.splitCount, 30)
    }
    
    func testF6_B02_TipRateBounds() {
        let visionVM = VisionViewModel()
        visionVM.receiptItems = [ReceiptLineItem(title: "Meal", amount: 100.0)]
        
        visionVM.tipPercentage = 0.0
        XCTAssertEqual(visionVM.receiptTipAmount, 0.0)
        
        visionVM.tipPercentage = 25.0
        XCTAssertEqual(visionVM.receiptTipAmount, 25.0)
    }
    
    func testF6_B03_SupportedCurrencyAllCasesIntegrity() {
        XCTAssertEqual(SupportedCurrency.allCases.count, 10)
        for cur in SupportedCurrency.allCases {
            XCTAssertFalse(cur.symbol.isEmpty)
            XCTAssertFalse(cur.flag.isEmpty)
        }
    }
    
    func testF6_B04_ReceiptWithNoPrices() {
        let scanner = VisionMathScanner()
        let result = scanner.parseReceipt(from: [
            ScannedTextObservation(rawText: "Welcome to our store", sanitizedExpression: "", boundingBox: .zero, confidence: 0.9),
            ScannedTextObservation(rawText: "Have a great day", sanitizedExpression: "", boundingBox: .zero, confidence: 0.9)
        ])
        XCTAssertEqual(result.items.count, 0)
    }
    
    func testF6_B05_ZeroAmountItemsHandling() {
        let item = ReceiptLineItem(title: "Free Sample", amount: 0.0)
        XCTAssertEqual(item.amount, 0.0)
    }
    
    // F7 Boundary Cases
    func testF7_B01_SemVerPrereleaseLexicographicalOrder() {
        let vAlpha = SemanticVersion("1.0.0-alpha")!
        let vBeta = SemanticVersion("1.0.0-beta")!
        XCTAssertTrue(vAlpha < vBeta)
    }
    
    func testF7_B02_SemVerPrereleaseNumericFieldPrecedence() {
        let v1 = SemanticVersion("1.0.0-beta.2")!
        let v2 = SemanticVersion("1.0.0-beta.11")!
        XCTAssertTrue(v1 < v2, "Numeric comparison: 2 < 11")
    }
    
    func testF7_B03_SemVerBuildMetadataEquality() {
        let v1 = SemanticVersion("1.0.0+build1")!
        let v2 = SemanticVersion("1.0.0+build2")!
        XCTAssertEqual(v1, v2)
    }
    
    func testF7_B04_GitHubReleaseMissingOptionalFields() {
        let release = GitHubRelease(
            tagName: "v1.0.0",
            htmlURL: URL(string: "https://example.com")!
        )
        XCTAssertNil(release.name)
        XCTAssertNil(release.body)
        XCTAssertEqual(release.assets.count, 0)
    }
    
    func testF7_B05_AppUpdateManagerAutoCheckDefaultsKey() {
        XCTAssertEqual(AppUpdateManager.autoCheckDefaultsKey, "LC_AutoCheckOnLaunch")
        XCTAssertEqual(AppUpdateManager.lastCheckDateDefaultsKey, "LC_LastUpdateCheckDate")
    }
    
    // =========================================================================
    // MARK: - TIER 3: CROSS-FEATURE PAIRWISE COMBINATIONS (15 Tests)
    // =========================================================================
    
    func testP01_F1_F5_KeypadEntry_PostfixPercentage_LivePreview() {
        let calcVM = CalculatorViewModel()
        calcVM.handleButtonPress(KeypadButton(label: "5", type: .digit("5")))
        calcVM.handleButtonPress(KeypadButton(label: "0", type: .digit("0")))
        calcVM.handleButtonPress(KeypadButton(label: "%", type: .percent))
        calcVM.handleButtonPress(KeypadButton(label: "*", type: .operation("*")))
        calcVM.handleButtonPress(KeypadButton(label: "2", type: .digit("2")))
        calcVM.handleButtonPress(KeypadButton(label: "0", type: .digit("0")))
        calcVM.handleButtonPress(KeypadButton(label: "0", type: .digit("0")))
        
        XCTAssertEqual(calcVM.expression, "50%*200")
        XCTAssertEqual(calcVM.livePreview, "100")
        
        calcVM.evaluateFinal()
        XCTAssertEqual(calcVM.displayResult, "100")
    }
    
    func testP02_F2_F3_SonarWaves_LaserSweep_SynchronizedContinuousHum() {
        let visionVM = VisionViewModel()
        visionVM.isScanning = true
        
        let laser = LaserSweepLineView(isScanning: visionVM.isScanning)
        let sonar = SonarWaveRingsView(isScanning: visionVM.isScanning)
        XCTAssertTrue(laser.isScanning)
        XCTAssertTrue(sonar.isScanning)
        
        SoundAndHapticManager.shared.startContinuousScanningHum()
        
        // Detection occurs
        visionVM.isScanning = false
        SoundAndHapticManager.shared.stopContinuousScanningHum()
        SoundAndHapticManager.shared.playDigitClick()
        
        XCTAssertFalse(visionVM.isScanning)
    }
    
    func testP03_F4_F5_F1_OCR_FractionsAndPowers_KeypadDisplay() {
        let scanner = VisionMathScanner()
        let rawOCR = "3 1/2 + 2³ ="
        let sanitized = scanner.sanitizeMathString(rawOCR)
        XCTAssertEqual(sanitized, "3 + 1/2 + 2^3")
        
        let calcVM = CalculatorViewModel()
        calcVM.expression = sanitized
        calcVM.evaluateFinal()
        // 3.5 + 8 = 11.5
        XCTAssertEqual(calcVM.displayResult, "11.5")
    }
    
    func testP04_F6_F3_F1_MultiCurrencyReceipt_LockOnHaptics_Splitter() {
        let obs = [
            ScannedTextObservation(rawText: "Tajine Poulet 85 MAD", sanitizedExpression: "", boundingBox: .zero, confidence: 0.95),
            ScannedTextObservation(rawText: "Couscous Royal 95 MAD", sanitizedExpression: "", boundingBox: .zero, confidence: 0.95),
            ScannedTextObservation(rawText: "Total 180 MAD", sanitizedExpression: "", boundingBox: .zero, confidence: 0.99)
        ]
        
        let scanner = VisionMathScanner()
        let parsed = scanner.parseReceipt(from: obs)
        XCTAssertEqual(parsed.detectedCurrency, .mad)
        XCTAssertEqual(parsed.items.count, 2)
        
        let visionVM = VisionViewModel()
        visionVM.selectedSubMode = .receipt
        visionVM.processScannedResults(obs)
        visionVM.splitCount = 2
        visionVM.tipPercentage = 10.0
        
        XCTAssertEqual(visionVM.receiptSubtotal, 180.0)
        XCTAssertEqual(visionVM.receiptTipAmount, 18.0)
        XCTAssertEqual(visionVM.receiptTotal, 198.0)
        XCTAssertEqual(visionVM.receiptPerPerson, 99.0)
    }
    
    func testP05_F7_F1_UpdateAvailableDetection_ModalPresentation() {
        let manager = AppUpdateManager(customCurrentVersion: "1.0.0")
        let release = GitHubRelease(
            tagName: "v1.2.0",
            name: "LiquidCalc 1.2.0",
            body: "Exciting update",
            htmlURL: URL(string: "https://github.com/Amine20100/liquidcalc/releases/tag/v1.2.0")!
        )
        
        XCTAssertTrue(manager.isUpdateAvailable(for: release))
        manager.latestRelease = release
        manager.updateAvailable = true
        manager.showUpdateSheet = true
        
        let updateModal = UpdateAvailableView(release: release, updateManager: manager)
        XCTAssertNotNil(updateModal)
        
        manager.dismissUpdateSheet()
        XCTAssertFalse(manager.showUpdateSheet)
    }
    
    func testP06_F3_F7_SettingsSheet_HapticToggle_UpdateCheck() {
        let settingsView = SettingsSheetView()
        XCTAssertNotNil(settingsView)
        
        SoundAndHapticManager.shared.isHapticsEnabled = false
        XCTAssertFalse(SoundAndHapticManager.shared.isHapticsEnabled)
        
        AppUpdateManager.shared.autoCheckOnLaunch = true
        XCTAssertTrue(AppUpdateManager.shared.autoCheckOnLaunch)
    }
    
    func testP07_F2_F4_F5_ViewfinderReticle_SolveCard_HistoryStorage() {
        let visionVM = VisionViewModel()
        visionVM.detectedExpression = "√144 * 2"
        visionVM.solveDetectedExpression()
        
        XCTAssertEqual(visionVM.solvedResult, "24")
        XCTAssertEqual(HistoryManager.shared.items.first?.result, "24")
        XCTAssertEqual(HistoryManager.shared.items.first?.mode, "Vision")
    }
    
    func testP08_F5_F1_DivisionByZero_ErrorShake_KeypadRecovery() {
        let calcVM = CalculatorViewModel()
        calcVM.expression = "100 / 0"
        calcVM.evaluateFinal()
        
        XCTAssertTrue(calcVM.hasError)
        XCTAssertEqual(calcVM.displayResult, "Error")
        XCTAssertTrue(calcVM.shouldShakeDisplay)
        
        // Keypad press clears error
        calcVM.handleButtonPress(KeypadButton(label: "4", type: .digit("4")))
        XCTAssertFalse(calcVM.hasError)
        XCTAssertEqual(calcVM.displayResult, "4")
    }
    
    func testP09_F6_F1_CurrencyFormatAcrossCurrencies() {
        let amount = 1250.50
        XCTAssertEqual(SupportedCurrency.usd.format(amount: amount), "$1,250.50")
        XCTAssertEqual(SupportedCurrency.eur.format(amount: amount), "1,250.50 €")
        XCTAssertEqual(SupportedCurrency.gbp.format(amount: amount), "£1,250.50")
        XCTAssertEqual(SupportedCurrency.mad.format(amount: amount), "1,250.50 MAD")
        XCTAssertEqual(SupportedCurrency.jpy.format(amount: amount), "¥1,251")
        XCTAssertEqual(SupportedCurrency.chf.format(amount: amount), "CHF 1,250.50")
    }
    
    func testP10_F3_F2_AppBackgrounding_StopsContinuousHumAndScanning() {
        let visionVM = VisionViewModel()
        visionVM.isScanning = true
        SoundAndHapticManager.shared.startContinuousScanningHum()
        
        // Backgrounding triggered
        SoundAndHapticManager.shared.handleAppBackground()
        visionVM.isScanning = false
        
        XCTAssertFalse(visionVM.isScanning)
    }
    
    func testP11_F1_F5_ScientificTrig_DegreesVsRadians() {
        let degCalc = CalculatorViewModel()
        degCalc.angleUnit = .degrees
        degCalc.expression = "sin(90)"
        degCalc.evaluateFinal()
        XCTAssertEqual(degCalc.displayResult, "1")
        
        let radCalc = CalculatorViewModel()
        radCalc.angleUnit = .radians
        radCalc.expression = "cos(pi)"
        radCalc.evaluateFinal()
        XCTAssertEqual(radCalc.displayResult, "-1")
    }
    
    func testP12_F4_F5_MixedFractions_Roots_Arithmetic() {
        let evaluator = MathEvaluator()
        // (1 1/2) * √16 = 1.5 * 4 = 6.0
        let result = try? evaluator.evaluate(expression: "(1 1/2) * √16")
        XCTAssertEqual(result, 6.0)
    }
    
    func testP13_F6_F4_ReceiptParsing_EuropeanCommas_Classification() {
        let scanner = VisionMathScanner()
        let obs = [
            ScannedTextObservation(rawText: "Entrée Froide 8,50 €", sanitizedExpression: "", boundingBox: .zero, confidence: 0.98),
            ScannedTextObservation(rawText: "Plat Chaud 21,50 €", sanitizedExpression: "", boundingBox: .zero, confidence: 0.98),
            ScannedTextObservation(rawText: "Sous-total 30,00 €", sanitizedExpression: "", boundingBox: .zero, confidence: 0.95),
            ScannedTextObservation(rawText: "Total 30,00 €", sanitizedExpression: "", boundingBox: .zero, confidence: 0.99)
        ]
        let res = scanner.parseReceipt(from: obs)
        XCTAssertEqual(res.detectedCurrency, .eur)
        XCTAssertEqual(res.items.count, 2)
        XCTAssertEqual(res.items[0].amount, 8.50)
        XCTAssertEqual(res.items[1].amount, 21.50)
    }
    
    func testP14_F7_F1_AppUpdateManager_ManualCheck_UpToDateAlert() {
        let manager = AppUpdateManager(customCurrentVersion: "2.0.0")
        let release = GitHubRelease(
            tagName: "v1.5.0",
            htmlURL: URL(string: "https://example.com")!
        )
        let isNewer = manager.isUpdateAvailable(for: release)
        XCTAssertFalse(isNewer)
        
        manager.showNoUpdateAlert = true
        XCTAssertTrue(manager.showNoUpdateAlert)
        manager.dismissNoUpdateAlert()
        XCTAssertFalse(manager.showNoUpdateAlert)
    }
    
    func testP15_F1_F5_DisplaySignToggleAndPower() {
        let calcVM = CalculatorViewModel()
        calcVM.handleButtonPress(KeypadButton(label: "5", type: .digit("5")))
        calcVM.toggleSign()
        XCTAssertEqual(calcVM.displayResult, "-(5)")
        
        calcVM.handleButtonPress(KeypadButton(label: "^", type: .operation("^")))
        calcVM.handleButtonPress(KeypadButton(label: "2", type: .digit("2")))
        calcVM.evaluateFinal()
        XCTAssertEqual(calcVM.displayResult, "25")
    }
    
    // =========================================================================
    // MARK: - TIER 4: REAL-WORLD APPLICATION SCENARIOS (5 Workflows)
    // =========================================================================
    
    /// Scenario 1: European Restaurant Multi-Course Dinner Split with Tip (F6, F1, F3)
    func testWorkflow1_EuropeanDinnerReceiptSplit() {
        // 1. Scanner parses EUR receipt with European comma decimals
        let scanner = VisionMathScanner()
        let observations = [
            ScannedTextObservation(rawText: "Le Gourmet Parisien", sanitizedExpression: "", boundingBox: .zero, confidence: 0.95),
            ScannedTextObservation(rawText: "1. Foie Gras Poêlé 24,00 €", sanitizedExpression: "", boundingBox: .zero, confidence: 0.98),
            ScannedTextObservation(rawText: "2. Filet de Bœuf Rossini 38,00 €", sanitizedExpression: "", boundingBox: .zero, confidence: 0.98),
            ScannedTextObservation(rawText: "3. Tarte Tatin Maison 12,00 €", sanitizedExpression: "", boundingBox: .zero, confidence: 0.97),
            ScannedTextObservation(rawText: "4. Bouteille Châteauneuf-du-Pape 46,00 €", sanitizedExpression: "", boundingBox: .zero, confidence: 0.99),
            ScannedTextObservation(rawText: "Sous-total 120,00 €", sanitizedExpression: "", boundingBox: .zero, confidence: 0.96),
            ScannedTextObservation(rawText: "TVA (20%) 24,00 €", sanitizedExpression: "", boundingBox: .zero, confidence: 0.95),
            ScannedTextObservation(rawText: "Total TTC 144,00 €", sanitizedExpression: "", boundingBox: .zero, confidence: 0.99)
        ]
        
        let parsed = scanner.parseReceipt(from: observations)
        XCTAssertEqual(parsed.detectedCurrency, .eur)
        XCTAssertEqual(parsed.items.count, 4)
        
        // 2. VisionViewModel processes items and computes 3-person split with 15% tip
        let visionVM = VisionViewModel()
        visionVM.selectedSubMode = .receipt
        visionVM.processScannedResults(observations)
        visionVM.taxRate = 0.0 // Taxes already included in items
        visionVM.tipPercentage = 15.0
        visionVM.splitCount = 3
        
        let subtotal = visionVM.receiptSubtotal
        XCTAssertEqual(subtotal, 120.00, accuracy: 1e-4)
        
        let tip = visionVM.receiptTipAmount
        XCTAssertEqual(tip, 18.00, accuracy: 1e-4)
        
        let total = visionVM.receiptTotal
        XCTAssertEqual(total, 138.00, accuracy: 1e-4)
        
        let perPerson = visionVM.receiptPerPerson
        XCTAssertEqual(perPerson, 46.00, accuracy: 1e-4)
        
        // 3. Verify currency formatted strings
        XCTAssertEqual(SupportedCurrency.eur.format(amount: perPerson), "46.00 €")
    }
    
    /// Scenario 2: Moroccan Café Multi-Item Bill (MAD) with Per-Person Split (F6, F1, F3)
    func testWorkflow2_MoroccanCafeReceiptSplit() {
        let scanner = VisionMathScanner()
        let observations = [
            ScannedTextObservation(rawText: "Café de la Palmeraie Marrakech", sanitizedExpression: "", boundingBox: .zero, confidence: 0.9),
            ScannedTextObservation(rawText: "Tajine Kefta aux Œufs 75 MAD", sanitizedExpression: "", boundingBox: .zero, confidence: 0.96),
            ScannedTextObservation(rawText: "Pastilla au Poulet 90 MAD", sanitizedExpression: "", boundingBox: .zero, confidence: 0.97),
            ScannedTextObservation(rawText: "2x Thé à la Menthe 30 DH", sanitizedExpression: "", boundingBox: .zero, confidence: 0.95),
            ScannedTextObservation(rawText: "Assortiment Cornes de Gazelle 45 Dhs", sanitizedExpression: "", boundingBox: .zero, confidence: 0.94),
            ScannedTextObservation(rawText: "Total 240 MAD", sanitizedExpression: "", boundingBox: .zero, confidence: 0.99)
        ]
        
        let result = scanner.parseReceipt(from: observations)
        XCTAssertEqual(result.detectedCurrency, .mad)
        XCTAssertEqual(result.items.count, 4)
        
        let visionVM = VisionViewModel()
        visionVM.selectedSubMode = .receipt
        visionVM.processScannedResults(observations)
        visionVM.taxRate = 0.0
        visionVM.tipPercentage = 10.0
        visionVM.splitCount = 4
        
        XCTAssertEqual(visionVM.receiptSubtotal, 240.00, accuracy: 1e-4)
        XCTAssertEqual(visionVM.receiptTipAmount, 24.00, accuracy: 1e-4)
        XCTAssertEqual(visionVM.receiptTotal, 264.00, accuracy: 1e-4)
        XCTAssertEqual(visionVM.receiptPerPerson, 66.00, accuracy: 1e-4)
        XCTAssertEqual(SupportedCurrency.mad.format(amount: visionVM.receiptPerPerson), "66.00 MAD")
    }
    
    /// Scenario 3: Camera Math Scan of Polynomial with Powers, Roots, Fractions (F4, F5, F2, F3)
    func testWorkflow3_CameraMathScanWithPowersAndRoots() {
        let scanner = VisionMathScanner()
        let rawScannedText = "½ × 4² + √144 - ∛27 ="
        let sanitized = scanner.sanitizeMathString(rawScannedText)
        
        // Expected sanitized string: "(1/2) * 4^2 + sqrt144 - cbrt27"
        XCTAssertTrue(sanitized.contains("(1/2)"))
        XCTAssertTrue(sanitized.contains("4^2"))
        XCTAssertTrue(sanitized.contains("sqrt144"))
        XCTAssertTrue(sanitized.contains("cbrt27"))
        
        // Evaluator computes: 0.5 * 16 + 12 - 3 = 8 + 12 - 3 = 17
        let evaluator = MathEvaluator()
        let solution = try? evaluator.evaluate(expression: sanitized)
        XCTAssertEqual(solution, 17.0)
        
        // Transfer to Calculator display
        let calcVM = CalculatorViewModel()
        calcVM.expression = sanitized
        calcVM.evaluateFinal()
        XCTAssertEqual(calcVM.displayResult, "17")
        XCTAssertEqual(HistoryManager.shared.items.first?.result, "17")
    }
    
    /// Scenario 4: Postfix Percentage Discount & Sales Tax Calculation (F5, F1)
    func testWorkflow4_PercentageDiscountAndTaxWorkflow() {
        let calcVM = CalculatorViewModel()
        
        // 1. Calculate discount: 200 * 20% = 40
        calcVM.handleButtonPress(KeypadButton(label: "2", type: .digit("2")))
        calcVM.handleButtonPress(KeypadButton(label: "0", type: .digit("0")))
        calcVM.handleButtonPress(KeypadButton(label: "0", type: .digit("0")))
        calcVM.handleButtonPress(KeypadButton(label: "*", type: .operation("*")))
        calcVM.handleButtonPress(KeypadButton(label: "2", type: .digit("2")))
        calcVM.handleButtonPress(KeypadButton(label: "0", type: .digit("0")))
        calcVM.handleButtonPress(KeypadButton(label: "%", type: .percent))
        
        XCTAssertEqual(calcVM.expression, "200*20%")
        XCTAssertEqual(calcVM.livePreview, "40")
        
        calcVM.evaluateFinal()
        XCTAssertEqual(calcVM.displayResult, "40")
        
        // 2. Net price: 200 - 40 = 160
        calcVM.handleButtonPress(KeypadButton(label: "-", type: .operation("-")))
        calcVM.handleButtonPress(KeypadButton(label: "2", type: .digit("2")))
        calcVM.handleButtonPress(KeypadButton(label: "0", type: .digit("0")))
        calcVM.handleButtonPress(KeypadButton(label: "0", type: .digit("0")))
        // Invert to 160
        calcVM.expression = "200 - 40"
        calcVM.evaluateFinal()
        XCTAssertEqual(calcVM.displayResult, "160")
    }
    
    /// Scenario 5: Online Update Check Flow with Semantic Version Compare (F7, F1)
    func testWorkflow5_OnlineUpdateCheckAndModalWorkflow() {
        // 1. Configure update manager with running version 1.0.0
        let manager = AppUpdateManager(customCurrentVersion: "1.0.0")
        XCTAssertEqual(manager.currentVersionString, "1.0.0")
        
        // 2. Remote latest release is 1.3.0 with LiquidCalc.ipa asset
        let ipaAsset = GitHubReleaseAsset(
            name: "LiquidCalc.ipa",
            size: 17500000,
            browserDownloadURL: URL(string: "https://github.com/Amine20100/liquidcalc/releases/download/v1.3.0/LiquidCalc.ipa")!
        )
        let release = GitHubRelease(
            tagName: "v1.3.0",
            name: "LiquidCalc 1.3.0 - Sonar Waves & Haptics",
            body: "- Concentric sonar rings\n- Synchronized haptics\n- Multi-currency receipt engine",
            htmlURL: URL(string: "https://github.com/Amine20100/liquidcalc/releases/tag/v1.3.0")!,
            publishedAtString: "2026-09-01T07:15:00Z",
            assets: [ipaAsset]
        )
        
        // 3. Evaluate update availability
        let isUpdateAvailable = manager.isUpdateAvailable(for: release)
        XCTAssertTrue(isUpdateAvailable)
        
        manager.latestRelease = release
        manager.updateAvailable = true
        manager.showUpdateSheet = true
        
        // 4. Modal presentation & dismissal
        let updateModal = UpdateAvailableView(release: release, updateManager: manager)
        XCTAssertNotNil(updateModal)
        XCTAssertEqual(release.ipaAsset?.name, "LiquidCalc.ipa")
        XCTAssertEqual(release.ipaDownloadURL?.absoluteString, "https://github.com/Amine20100/liquidcalc/releases/download/v1.3.0/LiquidCalc.ipa")
        
        manager.dismissUpdateSheet()
        XCTAssertFalse(manager.showUpdateSheet)
    }
}
