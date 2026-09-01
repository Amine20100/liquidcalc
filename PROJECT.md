# Project: LiquidCalc

## Architecture
LiquidCalc is an iOS 18+ / Swift 6 calculator and smart vision engine built with SwiftUI and Swift modern observation (`@Observable`).
The architecture is partitioned into:
- **`LiquidCalcCore`**:
  - `Models/`: Data structures for math tokens, calculation modes, receipt items, currency specifications (`SupportedCurrency`), and GitHub releases (`GitHubRelease`).
  - `Core/MathEngine/`: Lexer, AST Parser, Evaluator, and Unit Converter.
  - `Core/Vision/`: AVFoundation camera capture service, Vision framework OCR scanner (`VisionMathScanner`), math string sanitizers, and receipt parsing heuristics.
  - `Core/Feedback/`: CoreHaptics engine manager (`SoundAndHapticManager`) with continuous scanning hum, lock-on transients, and celebratory fanfare.
  - `Core/Update/`: `AppUpdateManager` and `UpdateCheckerService` for GitHub Releases API querying, semantic version comparison, and `.ipa` download resolution.
  - `ViewModels/`: `CalculatorViewModel`, `VisionViewModel`, `ProgrammerViewModel`, `ConverterViewModel`, and `UpdateViewModel`.
- **`LiquidCalc UI`**:
  - `Views/Components/`: Liquid glass backgrounds, dynamic mesh gradient drifting layers, mode switcher with matched geometry pills, settings sheet, update available modal/banner.
  - `Views/Display/`: Liquid numeric display with `.numericText()` transitions, gestural swipe-to-delete, copy HUD, speculative preview, and sinusoidal error shake.
  - `Views/Keypads/`: Standard, Scientific, and Programmer keypads with 0.92 spring scale dynamics and glowing contact halos.
  - `Views/Vision/`: Camera preview, holographic laser sweep line, expanding sonar wave rings, adaptive target reticles, frosted result cards, and multi-currency receipt splitter.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| F1 | Liquid Glass & Keypad Dynamics | Dynamic drifting ambient mesh gradients, specular glass sheen overlays, 0.92 spring scale compression keypad touch interactions with glowing halos, and .numericText() display morphing. | M1 | ORIGINAL_REQUEST §R1 |
| F2 | Scanner Motion FX & Viewfinder | Holographic laser sweep line curtain, expanding radar/sonar wave pulse rings, adaptive target reticles framing math/receipt bounding boxes with neon lock-on shift. | M2 | ORIGINAL_REQUEST §R2 |
| F3 | Synchronized Scanning Haptics | Continuous rhythmic tactile feedback synchronized with active scanning passes, crisp lock-on ticks, and celebratory fanfare on calculation resolution. | M3 | ORIGINAL_REQUEST §R3 |
| F4 | Smart Vision OCR & Math Normalization | Unicode vulgar fractions (½, ¼), superscript powers (x²), root wrapping (√x -> sqrt(x)), mixed fractions, and percentage normalization for OCR inputs. | M4 | ORIGINAL_REQUEST §R4 |
| F5 | Advanced Math Engine & Percentage Arithmetic | Postfix percentage evaluation (100 + 10%, 50%), multi-step expressions, roots, powers, robust error handling. | M4 | ORIGINAL_REQUEST §R4 |
| F6 | Multi-Currency Receipt Engine | International currency support ($, €, £, MAD, ¥, CHF, CAD, AUD), multilingual line classification (filtering subtotal/tax/total), and dynamic bill splitting. | M5 | ORIGINAL_REQUEST §R4 |
| F7 | GitHub Releases Online Update Checker | AppUpdateManager / UpdateCheckerService querying GitHub latest release, SemanticVersion comparison, Update Available modal/banner with .ipa download link, and Settings controls. | M6 | ORIGINAL_REQUEST §Follow-up |
| F8 | Comprehensive E2E & Unit Test Suite | 100% automated test coverage across all features F1-F7, boundary conditions, cross-feature interactions, and real-world scenarios in LiquidCalcTests. | M7 | ORIGINAL_REQUEST §Acceptance Criteria |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | UI & Keypad Dynamics Verification | Verify and harden Liquid Glass background, KeypadButtonView spring scale, LiquidDisplayView .numericText(), and ModeSwitcherView. | none | IN_PROGRESS |
| M2 | Scanner Motion FX & Sonar Rings | Add expanding SonarWaveRingsView, wire laser sweep and adaptive reticle animations to camera viewfinder. | none | PLANNED |
| M3 | Synchronized Haptics Integration | Connect SoundAndHapticManager continuous scanning hum and lock-on ticks to VisionViewModel lifecycle. | M2 | PLANNED |
| M4 | Smart Vision OCR & Math Parser | Upgrade VisionMathScanner normalizers (fractions, superscripts, roots) and MathEngine postfix percentage / multi-step evaluator. | none | PLANNED |
| M5 | Multi-Currency Receipt Engine | Implement SupportedCurrency, multilingual receipt line classifier, and dynamic ReceiptSplitterView. | M4 | PLANNED |
| M6 | GitHub Releases Update Checker | Implement Codable GitHubRelease models, SemanticVersion comparator, AppUpdateManager, UpdateAvailableView, and SettingsSheetView controls. | none | PLANNED |
| M7 | E2E Integration, Full Test Pass & Adversarial Hardening | Run 100% E2E and Unit test suite across Tiers 1-4, execute Tier 5 adversarial hardening, and verify clean build. | M1, M2, M3, M4, M5, M6 | PLANNED |

## Interface Contracts
### `SupportedCurrency` ↔ `ReceiptParser` ↔ `ReceiptSplitterView`
```swift
public enum SupportedCurrency: String, CaseIterable, Identifiable, Codable, Sendable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case mad = "MAD"
    case jpy = "JPY"
    case chf = "CHF"
    case cad = "CAD"
    case aud = "AUD"
    
    public var symbol: String { get }
    public var decimalPlaces: Int { get }
    public func format(amount: Double) -> String
}

public struct ReceiptLineItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var price: Double
    public var isSelected: Bool
}

public struct ReceiptParseResult: Equatable, Sendable {
    public var items: [ReceiptLineItem]
    public var detectedCurrency: SupportedCurrency
    public var detectedSubtotal: Double?
    public var detectedTax: Double?
    public var detectedTotal: Double?
}
```

### `AppUpdateManager` ↔ `UpdateCheckerService` ↔ `SettingsSheetView`
```swift
public struct SemanticVersion: Comparable, Equatable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public init?(_ versionString: String)
}

public struct GitHubReleaseAsset: Codable, Sendable {
    public let name: String
    public let browserDownloadURL: URL
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

public struct GitHubRelease: Codable, Sendable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlURL: URL
    public let assets: [GitHubReleaseAsset]
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name, body
        case htmlURL = "html_url"
        case assets
    }
}

@Observable
public final class AppUpdateManager {
    public var isChecking: Bool
    public var updateAvailable: Bool
    public var latestRelease: GitHubRelease?
    public var errorMessage: String?
    public var autoCheckOnLaunch: Bool
    
    public func checkForUpdates(manual: Bool) async -> Bool
}
```

## Code Layout
- `LiquidCalc/Models/`: `SupportedCurrency.swift`, `GitHubRelease.swift`, `CalculationMode.swift`, `MathToken.swift`
- `LiquidCalc/Core/MathEngine/`: `MathToken.swift`, `MathLexer.swift`, `MathParser.swift`, `MathEvaluator.swift`
- `LiquidCalc/Core/Vision/`: `VisionMathScanner.swift`, `CameraCaptureService.swift`
- `LiquidCalc/Core/Feedback/`: `SoundAndHapticManager.swift`
- `LiquidCalc/Core/Update/`: `AppUpdateManager.swift`, `SemanticVersion.swift`
- `LiquidCalc/ViewModels/`: `CalculatorViewModel.swift`, `VisionViewModel.swift`, `UpdateViewModel.swift`
- `LiquidCalc/Views/Components/`: `LiquidGlassBackground.swift`, `ModeSwitcherView.swift`, `SettingsSheetView.swift`, `UpdateAvailableView.swift`
- `LiquidCalc/Views/Keypads/`: `KeypadButtonView.swift`, `StandardKeypadView.swift`, `ScientificKeypadView.swift`, `ProgrammerKeypadView.swift`
- `LiquidCalc/Views/Display/`: `LiquidDisplayView.swift`
- `LiquidCalc/Views/Vision/`: `SmartVisionView.swift`, `CameraPreviewView.swift`, `ReceiptSplitterView.swift`
- `LiquidCalc/Views/Vision/Components/`: `LaserSweepLineView.swift`, `SonarWaveRingsView.swift`, `ReticleOverlayView.swift`, `SolvedResultCardView.swift`
- `LiquidCalcTests/`: `LiquidCalcE2ETests.swift`, `MathEngineTests.swift`, `VisionMathScannerTests.swift`, `SoundAndHapticManagerTests.swift`, `AppUpdateManagerTests.swift`
