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
        var cleaned = expression
        
        // 1. Normalize Unicode vulgar fractions
        let vulgarFractions: [String: String] = [
            "½": "(1/2)", "⅓": "(1/3)", "⅔": "(2/3)", "¼": "(1/4)",
            "¾": "(3/4)", "⅕": "(1/5)", "⅖": "(2/5)", "⅗": "(3/5)",
            "⅘": "(4/5)", "⅙": "(1/6)", "⅚": "(5/6)", "⅛": "(1/8)",
            "⅜": "(3/8)", "⅝": "(5/8)", "⅞": "(7/8)", "⅑": "(1/9)",
            "⅒": "(1/10)"
        ]
        for (vulgar, standard) in vulgarFractions {
            cleaned = cleaned.replacingOccurrences(of: vulgar, with: standard)
        }
        
        // 2. Normalize mixed fractions e.g. "3 1/2" -> "3 + 1/2"
        if let mixedRegex = try? NSRegularExpression(pattern: #"(\d+)\s+(\(?\d+\s*\/\s*\d+\)?)"#, options: []) {
            let range = NSRange(location: 0, length: cleaned.utf16.count)
            cleaned = mixedRegex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "$1 + $2")
        }
        
        // 3. Normalize Unicode superscripts e.g. x², 5³, 10⁻²
        let superscripts: [String: String] = [
            "⁰": "^0", "¹": "^1", "²": "^2", "³": "^3", "⁴": "^4",
            "⁵": "^5", "⁶": "^6", "⁷": "^7", "⁸": "^8", "⁹": "^9",
            "⁺": "^+", "⁻": "^-"
        ]
        for (sup, standard) in superscripts {
            cleaned = cleaned.replacingOccurrences(of: sup, with: standard)
        }
        
        // Collapse consecutive power signs: e.g. ^2^3 -> ^23 for multi-digit superscripts
        if let powerRegex = try? NSRegularExpression(pattern: #"\^(\d+)\^(\d+)"#, options: []) {
            var prev = cleaned
            repeat {
                prev = cleaned
                let range = NSRange(location: 0, length: cleaned.utf16.count)
                cleaned = powerRegex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "^$1$2")
            } while cleaned != prev
        }
        
        // 4. Normalize arithmetic and root operators
        cleaned = cleaned
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "·", with: "*")
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
            } else if char == "%" {
                index = input.index(after: index)
                // Determine if '%' is unary postfix percentage or binary modulo
                var isPostfix = false
                if let last = rawTokens.last {
                    switch last {
                    case .number, .constant, .rightParen, .postfixOp:
                        isPostfix = true
                    default:
                        isPostfix = false
                    }
                }
                
                if isPostfix {
                    rawTokens.append(.postfixOp("%"))
                } else {
                    rawTokens.append(.binaryOp("%"))
                }
            } else if char == "+" || char == "-" || char == "*" || char == "/" || char == "^" {
                let op = String(char)
                index = input.index(after: index)
                
                // Determine if '+' or '-' is unary prefix
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
        case "mod":
            return .binaryOp("mod")
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
                     (.rightParen, .function),
                     (.postfixOp, .leftParen),
                     (.postfixOp, .number),
                     (.postfixOp, .constant),
                     (.postfixOp, .function):
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
