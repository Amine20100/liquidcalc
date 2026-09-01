//
//  SoundAndHapticManager.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI
import AudioToolbox

#if canImport(CoreHaptics)
import CoreHaptics
#endif

#if canImport(UIKit)
import UIKit
#endif

@Observable
public final class SoundAndHapticManager: @unchecked Sendable {
    public static let shared = SoundAndHapticManager()
    
    // MARK: - Preferences & State
    
    public var isHapticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isHapticsEnabled, forKey: "LC_HapticsEnabled")
            if !isHapticsEnabled {
                stopContinuousScanningHum()
            }
        }
    }
    
    public var isSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: "LC_SoundEnabled")
        }
    }
    
    #if canImport(CoreHaptics) && os(iOS)
    private var engine: CHHapticEngine?
    private var continuousScanningPlayer: CHHapticAdvancedPatternPlayer?
    private var isEngineRunning: Bool = false
    #endif
    
    // MARK: - Initialization
    
    public init() {
        self.isHapticsEnabled = UserDefaults.standard.object(forKey: "LC_HapticsEnabled") as? Bool ?? true
        self.isSoundEnabled = UserDefaults.standard.object(forKey: "LC_SoundEnabled") as? Bool ?? true
        
        #if canImport(CoreHaptics) && os(iOS)
        setupCoreHapticsEngine()
        #endif
    }
    
    // MARK: - Hardware Capability
    
    public var supportsCoreHaptics: Bool {
        #if canImport(CoreHaptics) && os(iOS)
        return CHHapticEngine.capabilitiesForHardware().supportsHaptics
        #else
        return false
        #endif
    }
    
    // MARK: - CoreHaptics Engine Lifecycle (F8)
    
    public func prepare() {
        #if canImport(CoreHaptics) && os(iOS)
        guard supportsCoreHaptics else { return }
        if engine == nil {
            setupCoreHapticsEngine()
        }
        #endif
    }
    
    #if canImport(CoreHaptics) && os(iOS)
    private func setupCoreHapticsEngine() {
        guard supportsCoreHaptics else { return }
        do {
            let newEngine = try CHHapticEngine()
            newEngine.playsHapticsOnly = true
            newEngine.autoShutdownEnabled = false
            
            // Handle engine reset (e.g. after audio server restart)
            newEngine.resetHandler = { [weak self] in
                guard let self = self else { return }
                do {
                    try self.engine?.start()
                    self.isEngineRunning = true
                } catch {
                    self.isEngineRunning = false
                }
            }
            
            // Handle engine stoppage (e.g. app backgrounding, audio interruption)
            newEngine.stoppedHandler = { [weak self] reason in
                guard let self = self else { return }
                self.isEngineRunning = false
                self.stopContinuousScanningHum()
            }
            
            self.engine = newEngine
            if isHapticsEnabled {
                try newEngine.start()
                self.isEngineRunning = true
            }
        } catch {
            self.engine = nil
            self.isEngineRunning = false
        }
    }
    #endif
    
    public func startEngine() {
        #if canImport(CoreHaptics) && os(iOS)
        guard isHapticsEnabled, supportsCoreHaptics else { return }
        if engine == nil {
            setupCoreHapticsEngine()
        }
        guard let engine = engine, !isEngineRunning else { return }
        do {
            try engine.start()
            isEngineRunning = true
        } catch {
            isEngineRunning = false
        }
        #endif
    }
    
    public func stopEngine() {
        #if canImport(CoreHaptics) && os(iOS)
        stopContinuousScanningHum()
        guard let engine = engine, isEngineRunning else { return }
        engine.stop { [weak self] _ in
            self?.isEngineRunning = false
        }
        isEngineRunning = false
        #endif
    }
    
    public func handleAppBackground() {
        stopContinuousScanningHum()
        stopEngine()
    }
    
    public func handleAppForeground() {
        if isHapticsEnabled {
            startEngine()
        }
    }
    
    // MARK: - Custom Haptic Patterns (F9 & F10)
    
    /// Sharp, crisp transient click for digit and standard keypresses (F9).
    public func playDigitClick() {
        guard isHapticsEnabled else { return }
        
        #if canImport(CoreHaptics) && os(iOS)
        if supportsCoreHaptics, let engine = engine {
            do {
                if !isEngineRunning { try engine.start(); isEngineRunning = true }
                let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)
                let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.95)
                let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensityParam, sharpnessParam], relativeTime: 0)
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                return
            } catch {
                // Fall through to UIKit fallback
            }
        }
        #endif
        
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
    
    /// Distinct double-tap tactile burst for operation and function keys (=, +, -, *, /, C) (F9).
    public func playOperatorBurst() {
        guard isHapticsEnabled else { return }
        
        #if canImport(CoreHaptics) && os(iOS)
        if supportsCoreHaptics, let engine = engine {
            do {
                if !isEngineRunning { try engine.start(); isEngineRunning = true }
                let event1 = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0.0
                )
                let event2 = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.95)
                    ],
                    relativeTime: 0.08
                )
                let pattern = try CHHapticPattern(events: [event1, event2], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                return
            } catch {
                // Fall through to UIKit fallback
            }
        }
        #endif
        
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
    
    /// Distinct tactile click for function modifier keys.
    public func playFunctionClick() {
        guard isHapticsEnabled else { return }
        
        #if canImport(CoreHaptics) && os(iOS)
        if supportsCoreHaptics, let engine = engine {
            do {
                if !isEngineRunning { try engine.start(); isEngineRunning = true }
                let event = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.75)
                    ],
                    relativeTime: 0.0
                )
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                return
            } catch {
                // Fall through to UIKit fallback
            }
        }
        #endif
        
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
    
    /// Heavy thud pattern on calculation or domain errors (low sharpness, high intensity) (F9).
    public func playErrorThud() {
        guard isHapticsEnabled else { return }
        
        #if canImport(CoreHaptics) && os(iOS)
        if supportsCoreHaptics, let engine = engine {
            do {
                if !isEngineRunning { try engine.start(); isEngineRunning = true }
                let event1 = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15)
                    ],
                    relativeTime: 0.0
                )
                let event2 = CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
                    ],
                    relativeTime: 0.0,
                    duration: 0.12
                )
                let event3 = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 0.14
                )
                let pattern = try CHHapticPattern(events: [event1, event2, event3], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                return
            } catch {
                // Fall through to UIKit fallback
            }
        }
        #endif
        
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
        #endif
    }
    
    /// Rich celebratory success fanfare pattern upon solving a scanned equation (F9).
    public func playCelebratorySuccess() {
        guard isHapticsEnabled else { return }
        
        #if canImport(CoreHaptics) && os(iOS)
        if supportsCoreHaptics, let engine = engine {
            do {
                if !isEngineRunning { try engine.start(); isEngineRunning = true }
                let e1 = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                    ],
                    relativeTime: 0.0
                )
                let e2 = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.75)
                    ],
                    relativeTime: 0.08
                )
                let e3 = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                    ],
                    relativeTime: 0.16
                )
                let e4 = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: 0.24
                )
                let swell = CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0.24,
                    duration: 0.18
                )
                let pattern = try CHHapticPattern(events: [e1, e2, e3, e4, swell], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                return
            } catch {
                // Fall through to UIKit fallback
            }
        }
        #endif
        
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }
    
    // MARK: - Continuous Feedback (F9)
    
    /// Continuous subtle rumble/hum player during active camera scanning (F9).
    public func startContinuousScanningHum() {
        guard isHapticsEnabled else { return }
        
        #if canImport(CoreHaptics) && os(iOS)
        guard supportsCoreHaptics else { return }
        if engine == nil { setupCoreHapticsEngine() }
        guard let engine = engine else { return }
        
        do {
            if !isEngineRunning { try engine.start(); isEngineRunning = true }
            if continuousScanningPlayer != nil { return }
            
            let continuousEvent = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
                ],
                relativeTime: 0.0,
                duration: 60.0
            )
            let pattern = try CHHapticPattern(events: [continuousEvent], parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            player.loopEnabled = true
            try player.start(atTime: CHHapticTimeImmediate)
            self.continuousScanningPlayer = player
        } catch {
            self.continuousScanningPlayer = nil
        }
        #endif
    }
    
    /// Stops and releases the continuous scanning hum player (F9).
    public func stopContinuousScanningHum() {
        #if canImport(CoreHaptics) && os(iOS)
        if let player = continuousScanningPlayer {
            try? player.stop(atTime: CHHapticTimeImmediate)
            continuousScanningPlayer = nil
        }
        #endif
    }
    
    // MARK: - Legacy / Unified Bridge (F10 & F11)
    
    public enum HapticStyle {
        case light
        case medium
        case heavy
        case selection
        case success
        case error
    }
    
    public func triggerHaptic(_ style: HapticStyle) {
        guard isHapticsEnabled else { return }
        
        switch style {
        case .light:
            playDigitClick()
        case .medium:
            playOperatorBurst()
        case .heavy:
            playOperatorBurst()
        case .selection:
            #if os(iOS)
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
            #else
            playDigitClick()
            #endif
        case .success:
            playCelebratorySuccess()
        case .error:
            playErrorThud()
        }
    }
    
    // MARK: - Audio Feedback
    
    public func playKeySound() {
        guard isSoundEnabled else { return }
        #if os(iOS)
        AudioServicesPlaySystemSound(1104) // Standard iOS keyboard tap sound ID
        #endif
    }
    
    public func playOperationSound() {
        guard isSoundEnabled else { return }
        #if os(iOS)
        AudioServicesPlaySystemSound(1105) // Action modifier click
        #endif
    }
    
    public func playSuccessSound() {
        guard isSoundEnabled else { return }
        #if os(iOS)
        AudioServicesPlaySystemSound(1054) // Completion chime
        #endif
    }
}
