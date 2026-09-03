//
//  MathEngineTests.swift
//  LiquidCalcTests
//
//  Created for LiquidCalc iOS 18+.
//  Comprehensive Unit Test Suite for Features F4 & F5: Advanced Math Engine & OCR Normalization
//  Covers Vulgar Fractions, Mixed Fractions, Superscript Powers, Postfix Percentages, Roots,
//  Implicit Multiplication, Operator Precedence, and Multi-Step Scientific Expressions.
//

import XCTest
#if canImport(LiquidCalc)
@testable import LiquidCalc
#elseif canImport(LiquidCalcCore)
@testable import LiquidCalcCore
#endif

final class MathEngineTests: XCTestCase {
    
    // =========================================================================
    // MARK: - SECTION 1: Standard Arithmetic Precedence & Associativity
    // =========================================================================
    
    func testStandardArithmeticPrecedence() throws {
        let evaluator = MathEvaluator()
        
        // 2 + 3 * 4 = 14 (multiplication before addition)
        let res1 = try evaluator.evaluate(expression: "2 + 3 * 4")
        XCTAssertEqual(res1, 14.0, accuracy: 1e-9)
        
        // (2 + 3) * 4 = 20 (parentheses override precedence)
        let res2 = try evaluator.evaluate(expression: "(2 + 3) * 4")
        XCTAssertEqual(res2, 20.0, accuracy: 1e-9)
        
        // 10 - 2 + 3 = 11 (left-associative)
        let res3 = try evaluator.evaluate(expression: "10 - 2 + 3")
        XCTAssertEqual(res3, 11.0, accuracy: 1e-9)
        
        // 2 ^ 3 ^ 2 = 512 (right-associative: 2^(3^2) = 2^9 = 512)
        let res4 = try evaluator.evaluate(expression: "2 ^ 3 ^ 2")
        XCTAssertEqual(res4, 512.0, accuracy: 1e-9)
        
        // 100 / 5 / 2 = 10 (left-associative division)
        let res5 = try evaluator.evaluate(expression: "100 / 5 / 2")
        XCTAssertEqual(res5, 10.0, accuracy: 1e-9)
    }
    
    func testImplicitMultiplication() throws {
        let evaluator = MathEvaluator()
        
        // 2(3) = 6
        let res1 = try evaluator.evaluate(expression: "2(3)")
        XCTAssertEqual(res1, 6.0, accuracy: 1e-9)
        
        // 3(4 + 2) = 18
        let res2 = try evaluator.evaluate(expression: "3(4 + 2)")
        XCTAssertEqual(res2, 18.0, accuracy: 1e-9)
        
        // (2 + 3)(4 + 1) = 25
        let res3 = try evaluator.evaluate(expression: "(2 + 3)(4 + 1)")
        XCTAssertEqual(res3, 25.0, accuracy: 1e-9)
        
        // 2pi = 2 * Double.pi
        let res4 = try evaluator.evaluate(expression: "2pi")
        XCTAssertEqual(res4, 2 * Double.pi, accuracy: 1e-9)
        
        // 5e = 5 * M_E
        let res5 = try evaluator.evaluate(expression: "5e")
        XCTAssertEqual(res5, 5 * M_E, accuracy: 1e-9)
    }
    
    // =========================================================================
    // MARK: - SECTION 2: Unicode Vulgar Fractions & Mixed Fractions
    // =========================================================================
    
    func testVulgarFractionsEvaluation() throws {
        let evaluator = MathEvaluator()
        
        // Halves: ½ = 0.5
        XCTAssertEqual(try evaluator.evaluate(expression: "½"), 0.5, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "½ + ½"), 1.0, accuracy: 1e-9)
        
        // Thirds: ⅓ = 1/3, ⅔ = 2/3
        XCTAssertEqual(try evaluator.evaluate(expression: "⅓"), 1.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "⅔"), 2.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "⅓ + ⅔"), 1.0, accuracy: 1e-9)
        
        // Fourths: ¼ = 0.25, ¾ = 0.75
        XCTAssertEqual(try evaluator.evaluate(expression: "¼"), 0.25, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "¾"), 0.75, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "¾ * 4"), 3.0, accuracy: 1e-9)
        
        // Fifths: ⅕, ⅖, ⅗, ⅘
        XCTAssertEqual(try evaluator.evaluate(expression: "⅕"), 0.2, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "⅖"), 0.4, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "⅗"), 0.6, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "⅘"), 0.8, accuracy: 1e-9)
        
        // Sixths: ⅙, ⅚
        XCTAssertEqual(try evaluator.evaluate(expression: "⅙"), 1.0 / 6.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "⅚"), 5.0 / 6.0, accuracy: 1e-9)
        
        // Eighths: ⅛, ⅜, ⅝, ⅞
        XCTAssertEqual(try evaluator.evaluate(expression: "⅛"), 0.125, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "⅜"), 0.375, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "⅝"), 0.625, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "⅞"), 0.875, accuracy: 1e-9)
        
        // Ninths & Tenths: ⅑, ⅒
        XCTAssertEqual(try evaluator.evaluate(expression: "⅑"), 1.0 / 9.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "⅒"), 0.1, accuracy: 1e-9)
    }
    
    func testMixedFractionsEvaluation() throws {
        let evaluator = MathEvaluator()
        
        // "3 1/2" = 3.5
        let res1 = try evaluator.evaluate(expression: "3 1/2")
        XCTAssertEqual(res1, 3.5, accuracy: 1e-9)
        
        // "5 3/4" = 5.75
        let res2 = try evaluator.evaluate(expression: "5 3/4")
        XCTAssertEqual(res2, 5.75, accuracy: 1e-9)
        
        // "1 1/4 + 2 1/2" = 1.25 + 2.5 = 3.75
        let res3 = try evaluator.evaluate(expression: "1 1/4 + 2 1/2")
        XCTAssertEqual(res3, 3.75, accuracy: 1e-9)
        
        // "10 1/2 * 2" = (10 + 0.5) * 2 = 21.0
        let res4 = try evaluator.evaluate(expression: "(10 1/2) * 2")
        XCTAssertEqual(res4, 21.0, accuracy: 1e-9)
    }
    
    // =========================================================================
    // MARK: - SECTION 3: Unicode Superscript Powers & Exponents
    // =========================================================================
    
    func testSuperscriptPowersEvaluation() throws {
        let evaluator = MathEvaluator()
        
        // Single digit superscripts: 2⁰, 2¹, 3², 4³, 2⁴, 2⁵, 2⁶, 2⁷, 2⁸, 2⁹
        XCTAssertEqual(try evaluator.evaluate(expression: "2⁰"), 1.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "2¹"), 2.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "3²"), 9.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "4³"), 64.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "2⁴"), 16.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "2⁵"), 32.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "2⁶"), 64.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "2⁷"), 128.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "2⁸"), 256.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "2⁹"), 512.0, accuracy: 1e-9)
        
        // Multi-digit superscripts: 2¹⁰ = 1024
        XCTAssertEqual(try evaluator.evaluate(expression: "2¹⁰"), 1024.0, accuracy: 1e-9)
        
        // Compound superscript expressions: 5³ + 2² = 125 + 4 = 129
        XCTAssertEqual(try evaluator.evaluate(expression: "5³ + 2²"), 129.0, accuracy: 1e-9)
        
        // Negative superscripts: 10⁻² = 0.01
        XCTAssertEqual(try evaluator.evaluate(expression: "10⁻²"), 0.01, accuracy: 1e-9)
    }
    
    // =========================================================================
    // MARK: - SECTION 4: Postfix Percentages & Percentage Arithmetic
    // =========================================================================
    
    func testPostfixPercentagesEvaluation() throws {
        let evaluator = MathEvaluator()
        
        // Standalone percentage: 50% = 0.5
        let p1 = try evaluator.evaluate(expression: "50%")
        XCTAssertEqual(p1, 0.5, accuracy: 1e-9)
        
        // 100% = 1.0, 0% = 0.0, 12.5% = 0.125
        XCTAssertEqual(try evaluator.evaluate(expression: "100%"), 1.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "0%"), 0.0, accuracy: 1e-9)
        XCTAssertEqual(try evaluator.evaluate(expression: "12.5%"), 0.125, accuracy: 1e-9)
        
        // Percentage addition: 25% + 75% = 0.25 + 0.75 = 1.0
        let p2 = try evaluator.evaluate(expression: "25% + 75%")
        XCTAssertEqual(p2, 1.0, accuracy: 1e-9)
        
        // Percentage multiplication: 50% * 200 = 0.5 * 200 = 100
        let p3 = try evaluator.evaluate(expression: "50% * 200")
        XCTAssertEqual(p3, 100.0, accuracy: 1e-9)
        
        // 200 * 15% = 30.0
        let p4 = try evaluator.evaluate(expression: "200 * 15%")
        XCTAssertEqual(p4, 30.0, accuracy: 1e-9)
        
        // 100 + 10% = 100 + 0.10 = 100.10
        let p5 = try evaluator.evaluate(expression: "100 + 10%")
        XCTAssertEqual(p5, 100.10, accuracy: 1e-9)
    }
    
    // =========================================================================
    // MARK: - SECTION 5: Roots, Powers & Constants
    // =========================================================================
    
    func testRootSymbolsAndFunctions() throws {
        let evaluator = MathEvaluator()
        
        // Square root symbol: √144 = 12
        let sqrt1 = try evaluator.evaluate(expression: "√144")
        XCTAssertEqual(sqrt1, 12.0, accuracy: 1e-9)
        
        // √25 + √16 = 5 + 4 = 9
        let sqrt2 = try evaluator.evaluate(expression: "√25 + √16")
        XCTAssertEqual(sqrt2, 9.0, accuracy: 1e-9)
        
        // √(9 + 16) = √25 = 5
        let sqrt3 = try evaluator.evaluate(expression: "√(9 + 16)")
        XCTAssertEqual(sqrt3, 5.0, accuracy: 1e-9)
        
        // Cube root symbol: ∛27 = 3
        let cbrt1 = try evaluator.evaluate(expression: "∛27")
        XCTAssertEqual(cbrt1, 3.0, accuracy: 1e-9)
        
        // ∛125 = 5
        let cbrt2 = try evaluator.evaluate(expression: "∛125")
        XCTAssertEqual(cbrt2, 5.0, accuracy: 1e-9)
        
        // Binary Modulo
        let modRes = try evaluator.evaluate(expression: "10 mod 3")
        XCTAssertEqual(modRes, 1.0, accuracy: 1e-9)
    }
    
    func testScientificFunctions() throws {
        let degEvaluator = MathEvaluator(angleUnit: .degrees)
        
        // sin(30) in degrees = 0.5
        let sin30 = try degEvaluator.evaluate(expression: "sin(30)")
        XCTAssertEqual(sin30, 0.5, accuracy: 1e-6)
        
        // cos(60) in degrees = 0.5
        let cos60 = try degEvaluator.evaluate(expression: "cos(60)")
        XCTAssertEqual(cos60, 0.5, accuracy: 1e-6)
        
        // tan(45) in degrees = 1.0
        let tan45 = try degEvaluator.evaluate(expression: "tan(45)")
        XCTAssertEqual(tan45, 1.0, accuracy: 1e-6)
        
        let radEvaluator = MathEvaluator(angleUnit: .radians)
        // ln(e) = 1
        let lne = try radEvaluator.evaluate(expression: "ln(e)")
        XCTAssertEqual(lne, 1.0, accuracy: 1e-9)
        
        // log10(1000) = 3
        let log1k = try radEvaluator.evaluate(expression: "log(1000)")
        XCTAssertEqual(log1k, 3.0, accuracy: 1e-9)
        
        // fact(5) = 120
        let factVal = try radEvaluator.evaluate(expression: "fact(5)")
        XCTAssertEqual(factVal, 120.0, accuracy: 1e-9)
        
        // inv(4) = 0.25
        let invVal = try radEvaluator.evaluate(expression: "inv(4)")
        XCTAssertEqual(invVal, 0.25, accuracy: 1e-9)
    }
    
    // =========================================================================
    // MARK: - SECTION 6: Multi-Step Expressions & Error Handling
    // =========================================================================
    
    func testMultiStepComplexExpressions() throws {
        let evaluator = MathEvaluator(angleUnit: .degrees)
        
        // (3 + 5) * 2^3 - √64 / 2 = 8 * 8 - 8 / 2 = 64 - 4 = 60
        let complex1 = try evaluator.evaluate(expression: "(3 + 5) * 2^3 - √64 / 2")
        XCTAssertEqual(complex1, 60.0, accuracy: 1e-9)
        
        // 100 * (1 + 0.05)² = 100 * 1.1025 = 110.25
        let complex2 = try evaluator.evaluate(expression: "100 * (1 + 0.05)²")
        XCTAssertEqual(complex2, 110.25, accuracy: 1e-9)
        
        // sin(30)² + cos(30)² = 0.25 + 0.75 = 1.0
        let trigIdentity = try evaluator.evaluate(expression: "sin(30)² + cos(30)²")
        XCTAssertEqual(trigIdentity, 1.0, accuracy: 1e-6)
    }
    
    func testDivisionByZeroAndDomainErrors() {
        let evaluator = MathEvaluator()
        
        // Division by zero
        XCTAssertThrowsError(try evaluator.evaluate(expression: "5 / 0")) { error in
            XCTAssertEqual(error as? MathError, MathError.divisionByZero)
        }
        
        // Negative square root
        XCTAssertThrowsError(try evaluator.evaluate(expression: "sqrt(-4)"))
        
        // Factorial of negative number
        XCTAssertThrowsError(try evaluator.evaluate(expression: "fact(-1)"))
        
        // Mismatched parentheses
        XCTAssertThrowsError(try evaluator.evaluate(expression: "((2 + 3)"))
        
        // Empty expression
        XCTAssertThrowsError(try evaluator.evaluate(expression: ""))
    }
}
