//
//  CalculusEngine.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Numerical Calculus Engine: Derivatives, Integrals, Limits, Series Summation & Products
//

import Foundation

public final class CalculusEngine: Sendable {
    
    public static let shared = CalculusEngine()
    
    public init() {}
    
    // MARK: - Numerical Differentiation (5-Point Central Difference Stencil)
    // f'(x) ≈ (-f(x+2h) + 8f(x+h) - 8f(x-h) + f(x-2h)) / (12h)
    
    public func derivative(at x: Double, step: Double = 1e-5, function: @Sendable (Double) -> Double) -> Double {
        let h = max(1e-7, min(step, 1e-3))
        let f_p2 = function(x + 2 * h)
        let f_p1 = function(x + h)
        let f_m1 = function(x - h)
        let f_m2 = function(x - 2 * h)
        
        return (-f_p2 + 8 * f_p1 - 8 * f_m1 + f_m2) / (12 * h)
    }
    
    // MARK: - Second Derivative f''(x)
    // f''(x) ≈ (-f(x+2h) + 16f(x+h) - 30f(x) + 16f(x-h) - f(x-2h)) / (12h²)
    
    public func secondDerivative(at x: Double, step: Double = 1e-4, function: @Sendable (Double) -> Double) -> Double {
        let h = step
        let fx = function(x)
        let f_p2 = function(x + 2 * h)
        let f_p1 = function(x + h)
        let f_m1 = function(x - h)
        let f_m2 = function(x - 2 * h)
        
        return (-f_p2 + 16 * f_p1 - 30 * fx + 16 * f_m1 - f_m2) / (12 * h * h)
    }
    
    // MARK: - Definite Integral (Adaptive Composite Simpson's 3/8 Rule)
    // ∫[a, b] f(x) dx
    
    public func integrate(from a: Double, to b: Double, intervals: Int = 1000, function: @Sendable (Double) -> Double) -> Double {
        guard a != b else { return 0.0 }
        
        // Ensure even number of subintervals for Simpson's 1/3 rule
        let n = max(100, (intervals % 2 == 0) ? intervals : intervals + 1)
        let h = (b - a) / Double(n)
        
        var sum = function(a) + function(b)
        
        for i in 1..<n {
            let x = a + Double(i) * h
            let weight = (i % 2 == 0) ? 2.0 : 4.0
            let fx = function(x)
            if fx.isFinite {
                sum += weight * fx
            }
        }
        
        return (h / 3.0) * sum
    }
    
    // MARK: - Two-Sided Limit Approximation: lim(x -> a) f(x)
    
    public func limit(approaching a: Double, delta: Double = 1e-7, function: @Sendable (Double) -> Double) -> (left: Double, right: Double, twoSided: Double?) {
        let leftVal = function(a - delta)
        let rightVal = function(a + delta)
        
        let diff = abs(leftVal - rightVal)
        let twoSided: Double? = (diff < 1e-3 && leftVal.isFinite && rightVal.isFinite) ? ((leftVal + rightVal) / 2.0) : nil
        
        return (left: leftVal, right: rightVal, twoSided: twoSided)
    }
    
    // MARK: - Discrete Summation: ∑[n=start...end] f(n)
    
    public func sum(from start: Int, to end: Int, formula: (Int) -> Double) -> Double {
        guard start <= end else { return 0.0 }
        var total = 0.0
        for n in start...end {
            total += formula(n)
        }
        return total
    }
    
    // MARK: - Discrete Product: ∏[n=start...end] f(n)
    
    public func product(from start: Int, to end: Int, formula: (Int) -> Double) -> Double {
        guard start <= end else { return 1.0 }
        var total = 1.0
        for n in start...end {
            total *= formula(n)
        }
        return total
    }
}
