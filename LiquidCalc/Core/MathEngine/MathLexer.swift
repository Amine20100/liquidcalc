//
//  MathLexer.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation

public final class MathLexer {
    private let input: String
    private var index: String.Index
    
    public init(expression: String) {
        // Clean expression: normalize spaces and Unicode operators
        var cleaned = expression
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "π", with: "pi")
            .replacingOccurrences(of: "√", with: "sqrt")
            .replacingOccurrences(of: "∛", with: "cbrt")
            .replacingOccurrences(of: " ", with: "")
        
        self.input = cleaned
        self.index = cleaned.startIndex
    }
    
    public func tokenize() throws -> [MathToken] {
        var rawTokens: [MathToken] = []
        
        while index < input.endIndex {
            let char = input[index]
            
            if char.isNumber || char == "." {
                let numToken = try parseNumber()
                rawTokens.append(numToken)
            } else if char.isLetter {
                let identifierToken = parseIdentifier()
                rawTokens.append(identifierToken)
            } else if char == "(" {
                rawTokens.append(.leftParen)
                index = input.index(after: index)
            } else if char == ")" {
                rawTokens.append(.rightParen)
                index = input.index(after: index)
            } else if char == "," {
                rawTokens.append(.comma)
                index = input.index(after: index)
            } else if char == "+" || char == "-" || char == "*" || char == "/" || char == "^" || char == "%" {
                let op = String(char)
                index = input.index(after: index)
                
                // Determine if '+' or '-' is unary
                if (op == "-" || op == "+") {
                    let isUnary: Bool
                    if let last = rawTokens.last {
                        switch last {
                        case .binaryOp, .unaryOp, .leftParen, .comma:
                            isUnary = true
                        default:
                            isUnary = false
                        }
                    } else {
                        isUnary = true
                    }
                    
                    if isUnary {
                        if op == "-" {
                            rawTokens.append(.unaryOp("-"))
                        } // Unary '+' is a no-op
                    } else {
                        rawTokens.append(.binaryOp(op))
                    }
                } else {
                    rawTokens.append(.binaryOp(op))
                }
            } else {
                index = input.index(after: index)
            }
        }
        
        // Insert implicit multiplication:
        // e.g. number followed by ( or constant/function, or ) followed by number/(
        return insertImplicitMultiplication(rawTokens)
    }
    
    private func parseNumber() throws -> MathToken {
        let startIndex = index
        var hasDecimal = false
        
        while index < input.endIndex {
            let char = input[index]
            if char.isNumber {
                index = input.index(after: index)
            } else if char == "." {
                if hasDecimal { break }
                hasDecimal = true
                index = input.index(after: index)
            } else if char == "e" || char == "E" {
                // Check if scientific notation
                let nextIdx = input.index(after: index)
                if nextIdx < input.endIndex {
                    let nextChar = input[nextIdx]
                    if nextChar.isNumber || nextChar == "+" || nextChar == "-" {
                        index = nextIdx
                        if (nextChar == "+" || nextChar == "-") {
                            index = input.index(after: index)
                        }
                        while index < input.endIndex && input[index].isNumber {
                            index = input.index(after: index)
                        }
                    }
                }
                break
            } else {
                break
            }
        }
        
        let numStr = String(input[startIndex..<index])
        guard let value = Double(numStr) else {
            throw MathError.invalidNumber(numStr)
        }
        return .number(value)
    }
    
    private func parseIdentifier() -> MathToken {
        let startIndex = index
        while index < input.endIndex && input[index].isLetter {
            index = input.index(after: index)
        }
        let word = String(input[startIndex..<index]).lowercased()
        
        switch word {
        case "pi":
            return .constant("π", Double.pi)
        case "e":
            return .constant("e", M_E)
        case "phi":
            return .constant("ϕ", 1.6180339887498948)
        case "tau":
            return .constant("τ", Double.pi * 2)
        default:
            return .function(word)
        }
    }
    
    private func insertImplicitMultiplication(_ tokens: [MathToken]) -> [MathToken] {
        var result: [MathToken] = []
        for (i, token) in tokens.enumerated() {
            result.append(token)
            if i + 1 < tokens.count {
                let next = tokens[i + 1]
                let shouldMultiply: Bool
                switch (token, next) {
                case (.number, .leftParen),
                     (.number, .constant),
                     (.number, .function),
                     (.constant, .leftParen),
                     (.constant, .number),
                     (.constant, .constant),
                     (.constant, .function),
                     (.rightParen, .leftParen),
                     (.rightParen, .number),
                     (.rightParen, .constant),
                     (.rightParen, .function):
                    shouldMultiply = true
                default:
                    shouldMultiply = false
                }
                if shouldMultiply {
                    result.append(.binaryOp("*"))
                }
            }
        }
        return result
    }
}
