//
//  MathError.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation

public enum MathError: LocalizedError, Equatable {
    case invalidNumber(String)
    case unexpectedToken(String)
    case mismatchedParentheses
    case unknownFunction(String)
    case divisionByZero
    case domainError(String)
    case emptyExpression
    case overflow
    
    public var errorDescription: String? {
        switch self {
        case .invalidNumber(let s):
            return "Invalid number: \(s)"
        case .unexpectedToken(let s):
            return "Unexpected symbol: \(s)"
        case .mismatchedParentheses:
            return "Mismatched parentheses"
        case .unknownFunction(let s):
            return "Unknown function: \(s)"
        case .divisionByZero:
            return "Cannot divide by zero"
        case .domainError(let s):
            return s
        case .emptyExpression:
            return "Empty expression"
        case .overflow:
            return "Overflow"
        }
    }
}
