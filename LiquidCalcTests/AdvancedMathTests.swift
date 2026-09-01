//
//  AdvancedMathTests.swift
//  LiquidCalcTests
//
//  Created for LiquidCalc iOS 18+.
//  Unit Test Suite for Advanced Mathematics Engine
//

import XCTest
@testable import LiquidCalc

final class AdvancedMathTests: XCTestCase {
    
    // MARK: - Algebraic Solver Tests
    
    func testLinearEquation() {
        let solver = AlgebraicSolver.shared
        // 2x + 4 = 10 => x = 3
        let result = solver.solveLinear(a: 2, b: 4, c: 10)
        XCTAssertNotNil(result.x)
        XCTAssertEqual(result.x!, 3.0, accuracy: 1e-6)
    }
    
    func testQuadraticRealRoots() {
        let solver = AlgebraicSolver.shared
        // x² - 5x + 6 = 0 => roots 3 and 2
        let sol = solver.solveQuadratic(a: 1, b: -5, c: 6)
        XCTAssertNotNil(sol)
        XCTAssertFalse(sol!.isComplex)
        XCTAssertEqual(sol!.root1Real, 3.0, accuracy: 1e-6)
        XCTAssertEqual(sol!.root2Real, 2.0, accuracy: 1e-6)
    }
    
    func testQuadraticComplexRoots() {
        let solver = AlgebraicSolver.shared
        // x² + 4 = 0 => ±2i
        let sol = solver.solveQuadratic(a: 1, b: 0, c: 4)
        XCTAssertNotNil(sol)
        XCTAssertTrue(sol!.isComplex)
        XCTAssertEqual(sol!.root1Real, 0.0, accuracy: 1e-6)
        XCTAssertEqual(sol!.root1Imag, 2.0, accuracy: 1e-6)
    }
    
    func testLinearSystem() {
        let solver = AlgebraicSolver.shared
        // 2x + 3y = 8
        // 5x - y = 3
        // det = 2*(-1) - 5*3 = -17
        // x = 1, y = 2
        let sol = solver.solveLinearSystem(a1: 2, b1: 3, c1: 8, a2: 5, b2: -1, c2: 3)
        XCTAssertTrue(sol.isSolvable)
        XCTAssertEqual(sol.x, 1.0, accuracy: 1e-6)
        XCTAssertEqual(sol.y, 2.0, accuracy: 1e-6)
    }
    
    // MARK: - Calculus Engine Tests
    
    func testNumericalDerivative() {
        let calc = CalculusEngine.shared
        // f(x) = x³ => f'(2) = 12
        let d = calc.derivative(at: 2.0) { $0 * $0 * $0 }
        XCTAssertEqual(d, 12.0, accuracy: 1e-4)
    }
    
    func testDefiniteIntegral() {
        let calc = CalculusEngine.shared
        // ∫[0, 2] 3x² dx = [x³]₀² = 8
        let integ = calc.integrate(from: 0.0, to: 2.0) { 3.0 * $0 * $0 }
        XCTAssertEqual(integ, 8.0, accuracy: 1e-3)
    }
    
    // MARK: - Matrix Engine Tests
    
    func testMatrixDeterminantAndInverse() {
        let me = MatrixEngine.shared
        // A = [[4, 7], [2, 6]] => det(A) = 24 - 14 = 10
        let mat = Matrix([[4, 7], [2, 6]])
        let det = me.determinant(mat)
        XCTAssertNotNil(det)
        XCTAssertEqual(det!, 10.0, accuracy: 1e-6)
        
        let inv = me.inverse(mat)
        XCTAssertNotNil(inv)
        // A * A⁻¹ = I
        let prod = me.multiply(mat, inv!)
        XCTAssertNotNil(prod)
        XCTAssertEqual(prod![0, 0], 1.0, accuracy: 1e-5)
        XCTAssertEqual(prod![0, 1], 0.0, accuracy: 1e-5)
        XCTAssertEqual(prod![1, 0], 0.0, accuracy: 1e-5)
        XCTAssertEqual(prod![1, 1], 1.0, accuracy: 1e-5)
    }
    
    // MARK: - Complex Numbers Tests
    
    func testComplexArithmetic() {
        let z1 = ComplexNumber(real: 3, imag: 4)
        let z2 = ComplexNumber(real: 1, imag: -2)
        
        // z1 + z2 = 4 + 2i
        let add = z1 + z2
        XCTAssertEqual(add.real, 4.0, accuracy: 1e-6)
        XCTAssertEqual(add.imag, 2.0, accuracy: 1e-6)
        
        // |z1| = 5
        XCTAssertEqual(z1.magnitude, 5.0, accuracy: 1e-6)
        
        // z1 * z2 = (3+4i)(1-2i) = 3 - 6i + 4i + 8 = 11 - 2i
        let mul = z1 * z2
        XCTAssertEqual(mul.real, 11.0, accuracy: 1e-6)
        XCTAssertEqual(mul.imag, -2.0, accuracy: 1e-6)
    }
    
    // MARK: - Statistics Tests
    
    func testDescriptiveStatistics() {
        let se = StatisticsEngine.shared
        let data = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
        let stats = se.calculateStats(for: data)
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats!.count, 8)
        XCTAssertEqual(stats!.mean, 5.0, accuracy: 1e-6)
        XCTAssertEqual(stats!.median, 4.5, accuracy: 1e-6)
        XCTAssertEqual(stats!.mode, [4.0])
    }
    
    func testLinearRegression() {
        let se = StatisticsEngine.shared
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [2.0, 4.0, 6.0, 8.0, 10.0]
        let reg = se.linearRegression(x: x, y: y)
        XCTAssertNotNil(reg)
        XCTAssertEqual(reg!.slope, 2.0, accuracy: 1e-6)
        XCTAssertEqual(reg!.intercept, 0.0, accuracy: 1e-6)
        XCTAssertEqual(reg!.correlationR, 1.0, accuracy: 1e-6)
    }
    
    // MARK: - Number Theory Tests
    
    func testGCDAndLCM() {
        let nt = NumberTheoryEngine.shared
        XCTAssertEqual(nt.gcd(48, 18), 6)
        XCTAssertEqual(nt.lcm(12, 18), 36)
    }
    
    func testPrimeFactorization() {
        let nt = NumberTheoryEngine.shared
        // 360 = 2³ * 3² * 5¹
        let factors = nt.primeFactorization(of: 360)
        XCTAssertEqual(factors.count, 3)
        XCTAssertEqual(factors[0].prime, 2)
        XCTAssertEqual(factors[0].exponent, 3)
        XCTAssertEqual(factors[1].prime, 3)
        XCTAssertEqual(factors[1].exponent, 2)
        XCTAssertEqual(factors[2].prime, 5)
        XCTAssertEqual(factors[2].exponent, 1)
    }
    
    func testPrimality() {
        let nt = NumberTheoryEngine.shared
        XCTAssertTrue(nt.isPrime(997))
        XCTAssertFalse(nt.isPrime(1000))
    }
}
