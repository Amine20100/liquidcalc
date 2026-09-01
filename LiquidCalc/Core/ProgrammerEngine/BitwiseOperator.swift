//
//  BitwiseOperator.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation

public enum BitwiseOperator: String, CaseIterable, Identifiable, Sendable {
    case and = "AND"
    case or = "OR"
    case xor = "XOR"
    case not = "NOT"
    case nand = "NAND"
    case nor = "NOR"
    case xnor = "XNOR"
    case lsh = "LSH"
    case rsh = "RSH"
    case rol = "ROL"
    case ror = "ROR"
    case add = "+"
    case subtract = "-"
    case multiply = "×"
    case divide = "÷"
    case mod = "MOD"
    case negate = "NEG"
    
    public var id: String { rawValue }
    
    public var symbol: String {
        switch self {
        case .and: return "&"
        case .or: return "|"
        case .xor: return "^"
        case .not: return "~"
        case .nand: return "⊼"
        case .nor: return "⊽"
        case .xnor: return "⊙"
        case .lsh: return "<<"
        case .rsh: return ">>"
        case .rol: return "↺"
        case .ror: return "↻"
        case .add: return "+"
        case .subtract: return "-"
        case .multiply: return "×"
        case .divide: return "÷"
        case .mod: return "%"
        case .negate: return "±"
        }
    }
}
