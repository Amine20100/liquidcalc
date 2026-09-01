//
//  AlgebraicSolver.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Advanced Symbolic & Algebraic Equation Solver
//

import Foundation

public struct QuadraticSolution: Equatable, Sendable {
    public let discriminant: Double
    public let root1Real: Double
    public let root1Imag: Double
    public let root2Real: Double
    public let root2Imag: Double
    public let isComplex: Bool
    public let vertexX: Double
    public let vertexY: Double
    public let steps: [String]
    
    public var root1String: String {
        if isComplex {
            let sign = root1Imag >= 0 ? "+" : "-"
            return String(format: "%.4g %@ %.4gi", root1Real, sign, abs(root1Imag))
        } else {
            return String(format: "%.6g", root1Real)
        }
    }
    
    public var root2String: String {
        if isComplex {
            let sign = root2Imag >= 0 ? "+" : "-"
            return String(format: "%.4g %@ %.4gi", root2Real, sign, abs(root2Imag))
        } else {
            return String(format: "%.6g", root2Real)
        }
    }
}

public struct LinearSystemSolution: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let determinant: Double
    public let isSolvable: Bool
    public let steps: [String]
}

public final class AlgebraicSolver: Sendable {
    
    public static let shared = AlgebraicSolver()
    
    public init() {}
    
    // MARK: - Linear Equation: ax + b = c  =>  x = (c - b) / a
    
    public func solveLinear(a: Double, b: Double, c: Double) -> (x: Double?, steps: [String]) {
        var steps: [String] = []
        steps.append("Equation: \(formatNum(a))x + \(formatNum(b)) = \(formatNum(c))")
        
        guard abs(a) > 1e-12 else {
            if abs(b - c) < 1e-12 {
                steps.append("0x = 0 => Infinite solutions (Identity)")
                return (nil, steps)
            } else {
                steps.append("0x = \(formatNum(c - b)) => No solution (Contradiction)")
                return (nil, steps)
            }
        }
        
        let cMinusB = c - b
        steps.append("Subtract \(formatNum(b)) from both sides: \(formatNum(a))x = \(formatNum(cMinusB))")
        
        let x = cMinusB / a
        steps.append("Divide both sides by \(formatNum(a)): x = \(formatNum(x))")
        return (x, steps)
    }
    
    // MARK: - Quadratic Equation: ax² + bx + c = 0
    
    public func solveQuadratic(a: Double, b: Double, c: Double) -> QuadraticSolution? {
        guard abs(a) > 1e-12 else { return nil }
        
        var steps: [String] = []
        steps.append("Equation: \(formatNum(a))x² + \(formatNum(b))x + \(formatNum(c)) = 0")
        
        let disc = b * b - 4 * a * c
        steps.append("Discriminant Δ = b² - 4ac = (\(formatNum(b)))² - 4(\(formatNum(a)))(\(formatNum(c))) = \(formatNum(disc))")
        
        let vx = -b / (2 * a)
        let vy = c - (b * b) / (4 * a)
        steps.append("Parabola Vertex: (\(formatNum(vx)), \(formatNum(vy)))")
        
        if disc >= 0 {
            let sqrtDisc = sqrt(disc)
            let r1 = (-b + sqrtDisc) / (2 * a)
            let r2 = (-b - sqrtDisc) / (2 * a)
            
            if abs(disc) < 1e-12 {
                steps.append("Δ = 0 => One real double root: x = -b / 2a = \(formatNum(r1))")
            } else {
                steps.append("Δ > 0 => Two distinct real roots: x = (-b ± √Δ) / 2a")
                steps.append("x₁ = (\(formatNum(-b)) + \(formatNum(sqrtDisc))) / \(formatNum(2 * a)) = \(formatNum(r1))")
                steps.append("x₂ = (\(formatNum(-b)) - \(formatNum(sqrtDisc))) / \(formatNum(2 * a)) = \(formatNum(r2))")
            }
            
            return QuadraticSolution(
                discriminant: disc,
                root1Real: r1,
                root1Imag: 0,
                root2Real: r2,
                root2Imag: 0,
                isComplex: false,
                vertexX: vx,
                vertexY: vy,
                steps: steps
            )
        } else {
            let sqrtDisc = sqrt(-disc)
            let realPart = -b / (2 * a)
            let imagPart = sqrtDisc / (2 * a)
            
            steps.append("Δ < 0 => Two complex conjugate roots: x = (-b ± i√|Δ|) / 2a")
            steps.append("x₁ = \(formatNum(realPart)) + \(formatNum(abs(imagPart)))i")
            steps.append("x₂ = \(formatNum(realPart)) - \(formatNum(abs(imagPart)))i")
            
            return QuadraticSolution(
                discriminant: disc,
                root1Real: realPart,
                root1Imag: abs(imagPart),
                root2Real: realPart,
                root2Imag: -abs(imagPart),
                isComplex: true,
                vertexX: vx,
                vertexY: vy,
                steps: steps
            )
        }
    }
    
    // MARK: - 2x2 System of Linear Equations:
    // a1*x + b1*y = c1
    // a2*x + b2*y = c2
    
    public func solveLinearSystem(a1: Double, b1: Double, c1: Double, a2: Double, b2: Double, c2: Double) -> LinearSystemSolution {
        var steps: [String] = []
        steps.append("System:")
        steps.append("  [1] \(formatNum(a1))x + \(formatNum(b1))y = \(formatNum(c1))")
        steps.append("  [2] \(formatNum(a2))x + \(formatNum(b2))y = \(formatNum(c2))")
        
        let det = a1 * b2 - a2 * b1
        steps.append("Determinant D = (\(formatNum(a1)))(\(formatNum(b2))) - (\(formatNum(a2)))(\(formatNum(b1))) = \(formatNum(det))")
        
        guard abs(det) > 1e-12 else {
            steps.append("D = 0 => System is dependent (infinite solutions) or inconsistent (no solution).")
            return LinearSystemSolution(x: 0, y: 0, determinant: det, isSolvable: false, steps: steps)
        }
        
        let detX = c1 * b2 - c2 * b1
        let detY = a1 * c2 - a2 * c1
        
        steps.append("Dx = (\(formatNum(c1)))(\(formatNum(b2))) - (\(formatNum(c2)))(\(formatNum(b1))) = \(formatNum(detX))")
        steps.append("Dy = (\(formatNum(a1)))(\(formatNum(c2))) - (\(formatNum(a2)))(\(formatNum(c1))) = \(formatNum(detY))")
        
        let x = detX / det
        let y = detY / det
        
        steps.append("Cramer's Rule: x = Dx / D = \(formatNum(x)), y = Dy / D = \(formatNum(y))")
        
        return LinearSystemSolution(x: x, y: y, determinant: det, isSolvable: true, steps: steps)
    }
    
    private func formatNum(_ val: Double) -> String {
        if abs(val.rounded() - val) < 1e-9 {
            return String(format: "%.0f", val)
        } else {
            return String(format: "%.4g", val)
        }
    }
}
