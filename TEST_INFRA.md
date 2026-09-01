# E2E Test Infra: LiquidCalc

## Test Philosophy
- Opaque-box, requirement-driven testing based on user requirements in ORIGINAL_REQUEST.md.
- No internal coupling or assumptions about private implementation details.
- Systematic 4-tier methodology:
  - **Tier 1 - Feature Coverage**: Direct verification of each individual feature in isolation (>=5 tests per feature).
  - **Tier 2 - Boundary & Corner Cases**: Stress-testing boundaries, rapid taps, toggle spamming, invalid expressions, zero-division, nil values (>=5 tests per feature).
  - **Tier 3 - Cross-Feature Combinations**: Pairwise interactions between mode switches, calculations, error shakes, vision solves, and haptic feedback toggles.
  - **Tier 4 - Real-World Application Scenarios**: Multi-step workflows (e.g. multi-mode calculation, receipt itemization + calculation, vision math scan -> open in calc -> bitwise conversion).

## Feature Inventory
| # | Feature | Source (Requirement) | Tier 1 | Tier 2 | Tier 3 |
|---|---------|----------------------|:------:|:------:|:------:|
| 1 | F1. Keypad Button Spring Physics | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 2 | F2. Fluid Number Transitions | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 3 | F3. Animated Error Shake | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 4 | F4. Mode Switcher Transitions | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 5 | F5. Animated Scanning Laser Line | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 6 | F6. Pulsing & Locking Reticle | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 7 | F7. Solved Result Reveal Card | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 8 | F8. CHHapticEngine Lifecycle | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ |
| 9 | F9. Multi-Tiered Haptic Patterns | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ |
| 10 | F10. Graceful UIKit Fallbacks | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ |
| 11 | F11. Preferences Haptic Toggle | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ |

## Test Architecture
- Test Suite Location: LiquidCalcTests/
- Test Suites:
  - LiquidCalcTests/MathEngineTests.swift - Core math parsing and evaluation
  - LiquidCalcTests/ProgrammerEngineTests.swift - Bitwise and radix engine
  - LiquidCalcTests/UnitConverterTests.swift - Unit conversion engine
  - LiquidCalcTests/VisionMathScannerTests.swift - OCR sanitization and receipt parsing
  - LiquidCalcTests/SoundAndHapticManagerTests.swift - CoreHaptics lifecycle, patterns, fallbacks, and settings persistence
  - LiquidCalcTests/LiquidCalcE2ETests.swift - Tier 1-4 end-to-end integration and workflow test suites
- Test Runner:
  - Swift Package Manager: swift test
  - Xcodebuild: xcodebuild test -project LiquidCalc.xcodeproj -scheme LiquidCalc -destination "platform=iOS Simulator,name=iPhone 16,OS=18.0"

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | Standard Arithmetic Flow & Display Transition | F1, F2, F9, F11 | Medium |
| 2 | Division by Zero & Domain Error Shake | F1, F3, F9, F11 | Medium |
| 3 | Mode Switching Across All 5 Modes with State Retention | F1, F4, F9, F11 | High |
| 4 | Vision Scanner Equation Detection & Solve Fanfare | F5, F6, F7, F8, F9, F11 | High |
| 5 | App Backgrounding & Foregrounding Haptic Engine Recovery | F8, F9, F10, F11 | High |

## Coverage Thresholds
- Tier 1: ≥55 tests (≥5 per feature × 11 features)
- Tier 2: ≥55 tests (≥5 boundary tests per feature)
- Tier 3: ≥15 cross-feature pairwise tests
- Tier 4: ≥5 full application scenarios
- **Total Minimum Target**: ≥130 test assertions across unit and E2E suites.
