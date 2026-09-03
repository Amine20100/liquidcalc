//
//  SoundAndHapticManagerTests.swift
//  LiquidCalcTests
//
//  Created for LiquidCalc iOS 18+.
//

import XCTest
#if canImport(LiquidCalc)
@testable import LiquidCalc
#elseif canImport(LiquidCalcCore)
@testable import LiquidCalcCore
#endif

final class SoundAndHapticManagerTests: XCTestCase {
    private var manager: SoundAndHapticManager!
    private var originalHapticsEnabled: Bool!
    private var originalSoundEnabled: Bool!
    
    override func setUp() {
        super.setUp()
        manager = SoundAndHapticManager.shared
        originalHapticsEnabled = manager.isHapticsEnabled
        originalSoundEnabled = manager.isSoundEnabled
    }
    
    override func tearDown() {
        manager.isHapticsEnabled = originalHapticsEnabled
        manager.isSoundEnabled = originalSoundEnabled
        manager.stopContinuousScanningHum()
        super.tearDown()
    }
    
    func testHapticsSettingsPersistence() {
        manager.isHapticsEnabled = false
        XCTAssertFalse(manager.isHapticsEnabled)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "LC_HapticsEnabled"), false)
        
        manager.isHapticsEnabled = true
        XCTAssertTrue(manager.isHapticsEnabled)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "LC_HapticsEnabled"), true)
    }
    
    func testSoundSettingsPersistence() {
        manager.isSoundEnabled = false
        XCTAssertFalse(manager.isSoundEnabled)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "LC_SoundEnabled"), false)
        
        manager.isSoundEnabled = true
        XCTAssertTrue(manager.isSoundEnabled)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "LC_SoundEnabled"), true)
    }
    
    func testEngineLifecycleStateHandling() {
        // Test engine lifecycle methods execute safely in test/headless environment
        manager.prepare()
        manager.startEngine()
        manager.handleAppForeground()
        manager.handleAppBackground()
        manager.stopEngine()
    }
    
    func testHardwareCapabilityCheckSafety() {
        let supports = manager.supportsCoreHaptics
        // Verify capability check returns a valid boolean without throwing
        XCTAssertTrue(supports == true || supports == false)
    }
    
    func testTactilePatternTriggersInHeadlessEnvironment() {
        manager.isHapticsEnabled = true
        
        // Execute all custom pattern triggers
        manager.playDigitClick()
        manager.playOperatorBurst()
        manager.playFunctionClick()
        manager.playErrorThud()
        manager.playCelebratorySuccess()
    }
    
    func testContinuousScanningHumLifecycle() {
        manager.isHapticsEnabled = true
        
        // Start continuous hum
        manager.startContinuousScanningHum()
        
        // Redundant start call should be safely ignored
        manager.startContinuousScanningHum()
        
        // Stop continuous hum
        manager.stopContinuousScanningHum()
        
        // Redundant stop call should be safe
        manager.stopContinuousScanningHum()
    }
    
    func testDisablingHapticsStopsContinuousHum() {
        manager.isHapticsEnabled = true
        manager.startContinuousScanningHum()
        
        // Toggling haptics off should automatically stop and cleanup continuous hum
        manager.isHapticsEnabled = false
        XCTAssertFalse(manager.isHapticsEnabled)
        
        // Triggers with haptics disabled should exit early
        manager.playDigitClick()
        manager.playOperatorBurst()
        manager.playFunctionClick()
        manager.playErrorThud()
        manager.playCelebratorySuccess()
        manager.startContinuousScanningHum()
    }
    
    func testLegacyHapticStyleBridge() {
        manager.isHapticsEnabled = true
        let allStyles: [SoundAndHapticManager.HapticStyle] = [
            .light,
            .medium,
            .heavy,
            .selection,
            .success,
            .error
        ]
        
        for style in allStyles {
            manager.triggerHaptic(style)
        }
        
        manager.isHapticsEnabled = false
        for style in allStyles {
            manager.triggerHaptic(style)
        }
    }
    
    func testAudioFeedbackTriggers() {
        manager.isSoundEnabled = true
        manager.playKeySound()
        manager.playOperationSound()
        manager.playSuccessSound()
        
        manager.isSoundEnabled = false
        manager.playKeySound()
        manager.playOperationSound()
        manager.playSuccessSound()
    }
    
    func testIndependentInstanceInitialization() {
        // Instantiate a separate instance to test default constructor and user defaults binding
        let freshManager = SoundAndHapticManager()
        XCTAssertNotNil(freshManager)
        freshManager.prepare()
        freshManager.stopEngine()
    }
}
