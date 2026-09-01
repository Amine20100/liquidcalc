//
//  VisionMathScannerTests.swift
//  LiquidCalcTests
//
//  Created for LiquidCalc iOS 18+.
//  Comprehensive Unit Test Suite for Features F4 & F6: Smart Vision OCR Math Normalization & Multi-Currency Receipt Engine
//  Covers OCR Math Sanitization (Vulgar Fractions, Mixed Fractions, Superscripts, Roots),
//  and Multi-Currency Receipt Itemization across USD, EUR, GBP, MAD, JPY, CHF, CAD, AUD, INR, BRL.
//

import XCTest
import CoreGraphics
#if canImport(LiquidCalcCore)
@testable import LiquidCalcCore
#endif

final class VisionMathScannerTests: XCTestCase {
    
    private var scanner: VisionMathScanner!
    
    override func setUp() {
        super.setUp()
        scanner = VisionMathScanner()
    }
    
    override func tearDown() {
        scanner = nil
        super.tearDown()
    }
    
    // =========================================================================
    // MARK: - SECTION 1: OCR Math Sanitization & Normalization
    // =========================================================================
    
    func testSanitizeBasicOperatorsAndEqualsSign() {
        // Trailing & leading equals signs
        XCTAssertEqual(scanner.sanitizeMathString("5 + 3 ="), "5 + 3")
        XCTAssertEqual(scanner.sanitizeMathString("= 10 * 2"), "10 * 2")
        XCTAssertEqual(scanner.sanitizeMathString("  42 =  "), "42")
        
        // Unicode multiplication and division
        XCTAssertEqual(scanner.sanitizeMathString("10 × 4 ÷ 2"), "10 * 4 / 2")
        XCTAssertEqual(scanner.sanitizeMathString("3 · 4"), "3 * 4")
        
        // Letter 'x' or 'X' as multiplication between numbers
        XCTAssertEqual(scanner.sanitizeMathString("6x7"), "6 * 7")
        XCTAssertEqual(scanner.sanitizeMathString("12 X 5"), "12 * 5")
        XCTAssertEqual(scanner.sanitizeMathString("100 x 2"), "100 * 2")
        
        // Dashes: En-dash, Em-dash, Minus sign
        XCTAssertEqual(scanner.sanitizeMathString("15 — 5"), "15 - 5")
        XCTAssertEqual(scanner.sanitizeMathString("20 – 10"), "20 - 10")
        XCTAssertEqual(scanner.sanitizeMathString("30 − 5"), "30 - 5")
    }
    
    func testSanitizeUnicodeVulgarFractions() {
        // Vulgar fractions replacement
        XCTAssertEqual(scanner.sanitizeMathString("½ + ¼"), "(1/2) + (1/4)")
        XCTAssertEqual(scanner.sanitizeMathString("¾ × 8"), "(3/4) * 8")
        XCTAssertEqual(scanner.sanitizeMathString("⅓ + ⅔"), "(1/3) + (2/3)")
        XCTAssertEqual(scanner.sanitizeMathString("⅕ + ⅖ + ⅗ + ⅘"), "(1/5) + (2/5) + (3/5) + (4/5)")
        XCTAssertEqual(scanner.sanitizeMathString("⅛ + ⅜ + ⅝ + ⅞"), "(1/8) + (3/8) + (5/8) + (7/8)")
        XCTAssertEqual(scanner.sanitizeMathString("⅑ + ⅒"), "(1/9) + (1/10)")
    }
    
    func testSanitizeMixedFractions() {
        // Mixed fractions: "3 1/2" -> "3 + 1/2"
        XCTAssertEqual(scanner.sanitizeMathString("3 1/2"), "3 + 1/2")
        XCTAssertEqual(scanner.sanitizeMathString("5 3/4"), "5 + 3/4")
        XCTAssertEqual(scanner.sanitizeMathString("1 1/4 + 2 1/2"), "1 + 1/4 + 2 + 1/2")
    }
    
    func testSanitizeSuperscriptPowers() {
        // Single digit superscripts
        XCTAssertEqual(scanner.sanitizeMathString("x²"), "x^2")
        XCTAssertEqual(scanner.sanitizeMathString("5² + 2³"), "5^2 + 2^3")
        XCTAssertEqual(scanner.sanitizeMathString("10⁴"), "10^4")
        
        // Multi-digit superscripts: 2¹⁰ -> 2^10
        XCTAssertEqual(scanner.sanitizeMathString("2¹⁰"), "2^10")
        
        // Signed superscripts: 10⁻² -> 10^-2
        XCTAssertEqual(scanner.sanitizeMathString("10⁻²"), "10^-2")
        XCTAssertEqual(scanner.sanitizeMathString("2⁺³"), "2^+3")
    }
    
    func testSanitizeRootsAndConstants() {
        // Square root symbol
        XCTAssertEqual(scanner.sanitizeMathString("√144"), "sqrt144")
        XCTAssertEqual(scanner.sanitizeMathString("√25 + √16"), "sqrt25 + sqrt16")
        
        // Cube root symbol
        XCTAssertEqual(scanner.sanitizeMathString("∛27"), "cbrt27")
        
        // Pi symbol
        XCTAssertEqual(scanner.sanitizeMathString("2π"), "2pi")
    }
    
    // =========================================================================
    // MARK: - SECTION 2: Multi-Currency Receipt Detection & Parsing
    // =========================================================================
    
    func testUSDReceiptParsingWithSummaryFiltering() {
        let observations = [
            ScannedTextObservation(rawText: "Blue Bottle Coffee", sanitizedExpression: "Blue Bottle Coffee", boundingBox: .zero, confidence: 0.99),
            ScannedTextObservation(rawText: "1. Avocado Toast $14.50", sanitizedExpression: "1. Avocado Toast 14.50", boundingBox: .zero, confidence: 0.98),
            ScannedTextObservation(rawText: "2. Iced Matcha Latte $6.75", sanitizedExpression: "2. Iced Matcha Latte 6.75", boundingBox: .zero, confidence: 0.98),
            ScannedTextObservation(rawText: "3. Almond Croissant $4.25", sanitizedExpression: "3. Almond Croissant 4.25", boundingBox: .zero, confidence: 0.97),
            ScannedTextObservation(rawText: "Subtotal $25.50", sanitizedExpression: "Subtotal 25.50", boundingBox: .zero, confidence: 0.96),
            ScannedTextObservation(rawText: "Tax $2.27", sanitizedExpression: "Tax 2.27", boundingBox: .zero, confidence: 0.95),
            ScannedTextObservation(rawText: "Tip $4.50", sanitizedExpression: "Tip 4.50", boundingBox: .zero, confidence: 0.94),
            ScannedTextObservation(rawText: "Total $32.27", sanitizedExpression: "Total 32.27", boundingBox: .zero, confidence: 0.99),
            ScannedTextObservation(rawText: "Thank you for dining with us!", sanitizedExpression: "Thank you for dining with us!", boundingBox: .zero, confidence: 0.9)
        ]
        
        let result = scanner.parseReceipt(from: observations)
        
        XCTAssertEqual(result.detectedCurrency, .usd)
        XCTAssertEqual(result.items.count, 3, "Subtotal, Tax, Tip, Total, and Header noise must be filtered out")
        
        XCTAssertEqual(result.items[0].title, "Avocado Toast")
        XCTAssertEqual(result.items[0].amount, 14.50)
        
        XCTAssertEqual(result.items[1].title, "Iced Matcha Latte")
        XCTAssertEqual(result.items[1].amount, 6.75)
        
        XCTAssertEqual(result.items[2].title, "Almond Croissant")
        XCTAssertEqual(result.items[2].amount, 4.25)
        
        XCTAssertEqual(result.detectedSubtotal, 25.50)
        XCTAssertEqual(result.detectedTax, 2.27)
        XCTAssertEqual(result.detectedTotal, 32.27)
    }
    
    func testEURReceiptParsingWithEuropeanCommas() {
        let observations = [
            ScannedTextObservation(rawText: "Bistrot Parisien", sanitizedExpression: "Bistrot Parisien", boundingBox: .zero, confidence: 0.95),
            ScannedTextObservation(rawText: "Steak Frites 18,50 €", sanitizedExpression: "Steak Frites 18.50", boundingBox: .zero, confidence: 0.97),
            ScannedTextObservation(rawText: "Verre Bordeaux 6,50 €", sanitizedExpression: "Verre Bordeaux 6.50", boundingBox: .zero, confidence: 0.98),
            ScannedTextObservation(rawText: "Crème Brûlée 7,00 €", sanitizedExpression: "Crème Brûlée 7.00", boundingBox: .zero, confidence: 0.96),
            ScannedTextObservation(rawText: "Sous-total 32,00 €", sanitizedExpression: "Sous-total 32.00", boundingBox: .zero, confidence: 0.95),
            ScannedTextObservation(rawText: "TVA (10%) 3,20 €", sanitizedExpression: "TVA 3.20", boundingBox: .zero, confidence: 0.94),
            ScannedTextObservation(rawText: "Total TTC 35,20 €", sanitizedExpression: "Total TTC 35.20", boundingBox: .zero, confidence: 0.99)
        ]
        
        let result = scanner.parseReceipt(from: observations)
        
        XCTAssertEqual(result.detectedCurrency, .eur)
        XCTAssertEqual(result.items.count, 3)
        XCTAssertEqual(result.items[0].title, "Steak Frites")
        XCTAssertEqual(result.items[0].amount, 18.50)
        XCTAssertEqual(result.items[1].title, "Verre Bordeaux")
        XCTAssertEqual(result.items[1].amount, 6.50)
        XCTAssertEqual(result.items[2].title, "Crème Brûlée")
        XCTAssertEqual(result.items[2].amount, 7.00)
        XCTAssertEqual(result.detectedSubtotal, 32.00)
        XCTAssertEqual(result.detectedTax, 3.20)
        XCTAssertEqual(result.detectedTotal, 35.20)
    }
    
    func testMADMoroccanDirhamReceiptParsing() {
        let observations = [
            ScannedTextObservation(rawText: "Café Maure Marrakech", sanitizedExpression: "Café Maure Marrakech", boundingBox: .zero, confidence: 0.9),
            ScannedTextObservation(rawText: "Tajine Poulet Citron 85 MAD", sanitizedExpression: "Tajine Poulet Citron 85", boundingBox: .zero, confidence: 0.95),
            ScannedTextObservation(rawText: "Thé à la Menthe 20 DH", sanitizedExpression: "Thé à la Menthe 20", boundingBox: .zero, confidence: 0.96),
            ScannedTextObservation(rawText: "Pâtisserie Marocaine 45 Dhs", sanitizedExpression: "Pâtisserie Marocaine 45", boundingBox: .zero, confidence: 0.94),
            ScannedTextObservation(rawText: "Total à payer 150 MAD", sanitizedExpression: "Total à payer 150", boundingBox: .zero, confidence: 0.99)
        ]
        
        let result = scanner.parseReceipt(from: observations)
        
        XCTAssertEqual(result.detectedCurrency, .mad)
        XCTAssertEqual(result.items.count, 3)
        XCTAssertEqual(result.items[0].amount, 85.0)
        XCTAssertEqual(result.items[1].amount, 20.0)
        XCTAssertEqual(result.items[2].amount, 45.0)
        XCTAssertEqual(result.detectedTotal, 150.0)
    }
    
    func testGBPBritishPoundReceiptParsing() {
        let observations = [
            ScannedTextObservation(rawText: "London Gastropub", sanitizedExpression: "London Gastropub", boundingBox: .zero, confidence: 0.9),
            ScannedTextObservation(rawText: "Fish & Chips £14.95", sanitizedExpression: "Fish & Chips 14.95", boundingBox: .zero, confidence: 0.98),
            ScannedTextObservation(rawText: "Pint of Ale £5.50", sanitizedExpression: "Pint of Ale 5.50", boundingBox: .zero, confidence: 0.97),
            ScannedTextObservation(rawText: "Total £20.45", sanitizedExpression: "Total 20.45", boundingBox: .zero, confidence: 0.99)
        ]
        
        let result = scanner.parseReceipt(from: observations)
        XCTAssertEqual(result.detectedCurrency, .gbp)
        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.items[0].amount, 14.95)
        XCTAssertEqual(result.items[1].amount, 5.50)
    }
    
    func testJPYJapaneseYenReceiptParsing() {
        let observations = [
            ScannedTextObservation(rawText: "Ramen Ichiran Tokyo", sanitizedExpression: "Ramen Ichiran Tokyo", boundingBox: .zero, confidence: 0.95),
            ScannedTextObservation(rawText: "Tonkotsu Ramen ¥1100", sanitizedExpression: "Tonkotsu Ramen 1100", boundingBox: .zero, confidence: 0.98),
            ScannedTextObservation(rawText: "Gyoza (5 pcs) ¥450", sanitizedExpression: "Gyoza 450", boundingBox: .zero, confidence: 0.97),
            ScannedTextObservation(rawText: "Total ¥1550", sanitizedExpression: "Total 1550", boundingBox: .zero, confidence: 0.99)
        ]
        
        let result = scanner.parseReceipt(from: observations)
        XCTAssertEqual(result.detectedCurrency, .jpy)
        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.items[0].amount, 1100.0)
        XCTAssertEqual(result.items[1].amount, 450.0)
    }
    
    func testCHFSwissFrancReceiptParsing() {
        let observations = [
            ScannedTextObservation(rawText: "Zürich Café", sanitizedExpression: "Zürich Café", boundingBox: .zero, confidence: 0.9),
            ScannedTextObservation(rawText: "Fondue Portion CHF 28.50", sanitizedExpression: "Fondue Portion 28.50", boundingBox: .zero, confidence: 0.97),
            ScannedTextObservation(rawText: "Espresso CHF 4.80", sanitizedExpression: "Espresso 4.80", boundingBox: .zero, confidence: 0.96),
            ScannedTextObservation(rawText: "Total Due CHF 33.30", sanitizedExpression: "Total Due 33.30", boundingBox: .zero, confidence: 0.99)
        ]
        
        let result = scanner.parseReceipt(from: observations)
        XCTAssertEqual(result.detectedCurrency, .chf)
        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.items[0].amount, 28.50)
        XCTAssertEqual(result.items[1].amount, 4.80)
    }
    
    func testCADAndAUDReceiptParsing() {
        let cadObs = [
            ScannedTextObservation(rawText: "Poutine CA$ 12.50", sanitizedExpression: "Poutine 12.50", boundingBox: .zero, confidence: 0.98),
            ScannedTextObservation(rawText: "BeaverTail CA$ 7.25", sanitizedExpression: "BeaverTail 7.25", boundingBox: .zero, confidence: 0.98)
        ]
        let cadResult = scanner.parseReceipt(from: cadObs)
        XCTAssertEqual(cadResult.detectedCurrency, .cad)
        XCTAssertEqual(cadResult.items.count, 2)
        
        let audObs = [
            ScannedTextObservation(rawText: "Flat White A$ 4.50", sanitizedExpression: "Flat White 4.50", boundingBox: .zero, confidence: 0.98),
            ScannedTextObservation(rawText: "Avo on Toast A$ 16.00", sanitizedExpression: "Avo on Toast 16.00", boundingBox: .zero, confidence: 0.98)
        ]
        let audResult = scanner.parseReceipt(from: audObs)
        XCTAssertEqual(audResult.detectedCurrency, .aud)
        XCTAssertEqual(audResult.items.count, 2)
    }
    
    func testEmptyAndNoiseOnlyReceipt() {
        let emptyResult = scanner.parseReceipt(from: [])
        XCTAssertEqual(emptyResult.items.count, 0)
        XCTAssertNil(emptyResult.detectedSubtotal)
        XCTAssertNil(emptyResult.detectedTotal)
        
        let noiseObs = [
            ScannedTextObservation(rawText: "Thank you for dining!", sanitizedExpression: "", boundingBox: .zero, confidence: 0.9),
            ScannedTextObservation(rawText: "Order #48921", sanitizedExpression: "", boundingBox: .zero, confidence: 0.8),
            ScannedTextObservation(rawText: "Visa ****5678 Approved", sanitizedExpression: "", boundingBox: .zero, confidence: 0.95)
        ]
        let noiseResult = scanner.parseReceipt(from: noiseObs)
        XCTAssertEqual(noiseResult.items.count, 0)
    }
}
