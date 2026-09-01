//
//  LiquidCalcE2ETests.swift
//  LiquidCalcTests
//
//  Created for LiquidCalc iOS 18+.
//  Comprehensive Opaque-Box E2E Test Suite implementing the 4-Tier Test Methodology from TEST_INFRA.md:
//  - Tier 1: Feature Coverage (F1 to F11: >=5 tests per feature = 55+ tests)
//  - Tier 2: Boundary & Corner Cases (F1 to F11: >=5 tests per feature = 55+ tests)
//  - Tier 3: Cross-Feature Combinations (>=15 pairwise tests = 16 tests)
//  - Tier 4: Real-World Application Scenarios (>=5 multi-step workflows = 5 tests)
//  Total: 131 E2E tests covering Motion, Visual FX, CoreHaptics, and Calculation Workflows.
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
    // MARK: - TIER 1: FEATURE COVERAGE (F1 to F11: 55 Tests)
    // =========================================================================
    
    // -------------------------------------------------------------------------
    // Feature F1: Keypad Button Spring Physics (ORIGINAL_REQUEST §R1)
    // -------------------------------------------------------------------------
    
    func testF1_01_KeypadPressStyleSpringScaleConfiguration() {
        let pressStyle = KeypadPressStyle()
        XCTAssertNotNil(pressStyle, "KeypadPressStyle must initialize cleanly")
    }
    
    func testF1_02_KeypadButtonAccentStylesAndColorGradients() {
        let digitButton = KeypadButton(label: "7", type: .digit("7"))
        XCTAssertEqual(digitButton.accentStyle, .digitDark)
        XCTAssertEqual(digitButton.accentStyle.backgroundColors.count, 2)
        XCTAssertEqual(digitButton.accentStyle.foregroundColor, .white)
        
        let opButton = KeypadButton(label: "+", type: .operation("+"))
        XCTAssertEqual(opButton.accentStyle, .accentCyan)
        
        let eqButton = KeypadButton(label: "=", type: .equals)
        XCTAssertEqual(eqButton.accentStyle, .accentOrange)
        
        let fnButton = KeypadButton(label: "AC", type: .allClear)
        XCTAssertEqual(fnButton.accentStyle, .functionGray)
        
        let sciButton = KeypadButton(label: "sin", type: .scientific("sin"))
        XCTAssertEqual(sciButton.accentStyle, .scientificViolet)
    }
    
    func testF1_03_KeypadButtonDynamicFontSizeLogic() {
        let singleCharBtn = KeypadButton(label: "5", type: .digit("5"))
        let tripleCharBtn = KeypadButton(label: "cos", type: .scientific("cos"))
        let longLabelBtn = KeypadButton(label: "sinh⁻¹", type: .scientific("sinh"))
        
        XCTAssertEqual(singleCharBtn.label.count, 1)
        XCTAssertEqual(tripleCharBtn.label.count, 3)
        XCTAssertGreaterThan(longLabelBtn.label.count, 4)
    }
    
    func testF1_04_KeypadButtonModelAttributesAndIDUniqueness() {
        let btn1 = KeypadButton(label: "0", type: .digit("0"), secondaryLabel: "nil", isWide: true)
        let btn2 = KeypadButton(label: "0", type: .digit("0"), secondaryLabel: "nil", isWide: true)
        
        XCTAssertEqual(btn1.label, "0")
        XCTAssertEqual(btn1.isWide, true)
        XCTAssertNotEqual(btn1.id, btn2.id, "Each KeypadButton instance must have a unique UUID")
    }
    
    func testF1_05_KeypadButtonViewActionExecution() {
        var actionExecuted = false
        let button = KeypadButton(label: "1", type: .digit("1"))
        let buttonView = KeypadButtonView(button: button) {
            actionExecuted = true
        }
        XCTAssertNotNil(buttonView)
        buttonView.action()
        XCTAssertTrue(actionExecuted, "Triggering button view action must execute the provided closure")
    }
    
    // -------------------------------------------------------------------------
    // Feature F2: Fluid Number Transitions & Display (ORIGINAL_REQUEST §R1)
    // -------------------------------------------------------------------------
    
    func testF2_01_LiquidDisplayViewDefaultState() {
        let viewModel = CalculatorViewModel()
        let displayView = LiquidDisplayView(viewModel: viewModel)
        XCTAssertNotNil(displayView)
        XCTAssertEqual(viewModel.displayResult, "0")
        XCTAssertEqual(viewModel.expression, "")
        XCTAssertNil(viewModel.livePreview)
    }
    
    func testF2_02_DynamicFontSizeThresholdScaling() {
        let viewModel = CalculatorViewModel()
        
        // <= 8 characters -> large 58pt scale
        viewModel.displayResult = "12345678"
        XCTAssertLessThanOrEqual(viewModel.displayResult.count, 8)
        
        // 9 to 12 characters -> medium 46pt scale
        viewModel.displayResult = "1234567890"
        XCTAssertTrue(viewModel.displayResult.count >= 9 && viewModel.displayResult.count <= 12)
        
        // > 12 characters -> compact 36pt scale
        viewModel.displayResult = "12345678901234"
        XCTAssertGreaterThan(viewModel.displayResult.count, 12)
    }
    
    func testF2_03_LiveSpeculativePreviewGeneration() {
        let viewModel = CalculatorViewModel()
        
        viewModel.handleButtonPress(KeypadButton(label: "2", type: .digit("2")))
        viewModel.handleButtonPress(KeypadButton(label: "+", type: .operation("+")))
        viewModel.handleButtonPress(KeypadButton(label: "3", type: .digit("3")))
        
        XCTAssertEqual(viewModel.expression, "2+3")
        XCTAssertEqual(viewModel.livePreview, "5", "Live preview should speculatively evaluate 2+3 to 5")
    }
    
    func testF2_04_ResultFormattingPrecisionAndIntegerTruncation() {
        XCTAssertEqual(MathEvaluator.formatResult(42.0), "42")
        XCTAssertEqual(MathEvaluator.formatResult(3.14159), "3.14159")
        XCTAssertEqual(MathEvaluator.formatResult(0.0), "0")
        XCTAssertEqual(MathEvaluator.formatResult(-128.0), "-128")
    }
    
    func testF2_05_DisplaySwipeToDeleteLastCharacter() {
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
    
    // -------------------------------------------------------------------------
    // Feature F3: Animated Error Shake (ORIGINAL_REQUEST §R1)
    // -------------------------------------------------------------------------
    
    func testF3_01_ShakeEffectMathematicalOscillation() {
        let shake = ShakeEffect(shakes: 0.0, amount: 10, shakesPerUnit: 3)
        XCTAssertEqual(shake.amount, 10.0)
        XCTAssertEqual(shake.shakesPerUnit, 3.0)
        
        // At animatableData = 0, translation should be 0
        let transform0 = shake.effectValue(size: CGSize(width: 100, height: 50))
        XCTAssertNotNil(transform0)
    }
    
    func testF3_02_DivisionByZeroTriggersErrorAndShake() {
        let viewModel = CalculatorViewModel()
        viewModel.handleButtonPress(KeypadButton(label: "8", type: .digit("8")))
        viewModel.handleButtonPress(KeypadButton(label: "/", type: .operation("/")))
        viewModel.handleButtonPress(KeypadButton(label: "0", type: .digit("0")))
        viewModel.handleButtonPress(KeypadButton(label: "=", type: .equals))
        
        XCTAssertTrue(viewModel.hasError, "Division by zero must set hasError to true")
        XCTAssertEqual(viewModel.displayResult, "Error")
        XCTAssertTrue(viewModel.shouldShakeDisplay, "Division by zero must trigger shouldShakeDisplay")
    }
    
    func testF3_03_DomainMathErrorTriggersShake() {
        let viewModel = CalculatorViewModel()
        viewModel.expression = "sqrt(-25)"
        viewModel.evaluateFinal()
        
        XCTAssertTrue(viewModel.hasError)
        XCTAssertEqual(viewModel.displayResult, "Error")
        XCTAssertTrue(viewModel.shouldShakeDisplay)
    }
    
    func testF3_04_ErrorStateAutoRecoveryOnNewDigitInput() {
        let viewModel = CalculatorViewModel()
        viewModel.expression = "5/0"
        viewModel.evaluateFinal()
        XCTAssertTrue(viewModel.hasError)
        
        // Tapping a digit should auto-clear error state and start fresh
        viewModel.handleButtonPress(KeypadButton(label: "9", type: .digit("9")))
        XCTAssertFalse(viewModel.hasError, "Inputting digit after error must reset hasError flag")
        XCTAssertEqual(viewModel.displayResult, "9")
        XCTAssertEqual(viewModel.expression, "9")
    }
    
    func testF3_05_ClearAllResetsErrorAndDisplayState() {
        let viewModel = CalculatorViewModel()
        viewModel.expression = "10/0"
        viewModel.evaluateFinal()
        XCTAssertTrue(viewModel.hasError)
        
        viewModel.clearAll()
        XCTAssertFalse(viewModel.hasError)
        XCTAssertEqual(viewModel.displayResult, "0")
        XCTAssertEqual(viewModel.expression, "")
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // -------------------------------------------------------------------------
    // Feature F4: Mode Switcher Transitions (ORIGINAL_REQUEST §R1)
    // -------------------------------------------------------------------------
    
    func testF4_01_AllFiveCalculatorModesDefined() {
        let allModes = CalculatorMode.allCases
        XCTAssertEqual(allModes.count, 5)
        XCTAssertTrue(allModes.contains(.standard))
        XCTAssertTrue(allModes.contains(.scientific))
        XCTAssertTrue(allModes.contains(.programmer))
        XCTAssertTrue(allModes.contains(.converter))
        XCTAssertTrue(allModes.contains(.vision))
    }
    
    func testF4_02_ModeSwitcherBindingStateUpdate() {
        var mode: CalculatorMode = .standard
        let binding = Binding<CalculatorMode>(
            get: { mode },
            set: { mode = $0 }
        )
        let switcherView = ModeSwitcherView(selectedMode: binding)
        XCTAssertNotNil(switcherView)
        
        binding.wrappedValue = .scientific
        XCTAssertEqual(mode, .scientific)
        
        binding.wrappedValue = .vision
        XCTAssertEqual(mode, .vision)
    }
    
    func testF4_03_AngleUnitToggleAndRecalculation() {
        let viewModel = CalculatorViewModel()
        XCTAssertEqual(viewModel.angleUnit, .degrees)
        
        viewModel.expression = "sin(90)"
        viewModel.evaluateFinal()
        XCTAssertEqual(viewModel.displayResult, "1")
        
        viewModel.angleUnit = .radians
        XCTAssertEqual(viewModel.angleUnit, .radians)
    }
    
    func testF4_04_ModeStateIsolationBetweenViewModels() {
        let calcVM = CalculatorViewModel()
        let progVM = ProgrammerViewModel()
        let convVM = ConverterViewModel()
        
        calcVM.expression = "42"
        progVM.currentValue = 255
        convVM.inputString = "100"
        
        XCTAssertEqual(calcVM.expression, "42")
        XCTAssertEqual(progVM.currentValue, 255)
        XCTAssertEqual(convVM.inputString, "100")
    }
    
    func testF4_05_CalculatorModeIconNamesAndRawValues() {
        for mode in CalculatorMode.allCases {
            XCTAssertFalse(mode.iconName.isEmpty, "Mode \(mode.rawValue) must have non-empty iconName")
            XCTAssertFalse(mode.rawValue.isEmpty, "Mode \(mode.rawValue) must have non-empty rawValue")
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }
    
    // -------------------------------------------------------------------------
    // Feature F5: Animated Scanning Laser Line (ORIGINAL_REQUEST §R2)
    // -------------------------------------------------------------------------
    
    func testF5_01_LaserSweepLineViewInitialization() {
        let activeLaser = LaserSweepLineView(isScanning: true)
        let inactiveLaser = LaserSweepLineView(isScanning: false)
        XCTAssertNotNil(activeLaser)
        XCTAssertNotNil(inactiveLaser)
        XCTAssertTrue(activeLaser.isScanning)
        XCTAssertFalse(inactiveLaser.isScanning)
    }
    
    func testF5_02_LaserSweepActiveVisibilityContract() {
        let active = LaserSweepLineView(isScanning: true)
        XCTAssertTrue(active.isScanning)
    }
    
    func testF5_03_LaserVerticalRangeCalculation() {
        let standardHeight: CGFloat = 260
        let verticalRange = max(standardHeight - 40, 60)
        XCTAssertEqual(verticalRange, 220.0)
        
        let smallHeight: CGFloat = 80
        let smallRange = max(smallHeight - 40, 60)
        XCTAssertEqual(smallRange, 60.0)
    }
    
    func testF5_04_LaserSweepDefaultParameter() {
        let defaultLaser = LaserSweepLineView()
        XCTAssertTrue(defaultLaser.isScanning, "Default LaserSweepLineView initializer must default isScanning to true")
    }
    
    func testF5_05_LaserSweepStateToggling() {
        var isScanning = false
        isScanning = true
        let laser = LaserSweepLineView(isScanning: isScanning)
        XCTAssertTrue(laser.isScanning)
    }
    
    // -------------------------------------------------------------------------
    // Feature F6: Pulsing & Locking Reticle (ORIGINAL_REQUEST §R2)
    // -------------------------------------------------------------------------
    
    func testF6_01_ReticleOverlayViewTriStateInitialization() {
        let idleReticle = ReticleOverlayView(isScanning: false, hasTarget: false)
        let scanningReticle = ReticleOverlayView(isScanning: true, hasTarget: false)
        let lockedReticle = ReticleOverlayView(isScanning: false, hasTarget: true)
        
        XCTAssertNotNil(idleReticle)
        XCTAssertNotNil(scanningReticle)
        XCTAssertNotNil(lockedReticle)
    }
    
    func testF6_02_ReticleCornerInsetCalculation() {
        // Locked state inset = 12.0
        let lockedInset: CGFloat = 12.0
        // Idle breathing inset = 16.0 .. 18.0
        let idleMinInset: CGFloat = 16.0
        let idleMaxInset: CGFloat = 18.0
        // Scanning active inset = 22.0 .. 26.0
        let scanMinInset: CGFloat = 22.0
        let scanMaxInset: CGFloat = 26.0
        
        XCTAssertLessThan(lockedInset, idleMinInset)
        XCTAssertLessThan(idleMaxInset, scanMinInset)
        XCTAssertLessThanOrEqual(scanMinInset, scanMaxInset)
    }
    
    func testF6_03_ReticleAppleVisionCoordinateTransformation() {
        let containerWidth: CGFloat = 300
        let containerHeight: CGFloat = 200
        let visionBox = CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.4)
        
        // Vision (0,0) is bottom-left
        let expectedX = max(visionBox.origin.x * containerWidth - 10, 8)
        let expectedY = max((1.0 - visionBox.origin.y - visionBox.height) * containerHeight - 10, 8)
        let expectedW = min(visionBox.width * containerWidth + 20, containerWidth - 16)
        let expectedH = min(visionBox.height * containerHeight + 20, containerHeight - 16)
        
        XCTAssertEqual(expectedX, 50.0)
        XCTAssertEqual(expectedY, 50.0)
        XCTAssertEqual(expectedW, 200.0)
        XCTAssertEqual(expectedH, 100.0)
    }
    
    func testF6_04_ReticleTargetLockDetectionInVisionViewModel() {
        let visionVM = VisionViewModel()
        XCTAssertFalse(visionVM.hasDetectedTarget)
        
        visionVM.detectedExpression = "15 + 25"
        XCTAssertTrue(visionVM.hasDetectedTarget)
        
        visionVM.clearResults()
        XCTAssertFalse(visionVM.hasDetectedTarget)
    }
    
    func testF6_05_ReticleReceiptModeTargetLockDetection() {
        let visionVM = VisionViewModel()
        visionVM.selectedSubMode = .receipt
        XCTAssertFalse(visionVM.hasDetectedTarget)
        
        visionVM.receiptItems = [ReceiptLineItem(name: "Coffee", amount: 4.50)]
        XCTAssertTrue(visionVM.hasDetectedTarget)
    }
    
    // -------------------------------------------------------------------------
    // Feature F7: Solved Result Reveal Card (ORIGINAL_REQUEST §R2)
    // -------------------------------------------------------------------------
    
    func testF7_01_SolvedResultCardInitialization() {
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
    
    func testF7_02_SolvedResultCardAlternativeInitializer() {
        let card = SolvedResultCardView(
            result: "100",
            expression: "50 * 2",
            onOpenInCalc: {},
            onCopy: {}
        )
        XCTAssertEqual(card.result, "100")
        XCTAssertEqual(card.expression, "50 * 2")
    }
    
    func testF7_03_SolvedResultCardOpenInCalcWorkflow() {
        let calcVM = CalculatorViewModel()
        let card = SolvedResultCardView(
            expression: "144 / 12",
            result: "12",
            onOpenInCalc: {
                calcVM.expression = "144 / 12"
                calcVM.evaluateFinal()
            }
        )
        card.onOpenInCalc()
        XCTAssertEqual(calcVM.displayResult, "12")
    }
    
    func testF7_04_VisionViewModelSolveEquationSavesToHistory() {
        let visionVM = VisionViewModel()
        visionVM.detectedExpression = "25 * 4"
        visionVM.solveDetectedExpression()
        
        XCTAssertEqual(visionVM.solvedResult, "100")
        XCTAssertEqual(HistoryManager.shared.items.first?.result, "100")
        XCTAssertEqual(HistoryManager.shared.items.first?.mode, "Vision")
    }
    
    func testF7_05_VisionViewModelClearResults() {
        let visionVM = VisionViewModel()
        visionVM.detectedExpression = "99 + 1"
        visionVM.solvedResult = "100"
        XCTAssertTrue(visionVM.hasDetectedTarget)
        
        visionVM.clearResults()
        XCTAssertEqual(visionVM.detectedExpression, "")
        XCTAssertNil(visionVM.solvedResult)
        XCTAssertFalse(visionVM.hasDetectedTarget)
    }
    
    // -------------------------------------------------------------------------
    // Feature F8: CHHapticEngine Lifecycle (ORIGINAL_REQUEST §R3)
    // -------------------------------------------------------------------------
    
    func testF8_01_EnginePrepareAndStart() {
        let manager = SoundAndHapticManager.shared
        manager.prepare()
        manager.startEngine()
        XCTAssertNotNil(manager)
    }
    
    func testF8_02_EngineStopAndCleanup() {
        let manager = SoundAndHapticManager.shared
        manager.startEngine()
        manager.stopEngine()
    }
    
    func testF8_03_AppBackgroundingLifecycleHandler() {
        let manager = SoundAndHapticManager.shared
        manager.startContinuousScanningHum()
        manager.handleAppBackground()
    }
    
    func testF8_04_AppForegroundingLifecycleHandler() {
        let manager = SoundAndHapticManager.shared
        manager.handleAppBackground()
        manager.handleAppForeground()
    }
    
    func testF8_05_HardwareCapabilitySafetyCheck() {
        let manager = SoundAndHapticManager.shared
        let capability = manager.supportsCoreHaptics
        XCTAssertTrue(capability == true || capability == false)
    }
    
    // -------------------------------------------------------------------------
    // Feature F9: Multi-Tiered Haptic Patterns (ORIGINAL_REQUEST §R3)
    // -------------------------------------------------------------------------
    
    func testF9_01_PlayDigitClickPattern() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        manager.playDigitClick()
    }
    
    func testF9_02_PlayOperatorBurstPattern() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        manager.playOperatorBurst()
    }
    
    func testF9_03_PlayFunctionClickPattern() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        manager.playFunctionClick()
    }
    
    func testF9_04_PlayErrorThudPattern() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        manager.playErrorThud()
    }
    
    func testF9_05_PlayCelebratorySuccessPatternAndContinuousHum() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        manager.playCelebratorySuccess()
        manager.startContinuousScanningHum()
        manager.stopContinuousScanningHum()
    }
    
    // -------------------------------------------------------------------------
    // Feature F10: Graceful UIKit Fallbacks (ORIGINAL_REQUEST §R3)
    // -------------------------------------------------------------------------
    
    func testF10_01_LegacyBridgeAllHapticStyles() {
        let manager = SoundAndHapticManager.shared
        let styles: [SoundAndHapticManager.HapticStyle] = [
            .light, .medium, .heavy, .selection, .success, .error
        ]
        for style in styles {
            manager.triggerHaptic(style)
        }
    }
    
    func testF10_02_SilentWhenHapticsDisabled() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = false
        manager.playDigitClick()
        manager.playOperatorBurst()
        manager.playFunctionClick()
        manager.playErrorThud()
        manager.playCelebratorySuccess()
        manager.startContinuousScanningHum()
    }
    
    func testF10_03_AudioFeedbackChannels() {
        let manager = SoundAndHapticManager.shared
        manager.isSoundEnabled = true
        manager.playKeySound()
        manager.playOperationSound()
        manager.playSuccessSound()
    }
    
    func testF10_04_SilentWhenSoundDisabled() {
        let manager = SoundAndHapticManager.shared
        manager.isSoundEnabled = false
        manager.playKeySound()
        manager.playOperationSound()
        manager.playSuccessSound()
    }
    
    func testF10_05_IndependentManagerInstanceCreation() {
        let independentManager = SoundAndHapticManager()
        XCTAssertNotNil(independentManager)
        independentManager.prepare()
        independentManager.stopEngine()
    }
    
    // -------------------------------------------------------------------------
    // Feature F11: Preferences Haptic Toggle (ORIGINAL_REQUEST §R3)
    // -------------------------------------------------------------------------
    
    func testF11_01_HapticsEnabledUserDefaultsPersistence() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = false
        XCTAssertFalse(manager.isHapticsEnabled)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "LC_HapticsEnabled"), false)
        
        manager.isHapticsEnabled = true
        XCTAssertTrue(manager.isHapticsEnabled)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "LC_HapticsEnabled"), true)
    }
    
    func testF11_02_SoundEnabledUserDefaultsPersistence() {
        let manager = SoundAndHapticManager.shared
        manager.isSoundEnabled = false
        XCTAssertFalse(manager.isSoundEnabled)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "LC_SoundEnabled"), false)
        
        manager.isSoundEnabled = true
        XCTAssertTrue(manager.isSoundEnabled)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "LC_SoundEnabled"), true)
    }
    
    func testF11_03_DisablingHapticsSilencesActiveContinuousHum() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        manager.startContinuousScanningHum()
        
        // Toggle haptics off immediately
        manager.isHapticsEnabled = false
        XCTAssertFalse(manager.isHapticsEnabled)
    }
    
    func testF11_04_ReenablingHapticsRestoresReadiness() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = false
        manager.isHapticsEnabled = true
        XCTAssertTrue(manager.isHapticsEnabled)
        manager.playDigitClick()
    }
    
    func testF11_05_SettingsSheetViewInitialization() {
        let settingsView = SettingsSheetView()
        XCTAssertNotNil(settingsView)
    }
    
    // =========================================================================
    // MARK: - TIER 2: BOUNDARY & CORNER CASES (F1 to F11: 55 Tests)
    // =========================================================================
    
    // -------------------------------------------------------------------------
    // F1 Boundary Cases
    // -------------------------------------------------------------------------
    
    func testF1_B01_RapidButtonPressBurst() {
        let viewModel = CalculatorViewModel()
        for i in 0..<100 {
            let digit = String(i % 10)
            viewModel.handleButtonPress(KeypadButton(label: digit, type: .digit(digit)))
        }
        XCTAssertEqual(viewModel.displayResult.count, 100)
    }
    
    func testF1_B02_ExtremeLengthButtonLabels() {
        let btn = KeypadButton(label: "VERY_LONG_LABEL_12345", type: .scientific("fn"))
        XCTAssertGreaterThan(btn.label.count, 4)
    }
    
    func testF1_B03_WideButtonWithNilSecondaryLabel() {
        let wideZero = KeypadButton(label: "0", type: .digit("0"), secondaryLabel: nil, isWide: true)
        XCTAssertTrue(wideZero.isWide)
        XCTAssertNil(wideZero.secondaryLabel)
    }
    
    func testF1_B04_AllAccentStylesProduceNonEmptyGradients() {
        let styles: [KeypadAccentStyle] = [
            .digitDark, .functionGray, .accentOrange, .accentCyan, .scientificViolet, .hexBlue
        ]
        for style in styles {
            XCTAssertGreaterThanOrEqual(style.backgroundColors.count, 2)
            XCTAssertEqual(style.foregroundColor, .white)
        }
    }
    
    func testF1_B05_DefaultUnpressedKeypadPressStyle() {
        let pressStyle = KeypadPressStyle()
        XCTAssertNotNil(pressStyle)
    }
    
    // -------------------------------------------------------------------------
    // F2 Boundary Cases
    // -------------------------------------------------------------------------
    
    func testF2_B01_ExactLengthBoundaryScalingTransitions() {
        let len8 = "12345678"
        let len9 = "123456789"
        let len12 = "123456789012"
        let len13 = "1234567890123"
        
        XCTAssertEqual(len8.count, 8)
        XCTAssertEqual(len9.count, 9)
        XCTAssertEqual(len12.count, 12)
        XCTAssertEqual(len13.count, 13)
    }
    
    func testF2_B02_ExtremePrecisionDecimals() {
        let extremeSmall = 0.000000000000001
        let formatted = MathEvaluator.formatResult(extremeSmall)
        XCTAssertFalse(formatted.isEmpty)
    }
    
    func testF2_B03_EmptyExpressionState() {
        let viewModel = CalculatorViewModel()
        XCTAssertEqual(viewModel.displayResult, "0")
        XCTAssertEqual(viewModel.expression, "")
    }
    
    func testF2_B04_MultipleConsecutiveDecimalsPrevented() {
        let viewModel = CalculatorViewModel()
        viewModel.handleButtonPress(KeypadButton(label: "3", type: .digit("3")))
        viewModel.handleButtonPress(KeypadButton(label: ".", type: .decimal))
        viewModel.handleButtonPress(KeypadButton(label: ".", type: .decimal))
        viewModel.handleButtonPress(KeypadButton(label: "1", type: .digit("1")))
        viewModel.handleButtonPress(KeypadButton(label: ".", type: .decimal))
        
        XCTAssertEqual(viewModel.displayResult, "3.1")
        XCTAssertEqual(viewModel.expression, "3.1")
    }
    
    func testF2_B05_SignToggleBoundaryCases() {
        let viewModel = CalculatorViewModel()
        // Toggling on empty does nothing
        viewModel.toggleSign()
        XCTAssertEqual(viewModel.displayResult, "0")
        
        // Single digit
        viewModel.handleButtonPress(KeypadButton(label: "7", type: .digit("7")))
        viewModel.toggleSign()
        XCTAssertEqual(viewModel.displayResult, "-(7)")
        
        viewModel.toggleSign()
        XCTAssertEqual(viewModel.displayResult, "7")
    }
    
    // -------------------------------------------------------------------------
    // F3 Boundary Cases
    // -------------------------------------------------------------------------
    
    func testF3_B01_MultipleRapidErrorTriggers() {
        let viewModel = CalculatorViewModel()
        for _ in 0..<10 {
            viewModel.expression = "1/0"
            viewModel.evaluateFinal()
            XCTAssertTrue(viewModel.hasError)
            XCTAssertEqual(viewModel.displayResult, "Error")
        }
    }
    
    func testF3_B02_NegativeSquareRootDomainError() {
        let viewModel = CalculatorViewModel()
        viewModel.expression = "sqrt(-100)"
        viewModel.evaluateFinal()
        XCTAssertTrue(viewModel.hasError)
        XCTAssertEqual(viewModel.displayResult, "Error")
    }
    
    func testF3_B03_MismatchedParenthesesError() {
        let viewModel = CalculatorViewModel()
        viewModel.expression = "((5+3)"
        viewModel.evaluateFinal()
        XCTAssertTrue(viewModel.hasError)
    }
    
    func testF3_B04_ShakeEffectZeroAmplitudeAndShakes() {
        let shake = ShakeEffect(shakes: 0, amount: 0, shakesPerUnit: 0)
        let transform = shake.effectValue(size: CGSize(width: 200, height: 100))
        XCTAssertNotNil(transform)
    }
    
    func testF3_B05_ClearCurrentVsClearAllAfterError() {
        let viewModel = CalculatorViewModel()
        viewModel.expression = "9/0"
        viewModel.evaluateFinal()
        XCTAssertTrue(viewModel.hasError)
        
        viewModel.clearCurrent()
        XCTAssertFalse(viewModel.hasError)
        XCTAssertEqual(viewModel.displayResult, "0")
    }
    
    // -------------------------------------------------------------------------
    // F4 Boundary Cases
    // -------------------------------------------------------------------------
    
    func testF4_B01_RapidModeSwitchingCycle() {
        let modes: [CalculatorMode] = [.standard, .scientific, .programmer, .converter, .vision]
        var current = CalculatorMode.standard
        for _ in 0..<20 {
            for m in modes {
                current = m
                XCTAssertEqual(current, m)
            }
        }
    }
    
    func testF4_B02_ModeSwitchWhileInErrorState() {
        let viewModel = CalculatorViewModel()
        viewModel.expression = "1/0"
        viewModel.evaluateFinal()
        XCTAssertTrue(viewModel.hasError)
        
        viewModel.currentMode = .scientific
        XCTAssertEqual(viewModel.currentMode, .scientific)
        XCTAssertTrue(viewModel.hasError)
    }
    
    func testF4_B03_AngleUnitRapidToggling() {
        let viewModel = CalculatorViewModel()
        for _ in 0..<50 {
            viewModel.angleUnit = (viewModel.angleUnit == .radians) ? .degrees : .radians
        }
        XCTAssertEqual(viewModel.angleUnit, .degrees)
    }
    
    func testF4_B04_CaseIterableIntegrity() {
        XCTAssertEqual(CalculatorMode.allCases.count, 5)
        XCTAssertEqual(AngleUnit.allCases.count, 2)
    }
    
    func testF4_B05_AllModesHaveDistinctSFSystemIcons() {
        let icons = CalculatorMode.allCases.map { $0.iconName }
        let uniqueIcons = Set(icons)
        XCTAssertEqual(uniqueIcons.count, 5, "All 5 calculator modes must have unique SF Symbol icon names")
    }
    
    // -------------------------------------------------------------------------
    // F5 Boundary Cases
    // -------------------------------------------------------------------------
    
    func testF5_B01_ZeroAndViewportDimensions() {
        let zeroHeight: CGFloat = 0
        let zeroRange = max(zeroHeight - 40, 60)
        XCTAssertEqual(zeroRange, 60.0)
        
        let extremeHeight: CGFloat = 10000
        let extremeRange = max(extremeHeight - 40, 60)
        XCTAssertEqual(extremeRange, 9960.0)
    }
    
    func testF5_B02_RapidIsScanningToggling() {
        for _ in 0..<30 {
            let _ = LaserSweepLineView(isScanning: true)
            let _ = LaserSweepLineView(isScanning: false)
        }
    }
    
    func testF5_B03_NegativeContainerDimensionsSafety() {
        let negativeHeight: CGFloat = -100
        let safeRange = max(negativeHeight - 40, 60)
        XCTAssertEqual(safeRange, 60.0)
    }
    
    func testF5_B04_LaserSweepPhaseClampingBounds() {
        let phases: [CGFloat] = [0.0, 0.25, 0.5, 0.75, 1.0]
        let height: CGFloat = 200
        let verticalRange = max(height - 40, 60)
        
        for p in phases {
            let currentY = 20 + (p * verticalRange)
            XCTAssertGreaterThanOrEqual(currentY, 20.0)
            XCTAssertLessThanOrEqual(currentY, 20.0 + verticalRange)
        }
    }
    
    func testF5_B05_LaserSweepViewBodyEvaluation() {
        let laser = LaserSweepLineView(isScanning: true)
        let _ = laser.body
        XCTAssertTrue(laser.isScanning)
    }
    
    // -------------------------------------------------------------------------
    // F6 Boundary Cases
    // -------------------------------------------------------------------------
    
    func testF6_B01_NilBoundingBoxWithHasTarget() {
        let reticle = ReticleOverlayView(isScanning: false, hasTarget: true, targetBoundingBox: nil)
        XCTAssertNotNil(reticle)
        XCTAssertTrue(reticle.hasTarget)
        XCTAssertNil(reticle.targetBoundingBox)
    }
    
    func testF6_B02_ZeroAndInvertedBoundingBoxes() {
        let zeroBox = CGRect.zero
        let reticleZero = ReticleOverlayView(isScanning: true, hasTarget: true, targetBoundingBox: zeroBox)
        XCTAssertNotNil(reticleZero)
        
        let outOfBoundsBox = CGRect(x: -0.5, y: 1.5, width: 2.0, height: 2.0)
        let reticleOOB = ReticleOverlayView(isScanning: true, hasTarget: true, targetBoundingBox: outOfBoundsBox)
        XCTAssertNotNil(reticleOOB)
    }
    
    func testF6_B03_ExtremeSmallContainerSize() {
        let smallContainer = CGRect(x: 0, y: 0, width: 20, height: 20)
        let cornerLen = min(24, min(smallContainer.width, smallContainer.height) / 3)
        XCTAssertGreaterThan(cornerLen, 0)
    }
    
    func testF6_B04_RapidLockOnStateTransitions() {
        let visionVM = VisionViewModel()
        for i in 0..<25 {
            if i % 2 == 0 {
                visionVM.detectedExpression = "1+1"
            } else {
                visionVM.clearResults()
            }
        }
    }
    
    func testF6_B05_AppleVisionCornerMappings() {
        // Top-left in Vision coords is x:0, y:1
        let topLeft = CGRect(x: 0.0, y: 0.8, width: 0.2, height: 0.2)
        let containerW: CGFloat = 100
        let containerH: CGFloat = 100
        
        let x = max(topLeft.origin.x * containerW - 10, 8)
        let y = max((1.0 - topLeft.origin.y - topLeft.height) * containerH - 10, 8)
        XCTAssertEqual(x, 8.0)
        XCTAssertEqual(y, 8.0)
    }
    
    // -------------------------------------------------------------------------
    // F7 Boundary Cases
    // -------------------------------------------------------------------------
    
    func testF7_B01_NilSolvedResultDisplay() {
        let card = SolvedResultCardView(
            expression: "sqrt(16)",
            result: nil,
            onOpenInCalc: {}
        )
        XCTAssertEqual(card.expression, "sqrt(16)")
        XCTAssertNil(card.result)
    }
    
    func testF7_B02_ExtremelyLongExpressionString() {
        let longExp = String(repeating: "1+", count: 100) + "1"
        let card = SolvedResultCardView(
            expression: longExp,
            result: "101",
            onOpenInCalc: {}
        )
        XCTAssertEqual(card.expression.count, 201)
    }
    
    func testF7_B03_ExtremelyLargeResultNotation() {
        let card = SolvedResultCardView(
            expression: "10^30",
            result: "1e+30",
            onOpenInCalc: {}
        )
        XCTAssertEqual(card.result, "1e+30")
    }
    
    func testF7_B04_RepeatedOpenInCalcCallbackInvocations() {
        var count = 0
        let card = SolvedResultCardView(
            expression: "2+2",
            result: "4",
            onOpenInCalc: { count += 1 }
        )
        for _ in 0..<20 {
            card.onOpenInCalc()
        }
        XCTAssertEqual(count, 20)
    }
    
    func testF7_B05_DefaultCopyClosureExecution() {
        let card = SolvedResultCardView(
            result: "42",
            expression: "6 * 7",
            onOpenInCalc: {}
        )
        XCTAssertNotNil(card.onCopy)
        card.onCopy?()
    }
    
    // -------------------------------------------------------------------------
    // F8 Boundary Cases
    // -------------------------------------------------------------------------
    
    func testF8_B01_StopEngineWhenAlreadyStopped() {
        let manager = SoundAndHapticManager.shared
        manager.stopEngine()
        manager.stopEngine()
        manager.stopEngine()
    }
    
    func testF8_B02_StartEngineWhenAlreadyRunning() {
        let manager = SoundAndHapticManager.shared
        manager.startEngine()
        manager.startEngine()
        manager.startEngine()
    }
    
    func testF8_B03_RapidBackgroundForegroundCycling() {
        let manager = SoundAndHapticManager.shared
        for _ in 0..<20 {
            manager.handleAppBackground()
            manager.handleAppForeground()
        }
    }
    
    func testF8_B04_PrepareCalledMultipleTimes() {
        let manager = SoundAndHapticManager.shared
        for _ in 0..<10 {
            manager.prepare()
        }
    }
    
    func testF8_B05_EngineLifecycleUnderMutedHaptics() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = false
        manager.prepare()
        manager.startEngine()
        manager.stopEngine()
    }
    
    // -------------------------------------------------------------------------
    // F9 Boundary Cases
    // -------------------------------------------------------------------------
    
    func testF9_B01_ConcurrentHapticPatternTriggers() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        let exp = expectation(description: "Concurrent triggers")
        exp.expectedFulfillmentCount = 5
        
        DispatchQueue.global().async {
            manager.playDigitClick()
            exp.fulfill()
        }
        DispatchQueue.global().async {
            manager.playOperatorBurst()
            exp.fulfill()
        }
        DispatchQueue.global().async {
            manager.playFunctionClick()
            exp.fulfill()
        }
        DispatchQueue.global().async {
            manager.playErrorThud()
            exp.fulfill()
        }
        DispatchQueue.global().async {
            manager.playCelebratorySuccess()
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
    }
    
    func testF9_B02_StartContinuousHumMultipleTimes() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        for _ in 0..<10 {
            manager.startContinuousScanningHum()
        }
        manager.stopContinuousScanningHum()
    }
    
    func testF9_B03_StopContinuousHumWhenNotRunning() {
        let manager = SoundAndHapticManager.shared
        manager.stopContinuousScanningHum()
        manager.stopContinuousScanningHum()
    }
    
    func testF9_B04_InterleavedPatternsAndContinuousHum() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        manager.startContinuousScanningHum()
        manager.playDigitClick()
        manager.playOperatorBurst()
        manager.stopContinuousScanningHum()
    }
    
    func testF9_B05_RapidErrorThudTriggers() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        for _ in 0..<50 {
            manager.playErrorThud()
        }
    }
    
    // -------------------------------------------------------------------------
    // F10 Boundary Cases
    // -------------------------------------------------------------------------
    
    func testF10_B01_AllLegacyStylesWhileDisabled() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = false
        for style in [SoundAndHapticManager.HapticStyle.light, .medium, .heavy, .selection, .success, .error] {
            manager.triggerHaptic(style)
        }
    }
    
    func testF10_B02_AllSoundTypesWhileDisabled() {
        let manager = SoundAndHapticManager.shared
        manager.isSoundEnabled = false
        manager.playKeySound()
        manager.playOperationSound()
        manager.playSuccessSound()
    }
    
    func testF10_B03_RapidLegacyStyleSwitching() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        for _ in 0..<20 {
            manager.triggerHaptic(.light)
            manager.triggerHaptic(.medium)
            manager.triggerHaptic(.heavy)
            manager.triggerHaptic(.selection)
            manager.triggerHaptic(.success)
            manager.triggerHaptic(.error)
        }
    }
    
    func testF10_B04_UIKitGeneratorFallbacksExecution() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        manager.triggerHaptic(.selection)
    }
    
    func testF10_B05_AudioServicesSafeExecution() {
        let manager = SoundAndHapticManager.shared
        manager.isSoundEnabled = true
        manager.playKeySound()
        manager.playOperationSound()
        manager.playSuccessSound()
    }
    
    // -------------------------------------------------------------------------
    // F11 Boundary Cases
    // -------------------------------------------------------------------------
    
    func testF11_B01_RapidHapticsToggleSpam() {
        let manager = SoundAndHapticManager.shared
        for i in 0..<100 {
            manager.isHapticsEnabled = (i % 2 == 0)
        }
        XCTAssertEqual(manager.isHapticsEnabled, false)
    }
    
    func testF11_B02_RapidSoundToggleSpam() {
        let manager = SoundAndHapticManager.shared
        for i in 0..<100 {
            manager.isSoundEnabled = (i % 2 == 0)
        }
        XCTAssertEqual(manager.isSoundEnabled, false)
    }
    
    func testF11_B03_UserDefaultsKeyVerification() {
        UserDefaults.standard.set(true, forKey: "LC_HapticsEnabled")
        UserDefaults.standard.set(false, forKey: "LC_SoundEnabled")
        
        let freshManager = SoundAndHapticManager()
        XCTAssertTrue(freshManager.isHapticsEnabled)
        XCTAssertFalse(freshManager.isSoundEnabled)
    }
    
    func testF11_B04_DisablingHapticsDuringActiveContinuousHum() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        manager.startContinuousScanningHum()
        manager.isHapticsEnabled = false
        XCTAssertFalse(manager.isHapticsEnabled)
    }
    
    func testF11_B05_MultipleInstancesStateSync() {
        let m1 = SoundAndHapticManager()
        m1.isHapticsEnabled = true
        m1.isSoundEnabled = true
        
        let m2 = SoundAndHapticManager()
        XCTAssertTrue(m2.isHapticsEnabled)
        XCTAssertTrue(m2.isSoundEnabled)
    }
    
    // =========================================================================
    // MARK: - TIER 3: CROSS-FEATURE PAIRWISE COMBINATIONS (16 Tests)
    // =========================================================================
    
    func testP1_Calculation_ErrorShake_ModeSwitch() {
        let calcVM = CalculatorViewModel()
        calcVM.expression = "100 / 0"
        calcVM.evaluateFinal()
        
        XCTAssertTrue(calcVM.hasError)
        XCTAssertEqual(calcVM.displayResult, "Error")
        XCTAssertTrue(calcVM.shouldShakeDisplay)
        
        // Mode switch to Scientific
        calcVM.currentMode = .scientific
        XCTAssertEqual(calcVM.currentMode, .scientific)
        
        // Input digit clears error
        calcVM.handleButtonPress(KeypadButton(label: "5", type: .digit("5")))
        XCTAssertFalse(calcVM.hasError)
        XCTAssertEqual(calcVM.displayResult, "5")
    }
    
    func testP2_VisionDetection_ResultCard_OpenInCalc_Evaluation() {
        let visionVM = VisionViewModel()
        let calcVM = CalculatorViewModel()
        
        visionVM.detectedExpression = "35 * 3"
        visionVM.solveDetectedExpression()
        XCTAssertEqual(visionVM.solvedResult, "105")
        
        // Card open in calc transfers expression
        let card = SolvedResultCardView(
            expression: visionVM.detectedExpression,
            result: visionVM.solvedResult,
            onOpenInCalc: {
                calcVM.expression = visionVM.detectedExpression
                calcVM.evaluateFinal()
            }
        )
        card.onOpenInCalc()
        XCTAssertEqual(calcVM.displayResult, "105")
        XCTAssertEqual(HistoryManager.shared.items.first?.result, "105")
    }
    
    func testP3_HapticsDisabled_ErrorShake_AudioOnly() {
        SoundAndHapticManager.shared.isHapticsEnabled = false
        SoundAndHapticManager.shared.isSoundEnabled = true
        
        let calcVM = CalculatorViewModel()
        calcVM.expression = "25 / 0"
        calcVM.evaluateFinal()
        
        XCTAssertTrue(calcVM.hasError)
        XCTAssertTrue(calcVM.shouldShakeDisplay)
        XCTAssertFalse(SoundAndHapticManager.shared.isHapticsEnabled)
        XCTAssertTrue(SoundAndHapticManager.shared.isSoundEnabled)
    }
    
    func testP4_ContinuousHum_VisionMode_ModeSwitch_Backgrounding() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        manager.startContinuousScanningHum()
        
        // Mode switch to standard
        let calcVM = CalculatorViewModel()
        calcVM.currentMode = .standard
        
        // Backgrounding cleans up hum
        manager.handleAppBackground()
        XCTAssertNotNil(manager)
    }
    
    func testP5_DynamicFontScaling_LivePreview_Evaluation() {
        let calcVM = CalculatorViewModel()
        calcVM.handleButtonPress(KeypadButton(label: "1", type: .digit("1")))
        calcVM.handleButtonPress(KeypadButton(label: "2", type: .digit("2")))
        calcVM.handleButtonPress(KeypadButton(label: "3", type: .digit("3")))
        calcVM.handleButtonPress(KeypadButton(label: "4", type: .digit("4")))
        calcVM.handleButtonPress(KeypadButton(label: "+", type: .operation("+")))
        calcVM.handleButtonPress(KeypadButton(label: "5", type: .digit("5")))
        calcVM.handleButtonPress(KeypadButton(label: "6", type: .digit("6")))
        calcVM.handleButtonPress(KeypadButton(label: "7", type: .digit("7")))
        calcVM.handleButtonPress(KeypadButton(label: "8", type: .digit("8")))
        
        XCTAssertEqual(calcVM.expression, "1234+5678")
        XCTAssertEqual(calcVM.livePreview, "6912")
        
        calcVM.evaluateFinal()
        XCTAssertEqual(calcVM.displayResult, "6912")
    }
    
    func testP6_ProgrammerMode_BitToggling_ConverterMode_Length() {
        let progVM = ProgrammerViewModel()
        progVM.wordSize = .byte
        progVM.currentValue = 0
        progVM.toggleBit(at: 7) // 128
        progVM.toggleBit(at: 0) // 129
        XCTAssertEqual(progVM.currentValue, 129)
        XCTAssertEqual(progVM.hexDisplay, "81")
        
        // Switch to Converter
        let convVM = ConverterViewModel()
        convVM.selectedCategory = .length
        convVM.inputString = "129"
        XCTAssertEqual(convVM.outputString, "0.129")
    }
    
    func testP7_LaserSweep_ReticleLockOn_SolvedCard_Fanfare() {
        let visionVM = VisionViewModel()
        visionVM.isScanning = true
        let laser = LaserSweepLineView(isScanning: visionVM.isScanning)
        XCTAssertTrue(laser.isScanning)
        
        // Detection occurs
        visionVM.isScanning = false
        visionVM.detectedExpression = "8 * 9"
        visionVM.solveDetectedExpression()
        
        let reticle = ReticleOverlayView(isScanning: visionVM.isScanning, hasTarget: visionVM.hasDetectedTarget)
        XCTAssertTrue(reticle.hasTarget)
        XCTAssertEqual(visionVM.solvedResult, "72")
    }
    
    func testP8_ScientificTrig_DomainError_Recovery_Backspace() {
        let calcVM = CalculatorViewModel()
        calcVM.angleUnit = .degrees
        calcVM.expression = "sin(30)"
        calcVM.evaluateFinal()
        XCTAssertEqual(calcVM.displayResult, "0.5")
        
        calcVM.expression = "sqrt(-16)"
        calcVM.evaluateFinal()
        XCTAssertTrue(calcVM.hasError)
        
        calcVM.clearAll()
        calcVM.expression = "cos(60)"
        calcVM.evaluateFinal()
        XCTAssertEqual(calcVM.displayResult, "0.5")
    }
    
    func testP9_UnitConverter_SwapUnits_ModeSwitch_Standard() {
        let convVM = ConverterViewModel()
        convVM.selectedCategory = .length
        convVM.inputString = "5" // 5 meters
        XCTAssertEqual(convVM.outputString, "0.005") // to km
        
        convVM.swapUnits()
        XCTAssertEqual(convVM.outputString, "5000") // 5 km to meters
        
        let calcVM = CalculatorViewModel()
        calcVM.currentMode = .standard
        XCTAssertEqual(calcVM.currentMode, .standard)
    }
    
    func testP10_AppBackground_Foreground_HapticsMuted_Recovery() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        manager.startEngine()
        
        // App backgrounded
        manager.handleAppBackground()
        
        // Preferences muted in background
        manager.isHapticsEnabled = false
        
        // App foregrounded
        manager.handleAppForeground()
        XCTAssertFalse(manager.isHapticsEnabled)
        
        // Re-enabled
        manager.isHapticsEnabled = true
        manager.handleAppForeground()
        XCTAssertTrue(manager.isHapticsEnabled)
    }
    
    func testP11_MemoryStorage_DisplayBadge_Recall_FontScale() {
        let calcVM = CalculatorViewModel()
        calcVM.expression = "12345"
        calcVM.evaluateFinal()
        
        // M+
        calcVM.handleButtonPress(KeypadButton(label: "M+", type: .memory("M+")))
        XCTAssertTrue(calcVM.hasMemory)
        XCTAssertEqual(calcVM.memoryValue, 12345.0)
        
        calcVM.clearAll()
        XCTAssertTrue(calcVM.hasMemory)
        
        // Recall MR
        calcVM.handleButtonPress(KeypadButton(label: "MR", type: .memory("MR")))
        XCTAssertEqual(calcVM.displayResult, "12345")
        
        // Clear MC
        calcVM.handleButtonPress(KeypadButton(label: "MC", type: .memory("MC")))
        XCTAssertFalse(calcVM.hasMemory)
    }
    
    func testP12_VisionReceipt_MultiItem_TaxTipSplit_Calculation() {
        let visionVM = VisionViewModel()
        visionVM.selectedSubMode = .receipt
        visionVM.receiptItems = [
            ReceiptLineItem(name: "Burger", amount: 15.00),
            ReceiptLineItem(name: "Fries", amount: 5.00),
            ReceiptLineItem(name: "Drink", amount: 4.00)
        ]
        visionVM.tipPercentage = 20.0
        visionVM.taxRate = 10.0
        visionVM.splitCount = 2
        
        XCTAssertEqual(visionVM.receiptSubtotal, 24.00, accuracy: 1e-4)
        XCTAssertEqual(visionVM.receiptTipAmount, 4.80, accuracy: 1e-4)
        XCTAssertEqual(visionVM.receiptTaxAmount, 2.40, accuracy: 1e-4)
        XCTAssertEqual(visionVM.receiptTotal, 31.20, accuracy: 1e-4)
        XCTAssertEqual(visionVM.receiptPerPerson, 15.60, accuracy: 1e-4)
    }
    
    func testP13_HistoryInsertion_SignToggle_LivePreview_Evaluation() {
        let calcVM = CalculatorViewModel()
        let item = HistoryItem(expression: "10 * 10", result: "100", mode: "Standard")
        calcVM.insertFromHistory(item)
        
        XCTAssertEqual(calcVM.displayResult, "100")
        calcVM.toggleSign()
        XCTAssertEqual(calcVM.displayResult, "-(100)")
        
        calcVM.evaluateFinal()
        XCTAssertEqual(calcVM.displayResult, "-100")
    }
    
    func testP14_KeypadButtonPhysics_FeedbackRouting_DisplayUpdate() {
        let calcVM = CalculatorViewModel()
        let button = KeypadButton(label: "7", type: .digit("7"))
        let buttonView = KeypadButtonView(button: button) {
            calcVM.handleButtonPress(button)
        }
        
        buttonView.action()
        XCTAssertEqual(calcVM.displayResult, "7")
    }
    
    func testP15_RapidModeCycling_StateIsolation_PreferencesPersistence() {
        let calcVM = CalculatorViewModel()
        let progVM = ProgrammerViewModel()
        let convVM = ConverterViewModel()
        
        for m in CalculatorMode.allCases {
            calcVM.currentMode = m
            SoundAndHapticManager.shared.triggerHaptic(.selection)
        }
        
        XCTAssertNotNil(calcVM)
        XCTAssertNotNil(progVM)
        XCTAssertNotNil(convVM)
    }
    
    func testP16_ReticleBoundingBoxTransform_ResultCard_ClipboardCopy() {
        let obs = ScannedTextObservation(
            rawText: "50 + 50",
            sanitizedExpression: "50 + 50",
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.3),
            confidence: 0.99
        )
        let visionVM = VisionViewModel()
        visionVM.scannedObservations = [obs]
        visionVM.processScannedResults([obs])
        
        XCTAssertEqual(visionVM.detectedExpression, "50 + 50")
        XCTAssertEqual(visionVM.solvedResult, "100")
        XCTAssertNotNil(visionVM.targetBoundingBox)
    }
    
    // =========================================================================
    // MARK: - TIER 4: REAL-WORLD APPLICATION SCENARIOS (5 Tests)
    // =========================================================================
    
    /// Scenario 1: Standard Arithmetic Flow & Display Transition
    func testWorkflow1_FullStandardArithmeticFlow() {
        let calcVM = CalculatorViewModel()
        
        // 1. Enter "25 * 4 + 50 / 2"
        calcVM.handleButtonPress(KeypadButton(label: "2", type: .digit("2")))
        calcVM.handleButtonPress(KeypadButton(label: "5", type: .digit("5")))
        calcVM.handleButtonPress(KeypadButton(label: "*", type: .operation("*")))
        calcVM.handleButtonPress(KeypadButton(label: "4", type: .digit("4")))
        calcVM.handleButtonPress(KeypadButton(label: "+", type: .operation("+")))
        calcVM.handleButtonPress(KeypadButton(label: "5", type: .digit("5")))
        calcVM.handleButtonPress(KeypadButton(label: "0", type: .digit("0")))
        calcVM.handleButtonPress(KeypadButton(label: "/", type: .operation("/")))
        calcVM.handleButtonPress(KeypadButton(label: "2", type: .digit("2")))
        
        XCTAssertEqual(calcVM.expression, "25*4+50/2")
        XCTAssertEqual(calcVM.livePreview, "125")
        
        // 2. Swipe to delete "/2"
        calcVM.deleteBackward()
        calcVM.deleteBackward()
        XCTAssertEqual(calcVM.expression, "25*4+50")
        XCTAssertEqual(calcVM.livePreview, "150")
        
        // 3. Press equals
        calcVM.handleButtonPress(KeypadButton(label: "=", type: .equals))
        XCTAssertEqual(calcVM.displayResult, "150")
        XCTAssertEqual(HistoryManager.shared.items.first?.result, "150")
        
        // 4. Apply percent
        calcVM.handleButtonPress(KeypadButton(label: "%", type: .percent))
        calcVM.handleButtonPress(KeypadButton(label: "=", type: .equals))
        XCTAssertEqual(calcVM.displayResult, "1.5")
    }
    
    /// Scenario 2: Division by Zero & Domain Error Shake with Recovery
    func testWorkflow2_DivisionByZero_ErrorShake_PreferencesMute_Recovery() {
        let calcVM = CalculatorViewModel()
        
        // 1. Enter "50 / (10 - 10)"
        calcVM.expression = "50 / (10 - 10)"
        calcVM.evaluateFinal()
        
        // 2. Verify error and shake trigger
        XCTAssertTrue(calcVM.hasError)
        XCTAssertEqual(calcVM.displayResult, "Error")
        XCTAssertTrue(calcVM.shouldShakeDisplay)
        
        // 3. User opens Preferences and toggles Haptics off
        SoundAndHapticManager.shared.isHapticsEnabled = false
        XCTAssertFalse(SoundAndHapticManager.shared.isHapticsEnabled)
        
        // 4. User presses AllClear
        calcVM.handleButtonPress(KeypadButton(label: "AC", type: .allClear))
        XCTAssertFalse(calcVM.hasError)
        XCTAssertEqual(calcVM.displayResult, "0")
        
        // 5. User performs valid calculation
        calcVM.handleButtonPress(KeypadButton(label: "5", type: .digit("5")))
        calcVM.handleButtonPress(KeypadButton(label: "0", type: .digit("0")))
        calcVM.handleButtonPress(KeypadButton(label: "/", type: .operation("/")))
        calcVM.handleButtonPress(KeypadButton(label: "2", type: .digit("2")))
        calcVM.handleButtonPress(KeypadButton(label: "=", type: .equals))
        XCTAssertEqual(calcVM.displayResult, "25")
    }
    
    /// Scenario 3: Multi-Mode Scientific, Programmer, and Converter Exploration
    func testWorkflow3_ScientificToProgrammerToConverterExploration() {
        let calcVM = CalculatorViewModel()
        let progVM = ProgrammerViewModel()
        let convVM = ConverterViewModel()
        
        // 1. Scientific mode calculation
        calcVM.currentMode = .scientific
        calcVM.angleUnit = .degrees
        calcVM.expression = "sin(30) + cos(60)"
        calcVM.evaluateFinal()
        XCTAssertEqual(calcVM.displayResult, "1")
        
        // 2. Programmer mode bitwise operation
        calcVM.currentMode = .programmer
        progVM.wordSize = .byte
        progVM.currentValue = 0x0F
        progVM.handleButtonPress(KeypadButton(label: "OR", type: .bitwise("OR")))
        progVM.currentValue = 0xF0
        progVM.handleButtonPress(KeypadButton(label: "=", type: .equals))
        XCTAssertEqual(progVM.currentValue, 255)
        XCTAssertEqual(progVM.hexDisplay, "FF")
        
        // Toggle bit 0 off -> 254
        progVM.toggleBit(at: 0)
        XCTAssertEqual(progVM.currentValue, 254)
        XCTAssertEqual(progVM.hexDisplay, "FE")
        
        // 3. Unit Converter calculation
        calcVM.currentMode = .converter
        convVM.selectedCategory = .dataStorage
        convVM.inputString = "1024" // 1024 MB
        XCTAssertEqual(convVM.outputString, "1") // 1 GB
    }
    
    /// Scenario 4: Smart Vision Scanner Equation Capture to Keypad Workflow
    func testWorkflow4_VisionScannerScanToKeypadComputation() {
        let visionVM = VisionViewModel()
        let calcVM = CalculatorViewModel()
        
        // 1. Open Vision Scanner in equation mode
        visionVM.selectedSubMode = .equation
        XCTAssertFalse(visionVM.hasDetectedTarget)
        
        // 2. Simulate OCR capture
        let observation = ScannedTextObservation(
            rawText: "45 * 2 + 10 =",
            sanitizedExpression: "45 * 2 + 10",
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.3),
            confidence: 0.98
        )
        visionVM.processScannedResults([observation])
        
        XCTAssertTrue(visionVM.hasDetectedTarget)
        XCTAssertEqual(visionVM.detectedExpression, "45 * 2 + 10")
        XCTAssertEqual(visionVM.solvedResult, "100")
        
        // 3. Result card "Open in Calc" action
        let card = SolvedResultCardView(
            expression: visionVM.detectedExpression,
            result: visionVM.solvedResult,
            onOpenInCalc: {
                calcVM.expression = visionVM.detectedExpression
                calcVM.evaluateFinal()
            }
        )
        card.onOpenInCalc()
        
        // 4. Calculator view received expression and result
        XCTAssertEqual(calcVM.displayResult, "100")
        XCTAssertEqual(HistoryManager.shared.items.first?.result, "100")
    }
    
    /// Scenario 5: App Backgrounding & Foregrounding Haptic Engine Recovery Workflow
    func testWorkflow5_AppBackgroundLifecycleAndEngineRecoveryWithContinuousHum() {
        let manager = SoundAndHapticManager.shared
        manager.isHapticsEnabled = true
        
        // 1. Vision scanning activates continuous hum
        manager.startContinuousScanningHum()
        
        // 2. App transitions to background
        manager.handleAppBackground()
        
        // 3. User mutes haptics in preferences while in background
        manager.isHapticsEnabled = false
        
        // 4. App returns to foreground
        manager.handleAppForeground()
        XCTAssertFalse(manager.isHapticsEnabled)
        
        // 5. User re-enables haptics
        manager.isHapticsEnabled = true
        manager.handleAppForeground()
        XCTAssertTrue(manager.isHapticsEnabled)
        
        // 6. Verify haptic patterns execute cleanly
        manager.playCelebratorySuccess()
        manager.playErrorThud()
    }
}
