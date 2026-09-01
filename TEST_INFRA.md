# E2E Test Infra: LiquidCalc

## Test Philosophy
- Opaque-box, requirement-driven. Derives test suites from user requirements in `ORIGINAL_REQUEST.md`.
- Methodology: Category-Partition + Boundary Value Analysis (BVA) + Pairwise Combinatorial Testing + Real-World Workload Testing.

## Feature Inventory
| # | Feature | Source | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---------|--------|:------:|:------:|:------:|:------:|
| F1 | Liquid Glass & Keypad Dynamics | ORIGINAL_REQUEST §R1 | ≥5 | ≥5 | ✓ | ✓ |
| F2 | Scanner Motion FX & Viewfinder | ORIGINAL_REQUEST §R2 | ≥5 | ≥5 | ✓ | ✓ |
| F3 | Synchronized Scanning Haptics | ORIGINAL_REQUEST §R3 | ≥5 | ≥5 | ✓ | ✓ |
| F4 | Smart Vision OCR & Normalization | ORIGINAL_REQUEST §R4 | ≥5 | ≥5 | ✓ | ✓ |
| F5 | Advanced Math Engine & Percentages | ORIGINAL_REQUEST §R4 | ≥5 | ≥5 | ✓ | ✓ |
| F6 | Multi-Currency Receipt Engine | ORIGINAL_REQUEST §R4 | ≥5 | ≥5 | ✓ | ✓ |
| F7 | GitHub Releases Online Update Checker | ORIGINAL_REQUEST §Follow-up | ≥5 | ≥5 | ✓ | ✓ |

## Test Architecture
- Test Runner: Swift Package Manager (`swift test`) and Xcodebuild (`xcodebuild test`).
- Test Structure:
  - `LiquidCalcTests/LiquidCalcE2ETests.swift`: 4-tier systematic E2E test suite covering F1-F7.
  - `LiquidCalcTests/MathEngineTests.swift`: Comprehensive arithmetic, fractions, superscripts, percentages, roots.
  - `LiquidCalcTests/VisionMathScannerTests.swift`: OCR sanitization and multi-currency receipt parsing.
  - `LiquidCalcTests/SoundAndHapticManagerTests.swift`: CoreHaptics patterns, continuous hum, and fallbacks.
  - `LiquidCalcTests/AppUpdateManagerTests.swift`: Semantic version comparison, GitHub release decoding, and update workflow.

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | European Restaurant Multi-Course Dinner Split with Tip | F6, F1, F3 | High |
| 2 | Moroccan Café Multi-Item Bill (MAD) with Per-Person Split | F6, F1, F3 | High |
| 3 | Camera Math Scan of Polynomial with Powers, Roots, Fractions | F4, F5, F2, F3 | High |
| 4 | Postfix Percentage Discount & Sales Tax Calculation | F5, F1 | Medium |
| 5 | Online Update Check Flow with Semantic Version Compare | F7, F1 | Medium |

## Coverage Thresholds
- Tier 1: ≥5 per feature (Total ≥35 tests)
- Tier 2: ≥5 per feature boundary & corner (Total ≥35 tests)
- Tier 3: Pairwise cross-feature interactions (Total ≥10 tests)
- Tier 4: ≥5 realistic end-to-end user workflows
- Target: 100% automated test suite pass rate across all tiers.
