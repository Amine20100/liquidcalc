//
//  MathParser.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation

public final class MathParser {
    public init() {}
    
    /// Converts infix tokens to postfix (RPN) tokens using Dijkstra's Shunting-yard algorithm
    public func parseToRPN(_ tokens: [MathToken]) throws -> [MathToken] {
        var outputQueue: [MathToken] = []
        var operatorStack: [MathToken] = []
        
        for token in tokens {
            switch token {
            case .number, .constant:
                outputQueue.append(token)
                
            case .function:
                operatorStack.append(token)
                
            case .comma:
                while let top = operatorStack.last, top != .leftParen {
                    outputQueue.append(operatorStack.removeLast())
                }
                if operatorStack.isEmpty {
                    throw MathError.unexpectedToken(",")
                }
                
            case .unaryOp:
                operatorStack.append(token)
                
            case .binaryOp:
                while let top = operatorStack.last {
                    if top == .leftParen { break }
                    
                    let tokenPrec = token.precedence
                    let topPrec = top.precedence
                    
                    if (topPrec > tokenPrec) || (topPrec == tokenPrec && !token.isRightAssociative) {
                        outputQueue.append(operatorStack.removeLast())
                    } else {
                        break
                    }
                }
                operatorStack.append(token)
                
            case .leftParen:
                operatorStack.append(token)
                
            case .rightParen:
                var foundLeftParen = false
                while let top = operatorStack.last {
                    if top == .leftParen {
                        operatorStack.removeLast()
                        foundLeftParen = true
                        break
                    } else {
                        outputQueue.append(operatorStack.removeLast())
                    }
                }
                
                if !foundLeftParen {
                    throw MathError.mismatchedParentheses
                }
                
                // If the top of operatorStack is a function, pop it to outputQueue
                if let top = operatorStack.last, case .function = top {
                    outputQueue.append(operatorStack.removeLast())
                }
            }
        }
        
        while let top = operatorStack.last {
            if top == .leftParen || top == .rightParen {
                throw MathError.mismatchedParentheses
            }
            outputQueue.append(operatorStack.removeLast())
        }
        
        return outputQueue
    }
}
