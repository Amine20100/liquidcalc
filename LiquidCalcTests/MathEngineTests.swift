//
//  MathEngineTests.swift
//  LiquidCalcTests
//
//  Created for LiquidCalc iOS 18+.
//

import XCTest
#if canImport(LiquidCalcCore)
@testable import LiquidCalcCore
#endif

final class MathEngineTests: XCTestCase {
    
    func testStandardArithmeticPrecedence() throws {
        let evaluator = MathEvaluator()
        
        // 2 + 3 * 4 = 14 (not 20)
        let res1 = try evaluator.evaluate(expression: "2 + 3 * 4")
        XCTAssertEqual(res1, 14.0, accuracy: 1e-9)
        
        // (2 + 3) * 4 = 20
        let res2 = try evaluator.evaluate(expression: "(2 + 3) * 4")
        XCTAssertEqual(res2, 20.0, accuracy: 1e-9)
        
        // 10 - 2 + 3 = 11 (left-associative)
        let res3 = try evaluator.evaluate(expression: "10 - 2 + 3")
        XCTAssertEqual(res3, 11.0, accuracy: 1e-9)
        
        // 2 ^ 3 ^ 2 = 512 (right-associative: 2^(3^2) = 2^9 = 512)
        let res4 = try evaluator.evaluate(expression: "2 ^ 3 ^ 2")
        XCTAssertEqual(res4, 512.0, accuracy: 1e-9)
    }
    
    func testImplicitMultiplication() throws {
        let evaluator = MathEvaluator()
        
        // 2(3) = 6
        let res1 = try evaluator.evaluate(expression: "2(3)")
        XCTAssertEqual(res1, 6.0, accuracy: 1e-9)
        
        // 3(4 + 2) = 18
        let res2 = try evaluator.evaluate(expression: "3(4 + 2)")
        XCTAssertEqual(res2, 18.0, accuracy: 1e-9)
        
        // 2pi = 2 * Double.pi
        let res3 = try evaluator.evaluate(expression: "2pi")
        XCTAssertEqual(res3, 2 * Double.pi, accuracy: 1e-9)
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
        
        // sqrt(144) = 12
        let sqrtVal = try radEvaluator.evaluate(expression: "sqrt(144)")
        XCTAssertEqual(sqrtVal, 12.0, accuracy: 1e-9)
        
        // fact(5) = 120
        let factVal = try radEvaluator.evaluate(expression: "fact(5)")
        XCTAssertEqual(factVal, 120.0, accuracy: 1e-9)
    }
    
    func testDivisionByZero() {
        let evaluator = MathEvaluator()
        XCTAssertThrowsError(try evaluator.evaluate(expression: "5 / 0")) { error in
            XCTAssertEqual(error as? MathError, MathError.divisionByZero)
        }
    }
    
    func testNegativeSquareRoot() {
        let evaluator = MathEvaluator()
        XCTAssertThrowsError(try evaluator.evaluate(expression: "sqrt(-4)"))
    }
}
