//
//  VisionMathScannerTests.swift
//  LiquidCalcTests
//
//  Created for LiquidCalc iOS 18+.
//

import XCTest
#if canImport(LiquidCalcCore)
@testable import LiquidCalcCore
#endif

final class VisionMathScannerTests: XCTestCase {
    
    func testSanitizeMathString() {
        let scanner = VisionMathScanner()
        
        // Trailing equals sign removal
        let s1 = scanner.sanitizeMathString("5 + 3 =")
        XCTAssertEqual(s1, "5 + 3")
        
        // Unicode multiplication and division
        let s2 = scanner.sanitizeMathString("10 × 4 ÷ 2")
        XCTAssertEqual(s2, "10 * 4 / 2")
        
        // Lowercase 'x' as multiplication between numbers
        let s3 = scanner.sanitizeMathString("6x7")
        XCTAssertEqual(s3, "6 * 7")
        
        // Square root symbol
        let s4 = scanner.sanitizeMathString("√144")
        XCTAssertEqual(s4, "sqrt144")
        
        // Em-dash / En-dash
        let s5 = scanner.sanitizeMathString("15 — 5")
        XCTAssertEqual(s5, "15 - 5")
    }
    
    func testParseReceiptItems() {
        let scanner = VisionMathScanner()
        
        let observations = [
            ScannedTextObservation(
                rawText: "Avocado Toast $14.50",
                sanitizedExpression: "Avocado Toast 14.50",
                boundingBox: .zero,
                confidence: 0.95
            ),
            ScannedTextObservation(
                rawText: "Iced Matcha Latte $6.75",
                sanitizedExpression: "Iced Matcha Latte 6.75",
                boundingBox: .zero,
                confidence: 0.98
            ),
            ScannedTextObservation(
                rawText: "Thank you for dining!",
                sanitizedExpression: "Thank you for dining!",
                boundingBox: .zero,
                confidence: 0.9
            )
        ]
        
        let items = scanner.parseReceiptItems(from: observations)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].amount, 14.50)
        XCTAssertEqual(items[1].amount, 6.75)
        
        let subtotal = items.reduce(0.0) { $0 + $1.amount }
        XCTAssertEqual(subtotal, 21.25, accuracy: 1e-6)
    }
}
