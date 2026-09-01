# LiquidCalc — Advanced iOS Calculator with Smart Vision (iOS 18+ & Swift 6)

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2018%2B-blue.svg)](https://developer.apple.com/ios/)
[![UI](https://img.shields.io/badge/UI-SwiftUI%20%7C%20Liquid%20Glass-cyan.svg)](https://developer.apple.com/xcode/swiftui/)
[![Smart Vision](https://img.shields.io/badge/Vision-Apple%20VisionKit%20OCR-green.svg)](https://developer.apple.com/documentation/vision)
[![CI/CD](https://img.shields.io/badge/Build-GitHub%20Actions-blue.svg)](https://github.com/)

LiquidCalc is a 100% pure native **Swift 6** and **SwiftUI** iOS calculator engineered specifically for **iOS 18+** and future iOS versions.

It combines an Apple-inspired "Liquid Glass" frosted design system with Apple's on-device **Vision framework (`VNRecognizeTextRequest`)** for instant mathematical OCR and bill splitting, a multi-tiered **CoreHaptics (`CHHapticEngine`)** engine, a precision AST math engine with live speculative evaluation, a 64-bit programmer calculator with live bit visualizer, and a physical/digital unit converter.

---

## How to Build the iOS App

### Option A: Automated Cloud Build via GitHub Actions (Recommended on Windows)
Because native iOS compilation requires Apple's `xcodebuild` toolchain on macOS, a complete GitHub Actions CI/CD workflow is included at [`.github/workflows/ios-build.yml`](.github/workflows/ios-build.yml):
1. Push this repository to GitHub:
   ```bash
   git init
   git add .
   git commit -m "Initial commit of LiquidCalc iOS app"
   git branch -M main
   git remote add origin <your-github-repo-url>
   git push -u origin main
   ```
2. GitHub Actions will automatically spin up an official Apple Silicon `macos-14` runner with Xcode 16.
3. It compiles the iOS app (Release configuration), runs the 155 unit tests, and packages `LiquidCalc.app` into a downloadable zip artifact (`LiquidCalc-iOS-App`) under the **Actions** tab.

### Option B: Local Build on macOS (Xcode 16+)
1. Double-click [`LiquidCalc.xcodeproj`](LiquidCalc.xcodeproj) to open the project in Xcode 16+.
2. Select your target device or simulator: **iPhone 16 / iPhone 16 Pro (iOS 18.0+)**.
3. Press **Cmd + B** to build, or **Cmd + R** to run in the simulator.
4. Press **Cmd + U** to run the complete 155-test suite (`LiquidCalcTests`).

Alternatively, compile from the command line on macOS:
```bash
xcodebuild build \
  -project LiquidCalc.xcodeproj \
  -scheme LiquidCalc \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO
```

### Option C: Run Local Verification on Windows
To verify all business logic, math AST evaluations, CoreHaptics lifecycles, and test suites on Windows:
```powershell
.\build.ps1
```

---

## Architecture & Features

### 1. Smart Vision Math Scanner & Receipt Splitter
- **On-Device Vision OCR (`VNRecognizeTextRequest`)**:
  - Point your iPhone camera at handwritten or printed math notes, whiteboard calculations, or textbook problems.
  - Accurate character recognition with specialized mathematical string sanitization (converting OCR artifacts like `×`, `÷`, `x` between numbers, `√`, $\pi$, and trailing equals signs).
  - Instant live solve overlay with one-tap transfer to the primary calculator workspace.
- **Holographic Laser Sweep & Reticle**:
  - Multi-layer neon laser line with core filament traversing the viewfinder continuously during scanning.
  - Adaptive corner reticle that pulses and locks onto detected mathematical formulas or receipts with a neon green shift.
- **Photo Library & Screenshot Import (`PhotosPicker`)**:
  - Scan equations and expenses directly from your photo library or screenshot gallery.
- **Receipt & Bill Splitter**:
  - Multi-line itemized OCR scanning of store receipts and dining bills.
  - Real-time subtotal, tax rate calculation, tip presets (15%, 18%, 20%, 25%), and per-person split calculator (1–30 people).

### 2. High-Quality UI/UX & Interactive Design System
- **Apple iOS 18 Liquid Glass Aesthetic**:
  - Frosted `.ultraThinMaterial` dynamic glass, specular gradient sheen highlights, ambient background mesh glows, and smooth spring physics.
- **Native Gesture Interactions**:
  - **Swipe-to-Delete**: Swipe left or right on the main display to delete the last character (Apple's signature calculator gesture).
  - **Long-Press to Copy**: Long press on the display result to copy to the clipboard with haptic confirmation and an animated checkmark HUD.
- **Advanced CoreHaptics & Acoustic Engine (`SoundAndHapticManager`)**:
  - Full `CHHapticEngine` lifecycle with continuous scanning rumble, sharp transient clicks, dual-pulse operator bursts, 4-pulse celebration fanfare, and error thuds.
  - Automatic fallback to `UIImpactFeedbackGenerator` and `UINotificationFeedbackGenerator` on unsupported hardware.
  - Preferences sheet to toggle haptics and acoustic sounds on or off.

### 3. Precision Expression Math Engine (PEMDAS / BODMAS)
- **Tokenization & AST Parsing**: Dijkstra's Shunting-yard algorithm parses expressions into an AST / Reverse Polish Notation (RPN).
- **Implicit Multiplication**: Handles notations like `2(3)` $\to 6$, `3pi` $\to 3\pi$, and `(4)(5)` $\to 20$.
- **Full Scientific Suite**:
  - Trigonometric & Hyperbolic: `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `sinh`, `cosh`, `tanh`
  - Logarithms: `ln`, `log10`, `log2`
  - Powers & Roots: `xʸ`, `x²`, `x³`, `10ˣ`, `eˣ`, `√`, `∛`
  - Advanced: Factorial (`x!`), Reciprocal (`1/x`), Constants ($\pi$, $e$, $\phi$, $\tau$)
  - Instant angle mode switching: **RAD** vs **DEG**
- **Live Speculative Evaluation**: Real-time floating preview badge updating as you type.
- **Memory Registers**: `MC`, `MR`, `M+`, `M-`.

### 4. Programmer Calculator & Interactive 64-Bit Visualizer
- **Simultaneous Multi-Base Display**: Live synchronized cards for **HEX**, **DEC**, **OCT**, and **BIN**.
- **Word Sizes**: **64-bit (QWORD)**, **32-bit (DWORD)**, **16-bit (WORD)**, and **8-bit (BYTE)** with automatic bit masking.
- **Signed / Unsigned Toggle**: Instant two's complement interpretation.
- **Interactive 64-Bit Visualizer Grid**: Tap any individual bit from 0 to 63 to flip it between `0` and `1` with real-time numeric recalculation.
- **Bitwise Logic**: `AND`, `OR`, `XOR`, `NOT`, `NAND`, `NOR`, `XNOR`, logical/arithmetic shifts (`<<`, `>>`), and bit rotations (`ROL`, `ROR`).

### 5. Multi-Category Unit Converter
- 10 comprehensive categories: Length, Weight/Mass, Temperature, Speed, Area, Volume, Data Storage, Time, Pressure, and Energy.
- Bidirectional live conversion with quick-swap button and custom numeric keypad.

### 6. Calculation Tape (History)
- Persistent calculation history stored with formatted timestamps, input expressions, and results.
- Search filter, one-tap copy to clipboard, swipe to delete, and clear tape with confirmation.

---

## 100% Native Swift Project Structure

```
liqidcalc/
├── .github/
│   └── workflows/
│       └── ios-build.yml           # Automated macOS CI/CD workflow for building .app/.zip
├── LiquidCalc.xcodeproj/           # Xcode 16 project file (Targeting iOS 18.0+)
│   └── project.pbxproj
├── LiquidCalc/
│   ├── App/
│   │   └── LiquidCalcApp.swift     # Native @main SwiftUI entry point
│   ├── Models/
│   │   ├── CalculatorMode.swift    # Standard, Scientific, Programmer, Converter, Vision
│   │   ├── KeypadButton.swift      # Button taxonomy & glass styling
│   │   └── AngleUnit.swift         # Radians & Degrees
│   ├── Core/
│   │   ├── MathEngine/             # AST Shunting-yard engine (PEMDAS)
│   │   ├── ProgrammerEngine/       # 64-bit multi-radix & bitwise engine
│   │   ├── UnitConverter/          # 10 conversion categories
│   │   ├── History/                # Calculation tape storage
│   │   ├── Vision/                 # Apple Vision OCR & AVCaptureSession
│   │   └── Feedback/               # CoreHaptics & AudioToolbox manager
│   ├── ViewModels/                 # Calc, Programmer, Converter, Vision ViewModels
│   ├── Views/                      # Display, Keypads, Vision, Components
│   └── Resources/
│       ├── Assets.xcassets/        # AppIcon & asset catalog
│       └── Info.plist              # Camera & Photo Library permissions
├── LiquidCalcTests/
│   ├── MathEngineTests.swift
│   ├── ProgrammerEngineTests.swift
│   ├── UnitConverterTests.swift
│   ├── VisionMathScannerTests.swift
│   ├── SoundAndHapticManagerTests.swift
│   └── LiquidCalcE2ETests.swift    # 131 E2E tests across Tiers 1-4
├── Package.swift                   # Swift Package Manager manifest
├── build.ps1                       # Windows verification script
└── README.md                       # Complete documentation
```
