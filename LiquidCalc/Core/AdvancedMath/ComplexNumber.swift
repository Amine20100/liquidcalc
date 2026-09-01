//
//  ComplexNumber.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Complex Number (ℂ) Engine: Arithmetic, Polar/Cartesian, Euler's Formula & Transcendental Functions
//

import Foundation
#if canImport(Darwin)
import Darwin
#endif

public struct ComplexNumber: Equatable, Sendable, CustomStringConvertible {
    public let real: Double
    public let imag: Double
    
    public init(real: Double, imag: Double = 0.0) {
        self.real = real
        self.imag = imag
    }
    
    public init(magnitude r: Double, phase theta: Double) {
        self.real = r * Foundation.cos(theta)
        self.imag = r * Foundation.sin(theta)
    }
    
    public static let zero = ComplexNumber(real: 0, imag: 0)
    public static let one = ComplexNumber(real: 1, imag: 0)
    public static let i = ComplexNumber(real: 0, imag: 1)
    
    // MARK: - Properties
    
    public var magnitude: Double {
        hypot(real, imag)
    }
    
    public var phase: Double {
        atan2(imag, real)
    }
    
    public var conjugate: ComplexNumber {
        ComplexNumber(real: real, imag: -imag)
    }
    
    public var description: String {
        if abs(imag) < 1e-12 {
            return String(format: "%.4g", real)
        } else if abs(real) < 1e-12 {
            return abs(imag - 1.0) < 1e-12 ? "i" : (abs(imag + 1.0) < 1e-12 ? "-i" : String(format: "%.4gi", imag))
        } else {
            let sign = imag >= 0 ? "+" : "-"
            let imagAbs = abs(imag)
            let imagStr = abs(imagAbs - 1.0) < 1e-12 ? "i" : String(format: "%.4gi", imagAbs)
            return String(format: "%.4g %@ %@", real, sign, imagStr)
        }
    }
    
    public var polarDescription: String {
        let r = magnitude
        let thetaDeg = phase * 180.0 / .pi
        return String(format: "%.4g ∠ %.2f°", r, thetaDeg)
    }
    
    // MARK: - Basic Arithmetic
    
    public static func + (lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        ComplexNumber(real: lhs.real + rhs.real, imag: lhs.imag + rhs.imag)
    }
    
    public static func - (lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        ComplexNumber(real: lhs.real - rhs.real, imag: lhs.imag - rhs.imag)
    }
    
    public static func * (lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        ComplexNumber(
            real: lhs.real * rhs.real - lhs.imag * rhs.imag,
            imag: lhs.real * rhs.imag + lhs.imag * rhs.real
        )
    }
    
    public static func / (lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        let denom = rhs.real * rhs.real + rhs.imag * rhs.imag
        guard denom > 1e-15 else { return .zero }
        return ComplexNumber(
            real: (lhs.real * rhs.real + lhs.imag * rhs.imag) / denom,
            imag: (lhs.imag * rhs.real - lhs.real * rhs.imag) / denom
        )
    }
    
    // MARK: - Advanced Powers & Roots: zⁿ, √z
    
    public func power(_ exponent: Double) -> ComplexNumber {
        let r = magnitude
        let theta = phase
        let newR = pow(r, exponent)
        let newTheta = theta * exponent
        return ComplexNumber(magnitude: newR, phase: newTheta)
    }
    
    public func sqrt() -> ComplexNumber {
        power(0.5)
    }
    
    // MARK: - Transcendental Functions: eᶻ, ln(z), sin(z), cos(z)
    
    public func exp() -> ComplexNumber {
        let expReal = Foundation.exp(real)
        return ComplexNumber(real: expReal * Foundation.cos(imag), imag: expReal * Foundation.sin(imag))
    }
    
    public func log() -> ComplexNumber {
        ComplexNumber(real: Foundation.log(magnitude), imag: phase)
    }
    
    public func sin() -> ComplexNumber {
        // sin(a + bi) = sin(a)cosh(b) + i*cos(a)sinh(b)
        ComplexNumber(real: Foundation.sin(real) * Foundation.cosh(imag), imag: Foundation.cos(real) * Foundation.sinh(imag))
    }
    
    public func cos() -> ComplexNumber {
        // cos(a + bi) = cos(a)cosh(b) - i*sin(a)sinh(b)
        ComplexNumber(real: Foundation.cos(real) * Foundation.cosh(imag), imag: -Foundation.sin(real) * Foundation.sinh(imag))
    }
}
