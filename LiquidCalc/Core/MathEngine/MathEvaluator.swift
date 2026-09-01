//
//  MathEvaluator.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation

public final class MathEvaluator {
    public var angleUnit: AngleUnit
    
    public init(angleUnit: AngleUnit = .radians) {
        self.angleUnit = angleUnit
    }
    
    public func evaluate(expression: String) throws -> Double {
        let lexer = MathLexer(expression: expression)
        let tokens = try lexer.tokenize()
        guard !tokens.isEmpty else {
            throw MathError.emptyExpression
        }
        
        let parser = MathParser()
        let rpn = try parser.parseToRPN(tokens)
        return try evaluateRPN(rpn)
    }
    
    public func evaluateRPN(_ tokens: [MathToken]) throws -> Double {
        var stack: [Double] = []
        
        for token in tokens {
            switch token {
            case .number(let value):
                stack.append(value)
                
            case .constant(_, let value):
                stack.append(value)
                
            case .unaryOp(let op):
                guard let operand = stack.popLast() else {
                    throw MathError.unexpectedToken(op)
                }
                if op == "-" {
                    stack.append(-operand)
                } else {
                    stack.append(operand)
                }
                
            case .binaryOp(let op):
                guard let right = stack.popLast(), let left = stack.popLast() else {
                    throw MathError.unexpectedToken(op)
                }
                let result = try executeBinaryOp(op, left: left, right: right)
                stack.append(result)
                
            case .function(let fn):
                guard let operand = stack.popLast() else {
                    throw MathError.unknownFunction(fn)
                }
                let result = try executeFunction(fn, operand: operand)
                stack.append(result)
                
            default:
                break
            }
        }
        
        guard let finalResult = stack.popLast(), stack.isEmpty else {
            throw MathError.domainError("Malformed expression")
        }
        
        if finalResult.isNaN {
            throw MathError.domainError("Result is undefined")
        }
        if finalResult.isInfinite {
            throw MathError.overflow
        }
        
        return finalResult
    }
    
    private func executeBinaryOp(_ op: String, left: Double, right: Double) throws -> Double {
        switch op {
        case "+":
            return left + right
        case "-":
            return left - right
        case "*":
            return left * right
        case "/":
            if abs(right) < 1e-15 {
                throw MathError.divisionByZero
            }
            return left / right
        case "%":
            if abs(right) < 1e-15 {
                throw MathError.divisionByZero
            }
            return left.truncatingRemainder(dividingBy: right)
        case "^":
            return pow(left, right)
        default:
            throw MathError.unexpectedToken(op)
        }
    }
    
    private func executeFunction(_ fn: String, operand: Double) throws -> Double {
        switch fn {
        case "sin":
            let val = angleUnit == .degrees ? operand * .pi / 180.0 : operand
            return sin(val)
        case "cos":
            let val = angleUnit == .degrees ? operand * .pi / 180.0 : operand
            return cos(val)
        case "tan":
            let val = angleUnit == .degrees ? operand * .pi / 180.0 : operand
            let cosVal = cos(val)
            if abs(cosVal) < 1e-15 {
                throw MathError.domainError("Undefined (tangent asymptotic)")
            }
            return tan(val)
        case "asin":
            if operand < -1.0 || operand > 1.0 {
                throw MathError.domainError("Domain error for asin [-1, 1]")
            }
            let res = asin(operand)
            return angleUnit == .degrees ? res * 180.0 / .pi : res
        case "acos":
            if operand < -1.0 || operand > 1.0 {
                throw MathError.domainError("Domain error for acos [-1, 1]")
            }
            let res = acos(operand)
            return angleUnit == .degrees ? res * 180.0 / .pi : res
        case "atan":
            let res = atan(operand)
            return angleUnit == .degrees ? res * 180.0 / .pi : res
        case "sinh":
            return sinh(operand)
        case "cosh":
            return cosh(operand)
        case "tanh":
            return tanh(operand)
        case "asinh":
            return asinh(operand)
        case "acosh":
            if operand < 1.0 {
                throw MathError.domainError("acosh domain is [1, ∞)")
            }
            return acosh(operand)
        case "atanh":
            if operand <= -1.0 || operand >= 1.0 {
                throw MathError.domainError("atanh domain is (-1, 1)")
            }
            return atanh(operand)
        case "ln":
            if operand <= 0 {
                throw MathError.domainError("ln of non-positive number")
            }
            return log(operand)
        case "log", "log10":
            if operand <= 0 {
                throw MathError.domainError("log10 of non-positive number")
            }
            return log10(operand)
        case "log2":
            if operand <= 0 {
                throw MathError.domainError("log2 of non-positive number")
            }
            return log2(operand)
        case "sqrt":
            if operand < 0 {
                throw MathError.domainError("Cannot compute square root of negative number")
            }
            return sqrt(operand)
        case "cbrt":
            return cbrt(operand)
        case "abs":
            return abs(operand)
        case "exp":
            return exp(operand)
        case "fact":
            if operand < 0 || floor(operand) != operand {
                throw MathError.domainError("Factorial requires non-negative integer")
            }
            if operand > 170 {
                throw MathError.overflow
            }
            let n = Int(operand)
            var res = 1.0
            for i in 1...max(1, n) {
                res *= Double(i)
            }
            return res
        case "inv":
            if abs(operand) < 1e-15 {
                throw MathError.divisionByZero
            }
            return 1.0 / operand
        default:
            throw MathError.unknownFunction(fn)
        }
    }
    
    public static func formatResult(_ value: Double) -> String {
        if value.isNaN { return "Error" }
        if value.isInfinite { return value > 0 ? "∞" : "-∞" }
        
        let absVal = abs(value)
        if absVal != 0 && (absVal >= 1e12 || absVal < 1e-6) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .scientific
            formatter.maximumSignificantDigits = 8
            formatter.exponentSymbol = "e"
            return formatter.string(from: NSNumber(value: value)) ?? String(value)
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
