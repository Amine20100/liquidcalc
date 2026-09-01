//
//  NumberTheoryEngine.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Number Theory Engine: Prime Factorization, GCD, LCM, Primality Testing & Modular Arithmetic
//

import Foundation

public struct PrimeFactor: Equatable, Sendable, CustomStringConvertible {
    public let prime: Int64
    public let exponent: Int
    
    public var description: String {
        exponent > 1 ? "\(prime)^\(exponent)" : "\(prime)"
    }
}

public final class NumberTheoryEngine: Sendable {
    
    public static let shared = NumberTheoryEngine()
    
    public init() {}
    
    // MARK: - Greatest Common Divisor (Euclidean Algorithm)
    
    public func gcd(_ a: Int64, _ b: Int64) -> Int64 {
        var x = abs(a)
        var y = abs(b)
        while y != 0 {
            let temp = y
            y = x % y
            x = temp
        }
        return x
    }
    
    // MARK: - Least Common Multiple
    
    public func lcm(_ a: Int64, _ b: Int64) -> Int64 {
        guard a != 0 && b != 0 else { return 0 }
        return abs(a / gcd(a, b)) * abs(b)
    }
    
    // MARK: - Prime Factorization
    
    public func primeFactorization(of n: Int64) -> [PrimeFactor] {
        var num = abs(n)
        guard num > 1 else { return [] }
        
        var factors: [PrimeFactor] = []
        
        // Check factor 2
        var count2 = 0
        while num % 2 == 0 {
            count2 += 1
            num /= 2
        }
        if count2 > 0 {
            factors.append(PrimeFactor(prime: 2, exponent: count2))
        }
        
        // Check odd factors up to sqrt(num)
        var d: Int64 = 3
        while d * d <= num {
            var count = 0
            while num % d == 0 {
                count += 1
                num /= d
            }
            if count > 0 {
                factors.append(PrimeFactor(prime: d, exponent: count))
            }
            d += 2
        }
        
        if num > 1 {
            factors.append(PrimeFactor(prime: num, exponent: 1))
        }
        
        return factors
    }
    
    // MARK: - Deterministic & Probabilistic Primality Test (Miller-Rabin)
    
    public func isPrime(_ n: Int64) -> Bool {
        guard n > 1 else { return false }
        if n == 2 || n == 3 || n == 5 || n == 7 { return true }
        if n % 2 == 0 || n % 3 == 0 || n % 5 == 0 || n % 7 == 0 { return false }
        
        // Decompose n - 1 = 2^s * d
        var d = n - 1
        var s = 0
        while d % 2 == 0 {
            d /= 2
            s += 1
        }
        
        // Bases for 64-bit deterministic testing
        let bases: [Int64] = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]
        for a in bases {
            if a >= n { continue }
            if !millerRabinTest(n: n, a: a, d: d, s: s) {
                return false
            }
        }
        return true
    }
    
    private func millerRabinTest(n: Int64, a: Int64, d: Int64, s: Int) -> Bool {
        var x = modPow(base: a, exp: d, mod: n)
        if x == 1 || x == n - 1 { return true }
        
        for _ in 1..<s {
            x = modMul(x, x, n)
            if x == n - 1 { return true }
            if x == 1 { return false }
        }
        return false
    }
    
    // MARK: - Modular Exponentiation: (base^exp) % mod
    
    public func modPow(base: Int64, exp: Int64, mod: Int64) -> Int64 {
        guard mod > 1 else { return 0 }
        var result: Int64 = 1
        var b = base % mod
        var e = exp
        
        while e > 0 {
            if e % 2 == 1 {
                result = modMul(result, b, mod)
            }
            e /= 2
            b = modMul(b, b, mod)
        }
        return result
    }
    
    private func modMul(_ a: Int64, _ b: Int64, _ m: Int64) -> Int64 {
        var res: Int64 = 0
        var tempA = (a % m + m) % m
        var tempB = (b % m + m) % m
        while tempB > 0 {
            if tempB % 2 == 1 {
                res = (res + tempA) % m
            }
            tempA = (tempA * 2) % m
            tempB /= 2
        }
        return res
    }
}
