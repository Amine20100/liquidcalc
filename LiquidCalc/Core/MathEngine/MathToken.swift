//
//  MathToken.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation

public enum MathToken: Equatable {
    case number(Double)
    case constant(String, Double)
    case binaryOp(String)
    case unaryOp(String)
    case function(String)
    case leftParen
    case rightParen
    case comma
    
    public var precedence: Int {
        switch self {
        case .binaryOp(let op):
            switch op {
            case "+", "-": return 1
            case "*", "/", "%", "×", "÷": return 2
            case "^": return 4
            default: return 0
            }
        case .unaryOp:
            return 3
        case .function:
            return 5
        default:
            return 0
        }
    }
    
    public var isRightAssociative: Bool {
        switch self {
        case .binaryOp(let op):
            return op == "^"
        case .unaryOp:
            return true
        default:
            return false
        }
    }
}
