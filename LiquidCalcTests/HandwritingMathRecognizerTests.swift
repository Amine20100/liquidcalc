//
//  HandwritingMathRecognizerTests.swift
//  LiquidCalcTests
//
//  Created for LiquidCalc iOS 18+.
//  Unit Test Suite for Draw Calc & Handwriting Math Recognition Engine
//

import XCTest
#if canImport(LiquidCalc)
@testable import LiquidCalc
#elseif canImport(LiquidCalcCore)
@testable import LiquidCalcCore
#endif

final class HandwritingMathRecognizerTests: XCTestCase {
    
    private var recognizer: HandwritingMathRecognizer!
    
    override func setUp() {
        super.setUp()
        recognizer = HandwritingMathRecognizer()
    }
    
    override func tearDown() {
        recognizer = nil
        super.tearDown()
    }
    
    func testSolveHandwrittenArithmetic() {
        // "15 * 4 + 8" -> 68
        let sol = recognizer.solveExpression("15 * 4 + 8")
        XCTAssertEqual(sol, "68")
    }
    
    func testSolveHandwrittenWithTrailingEquals() {
        // "120 / 4 + 10 =" -> 40
        let sol = recognizer.solveExpression("120 / 4 + 10 =")
        XCTAssertEqual(sol, "40")
    }
    
    func testSolveHandwrittenFractions() {
        // "(1/2) + (3/4)" -> 1.25
        let sol = recognizer.solveExpression("(1/2) + (3/4)")
        XCTAssertEqual(sol, "1.25")
    }
    
    func testSolveHandwrittenLinearEquation() {
        // "2x + 5 = 15" -> "x = 5"
        let sol = recognizer.solveExpression("2x + 5 = 15")
        XCTAssertEqual(sol, "x = 5")
    }
    
    func testSolveHandwrittenRootsAndPowers() {
        // "sqrt(64) + 2^3" -> 16
        let sol = recognizer.solveExpression("sqrt(64) + 2^3")
        XCTAssertEqual(sol, "16")
    }
}
