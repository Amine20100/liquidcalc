# Project: LiquidCalc

## Architecture
LiquidCalc is a modern iOS 18 calculator and smart math assistant built with SwiftUI, Swift 6 Observation (`@Observable`), CoreHaptics, and Vision.

```
┌────────────────────────────────────────────────────────────────────────┐
│                              LiquidCalcApp                             │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
                        MainCalculatorView (SwiftUI)
   ┌────────────────────────────────┼────────────────────────────────┐
   │                                │                                │
   ▼                                ▼                                ▼
LiquidGlassBackground        LiquidDisplayView               KeypadButtonView
(Multi-layer drifting        (Numeric text transition,       (Spring scale 0.90/0.92,
 radial gradients, blur)     cursor glow, error shake)       specular sheen, halos)
                                    │
                                    ▼
                        ModeSwitcherView (MatchedGeometry Pill)
   ┌────────────────────────────────┼────────────────────────────────┐
   │                                │                                │
   ▼                                ▼                                ▼
CalculatorKeypadView        MathDrawCanvasView              CameraScannerView
(Standard/Scientific/       (Stroke drawing dynamics,       (Vision OCR bounding box,
 Programmer keypads)         micro-vibrations, solve fanfare) lock-on snap ticks)
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        SoundAndHapticManager                           │
│  - CHHapticEngine lifecycle (auto-start, backgrounding, reset recover) │
│  - Multi-tier patterns (Digit, Operator, Equals, Hum, Fanfare, Thud)   │
│  - Graceful UIKit fallbacks (UIImpact/UINotificationFeedbackGenerator) │
│  - Dynamic user intensity multiplier (0.1 ... 1.0) & settings sync     │
└────────────────────────────────────────────────────────────────────────┘
```

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Specular Sheen & Spring Scale | Interactive specular highlights and spring compression (0.90/0.92) on button press | M1 | ORIGINAL_REQUEST §R1 |
| 2 | Contact Glow & Halo | Radial/linear cyan glowing contact halos on keypad buttons and dock pills | M1 | ORIGINAL_REQUEST §R1 |
| 3 | Numeric Text Transition | Smooth morphing `.contentTransition(.numericText())` in primary display | M1 | ORIGINAL_REQUEST §R1 |
| 4 | Expression Cursor Breathing | Pulsing cyan glow on active expression insertion cursor | M1 | ORIGINAL_REQUEST §R1 |
| 5 | Natural Spring Error Shake | Sinusoidal spring shake animation on evaluation error / division by zero | M1 | ORIGINAL_REQUEST §R1 |
| 6 | Drifting Ambient Glass Mesh | 3-layer radial gradient mesh with ultra-thin material blur | M1 | ORIGINAL_REQUEST §R1 |
| 7 | Matched Geometry Mode Dock | Smoothly interpolating pill indicator across Standard, Scientific, Programmer, Draw, Vision modes | M1 | ORIGINAL_REQUEST §R1 |
| 8 | CHHapticEngine Lifecycle Manager | Auto-start, backgrounding shutdown, reset recovery on audio server restart | M2 | ORIGINAL_REQUEST §R2 |
| 9 | Digit & Character Taps | Crisp, subtle transient clicks with minimal latency | M2 | ORIGINAL_REQUEST §R2 |
| 10 | Operator & Function Keys | Distinct dual-pulse tactile transients for +, -, ×, ÷, AND, OR, XOR | M2 | ORIGINAL_REQUEST §R2 |
| 11 | Equals & Evaluation Resolve | Heavy tactile resolve burst on calculation completion | M2 | ORIGINAL_REQUEST §R2 |
| 12 | Continuous Active Hums | Rhythmic subtle vibration during camera scanning or drawing | M2 | ORIGINAL_REQUEST §R2 |
| 13 | Lock-On & Solve Celebration | Multi-stage harmonic fanfare upon successful math equation OCR or drawing solve | M2 | ORIGINAL_REQUEST §R2 |
| 14 | Error & Domain Faults Thud | Heavy double-thud vibration on syntax error or domain failure | M2 | ORIGINAL_REQUEST §R2 |
| 15 | Graceful Fallback Engine | Fallback to UIImpactFeedbackGenerator and UINotificationFeedbackGenerator | M2 | ORIGINAL_REQUEST §R2 |
| 16 | Settings Real-Time Controls | User settings for haptic intensity (0.1-1.0), audio toggle, and live preview | M2 | ORIGINAL_REQUEST §R2 |
| 17 | Draw Calc Stroke Dynamics | Velocity/pressure-based micro-vibration ticks during active canvas drawing | M3 | ORIGINAL_REQUEST §R3 |
| 18 | Viewfinder Lock-On Snap | Crisp tactile lock-on tick when camera viewfinder snaps to equation / box | M3 | ORIGINAL_REQUEST §R3 |
| 19 | Comprehensive Unit & E2E Tests | Automated unit test suite verifying haptic engine, fallbacks, intensity, and UI dynamics | M4 | ORIGINAL_REQUEST Acceptance |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Next-Gen Liquid Glass Visual Design & Fluid Spring Physics | Specular sheen, glowing contact halos, spring scale compression, numeric morphing, cursor breathing glow, spring error shake, ambient glass drifting mesh | None | DONE |
| M2 | Comprehensive Multi-Tiered CoreHaptics Tactile Engine | Centralized CHHapticEngine manager, 6 distinct pattern tiers + equals resolve, dynamic intensity multiplier, lifecycle recovery, UIKit fallback, Settings intensity slider & preview | None | IN_PROGRESS |
| M3 | Feature & Input Haptic Synchronization | Draw Calc canvas stroke drawing micro-vibrations, camera viewfinder lock-on snap ticks | M2 | PLANNED |
| M4 | Comprehensive Test Suite & Verification | Automated test suite expansion, 100% pass verification on all engine and UI capabilities | M1, M2, M3 | PLANNED |

## Interface Contracts

### `SoundAndHapticManager` Public Interface
```swift
@MainActor
public final class SoundAndHapticManager: ObservableObject {
    public static let shared: SoundAndHapticManager
    
    @Published public var isHapticsEnabled: Bool
    @Published public var isSoundEnabled: Bool
    @Published public var hapticIntensity: Double // 0.1 ... 1.0
    
    public func playDigitClick()
    public func playOperatorBurst()
    public func playFunctionClick()
    public func playEqualsResolve()
    public func playErrorThud()
    public func playCelebratorySuccess()
    public func playLockOnTick()
    public func playDrawingStrokeTick()
    public func startContinuousScanningHum()
    public func stopContinuousScanningHum()
    public func triggerHapticPreview()
}
```

### `KeypadButtonView` Key Action Routing
- Digits / numbers / decimal / parenthesis -> `playDigitClick()`
- Operators (+, -, ×, ÷, %, AND, OR, XOR, NOT, shift) -> `playOperatorBurst()`
- Functions (sin, cos, tan, ln, log, sqrt, etc.) -> `playFunctionClick()`
- Equals (=, evaluate) -> `playEqualsResolve()`
- Clear / Delete -> `playDigitClick()` / `playFunctionClick()`

### `SettingsSheetView` Bindings
- Section "Feedback & Interactions":
  - `Toggle("Haptic Feedback", isOn: $feedbackManager.isHapticsEnabled)`
  - `Toggle("Key Sounds", isOn: $feedbackManager.isSoundEnabled)`
  - `Slider(value: $feedbackManager.hapticIntensity, in: 0.1...1.0, step: 0.05)`
  - `Button("Test Haptic Intensity") { feedbackManager.triggerHapticPreview() }`

## Code Layout
- `LiquidCalc/Core/Feedback/SoundAndHapticManager.swift` - CoreHaptics engine, pattern creation, fallback mechanics, intensity scaling
- `LiquidCalc/Views/Keypads/KeypadButtonView.swift` - Button spring style, specular highlights, contact halos, tactile routing
- `LiquidCalc/Views/Display/LiquidDisplayView.swift` - Numeric text transition, dynamic font sizing, cursor glow, error shake
- `LiquidCalc/Views/Components/LiquidGlassBackground.swift` - Ambient drifting radial gradient mesh & ultra-thin material
- `LiquidCalc/Views/Components/ModeSwitcherView.swift` - Matched geometry mode pill selector
- `LiquidCalc/Views/Components/SettingsSheetView.swift` - Settings toggles, intensity slider, real-time preview
- `LiquidCalc/Views/DrawCalc/MathDrawCanvasView.swift` & `LiquidCalc/ViewModels/DrawCalcViewModel.swift` - Canvas drawing gesture, stroke micro-vibration synchronization
- `LiquidCalc/Views/Vision/Components/ReticleOverlayView.swift` & `LiquidCalc/ViewModels/VisionViewModel.swift` - Viewfinder target lock-on snap ticks
- `LiquidCalcTests/SoundAndHapticManagerTests.swift` - Haptic engine unit tests
- `LiquidCalcTests/LiquidCalcE2ETests.swift` - End-to-end integration and UI tests
