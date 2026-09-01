# Project: LiquidCalc Motion FX & CoreHaptics

## Architecture
- **View Hierarchy & UI Motion Layer**:
  - MainCalculatorView acts as the root coordinator managing the active CalculatorMode with fluid matched geometry (ModeSwitcherView) and asymmetric slide/opacity workstation transitions.
  - KeypadButtonView handles interactive spring scale compression (.spring(response: 0.22, dampingFraction: 0.55)), specular sheen gradients, and dynamic glow shadows.
  - LiquidDisplayView handles numeric transitions, dynamic font scaling, swipe gestures, clipboard HUD, and horizontal sinusoidal ShakeEffect on errors.
- **Vision Scanner Motion & Visual FX Layer**:
  - SmartVisionView orchestrates camera capture, multi-phase animated holographic laser sweep, state-driven pulsing/locking reticle framing, and celebratory spring reveal card with glowing neon borders.
  - VisionViewModel coordinates OCR observation parsing, sub-mode switching (Equations vs. Receipts), and triggers haptic solve patterns.
- **Tactile Feedback & Lifecycle Layer**:
  - SoundAndHapticManager encapsulates CHHapticEngine lifecycle (start, stop, reset recovery, app backgrounding via scenePhase) and provides multi-tiered custom haptic patterns (digit transient clicks, operator double-tap bursts, continuous scanning rumble, celebratory solve pattern, heavy error thud) with automatic fallback to UIImpactFeedbackGenerator.
  - Preferences toggle (LC_HapticsEnabled) binds directly to SoundAndHapticManager.shared.isHapticsEnabled, controlling all haptic dispatch across the application.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | F1. Keypad Button Spring Physics | Interactive compression scale (0.92), specular sheen highlight, ambient glow shadow, and smooth release | M1 | Survey / R1 |
| 2 | F2. Fluid Number Transitions | Content transitions with numeric text animation and dynamic 36-58pt font scaling | M1 | Survey / R1 |
| 3 | F3. Animated Error Shake | Sinusoidal horizontal displacement (10pt amplitude, 3 shakes, 0.4s) on calculation errors | M1 | Survey / R1 |
| 4 | F4. Mode Switcher Transitions | Matched geometry indicator pill and asymmetric slide/cross-fade between all 5 calculator modes | M1 | Survey / R1 |
| 5 | F5. Animated Scanning Laser Line | Multi-layer holographic laser beam with core filament, cyan glow, and trailing curtain traversing viewfinder | M2 | Survey / R2 |
| 6 | F6. Pulsing & Locking Reticle | State-driven corner reticle with idle breathing, active scan inward pulse, and spring snap lock-on with neon green shift | M2 | Survey / R2 |
| 7 | F7. Solved Result Reveal Card | Spring scale/bounce reveal transition with multi-stop glowing neon accent border and outer shadow | M2 | Survey / R2 |
| 8 | F8. CHHapticEngine Lifecycle | Initialization, start/stop, backgrounding/foregrounding recovery, and engine reset/stopped handlers | M3 | Survey / R3 |
| 9 | F9. Multi-Tiered Haptic Patterns | Digit click, operator double-tap burst, continuous scanning rumble, celebratory solve fanfare, heavy error thud | M3 | Survey / R3 |
| 10 | F10. Graceful UIKit Fallbacks | Seamless fallback to UIImpactFeedbackGenerator / UINotificationFeedbackGenerator when CoreHaptics is unavailable | M3 | Survey / R3 |
| 11 | F11. Preferences Haptic Toggle | User-facing toggle in SettingsSheetView controlling all haptic feedback with immediate effect | M3 | Survey / R3 |
| 12 | F12. Test Suite & Verification | Full unit test suites in LiquidCalcTests covering Math, Programmer, Converter, Vision, and Haptics/Settings | M4/M5 | Survey / R1-R3 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | UI & Keypad Spring Motion | Keypad button physics, Display transitions & error shakes, Mode switcher matched geometry | none | DONE |
| M2 | Vision Scanner Motion & Visual FX | Viewfinder laser sweep line, Reticle overlay pulsing & locking, Result card spring reveal & glow | none | DONE |
| M3 | CoreHaptics Tactile Engine & Settings | CHHapticEngine lifecycle, custom patterns, UIKit fallbacks, Settings toggle & unified call sites | none | DONE |
| M4 | E2E Integration & Verification | 100% pass of E2E Test Suite (Tiers 1-4) across all feature combinations (155 tests total) | M1, M2, M3 | DONE |
| M5 | Adversarial Coverage Hardening | Tier 5 adversarial edge cases, stress testing, lifecycle robustness, and forensic integrity audit | M4 | DONE |

## Interface Contracts
### SoundAndHapticManager API
```swift
public final class SoundAndHapticManager: @unchecked Sendable {
    public static let shared: SoundAndHapticManager
    public var isHapticsEnabled: Bool
    public var isSoundEnabled: Bool
    
    // Lifecycle
    public func prepare()
    public func handleAppBackground()
    public func handleAppForeground()
    
    // Discrete Tactile Patterns
    public func playDigitClick()
    public func playOperatorBurst()
    public func playFunctionClick()
    public func playErrorThud()
    public func playCelebratorySuccess()
    
    // Continuous Tactile Feedback
    public func startContinuousScanningHum()
    public func stopContinuousScanningHum()
    
    // Legacy / Unified Bridge
    public func triggerHaptic(_ style: HapticStyle)
}
```

### KeypadButtonView API
```swift
struct KeypadButtonView: View {
    let button: KeypadButtonType
    let action: () -> Void
    // Internally binds KeypadPressStyle with .spring(response: 0.22, dampingFraction: 0.55),
    // specular gradient stroke, and cyan glow shadow.
}
```

### LiquidDisplayView API
```swift
struct LiquidDisplayView: View {
    @Bindable var viewModel: CalculatorViewModel
    // Binds shouldShakeDisplay to ShakeEffect GeometryEffect and applies .contentTransition(.numericText())
}
```

### VisionScannerView / SmartVisionView Components API
```swift
// Laser Sweep
struct LaserSweepLineView: View {
    let isScanning: Bool
}

// Reticle Overlay
struct ReticleOverlayView: View {
    let isScanning: Bool
    let hasTarget: Bool
    var targetBoundingBox: CGRect? = nil
}

// Solved Result Card
struct SolvedResultCardView: View {
    let result: String
    let expression: String
    let onOpenInCalc: () -> Void
    let onCopy: () -> Void
}
```

## Code Layout
- LiquidCalc/App/LiquidCalcApp.swift - App entry point with scenePhase lifecycle hooks for haptics.
- LiquidCalc/Core/Feedback/SoundAndHapticManager.swift - CoreHaptics engine, custom patterns, fallbacks, UserDefaults.
- LiquidCalc/Views/Keypads/KeypadButtonView.swift - Keypad button spring animations and visual effects.
- LiquidCalc/Views/Keypads/BitVisualizerView.swift - Bitwise button grid with unified haptics.
- LiquidCalc/Views/Display/LiquidDisplayView.swift - Display font scaling, numeric transitions, and error shake.
- LiquidCalc/Views/Components/ModeSwitcherView.swift - Matched geometry mode pill selector.
- LiquidCalc/Views/Components/SettingsSheetView.swift - Preferences toggle for haptics and sound.
- LiquidCalc/Views/Vision/SmartVisionView.swift - Vision scanner view with laser sweep, reticle, and result card.
- LiquidCalc/Views/Vision/Components/ - Modular vision UI components (LaserSweepLineView, ReticleOverlayView, SolvedResultCardView).
- LiquidCalc/Views/Converter/UnitConverterView.swift - Converter keypad with unified haptics.
- LiquidCalc/Views/History/HistorySheetView.swift - History view with unified haptics.
- LiquidCalcTests/ - Unit and E2E test suites (155 automated tests).
