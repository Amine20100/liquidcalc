//
//  ProgrammerViewModel.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation
import SwiftUI

@Observable
public final class ProgrammerViewModel {
    public let engine = ProgrammerEngine()
    
    public var currentValue: UInt64 {
        get { engine.currentValue }
        set { engine.currentValue = newValue }
    }
    
    public var wordSize: WordSize {
        get { engine.wordSize }
        set { engine.wordSize = newValue }
    }
    
    public var activeBase: RadixBase {
        get { engine.activeBase }
        set { engine.activeBase = newValue }
    }
    
    public var isSigned: Bool {
        get { engine.isSigned }
        set { engine.isSigned = newValue }
    }
    
    public var hexDisplay: String { engine.hexString }
    public var decDisplay: String { engine.decString }
    public var octDisplay: String { engine.octString }
    public var binDisplay: String { engine.binString }
    
    public init() {}
    
    public func handleButtonPress(_ button: KeypadButton) {
        switch button.type {
        case .digit(let d):
            if let char = d.first {
                engine.inputDigit(char)
            }
        case .hexDigit(let h):
            if let char = h.first {
                engine.inputDigit(char)
            }
        case .clear, .allClear:
            engine.clear()
        case .delete:
            engine.backspace()
        case .bitwise(let opName):
            if let op = BitwiseOperator(rawValue: opName) {
                engine.setPendingOperation(op)
            }
        case .operation(let op):
            switch op {
            case "+": engine.setPendingOperation(.add)
            case "-": engine.setPendingOperation(.subtract)
            case "×", "*": engine.setPendingOperation(.multiply)
            case "÷", "/": engine.setPendingOperation(.divide)
            case "%", "MOD": engine.setPendingOperation(.mod)
            default: break
            }
        case .plusMinus:
            engine.setPendingOperation(.negate)
        case .equals:
            engine.computeEquals()
        default:
            break
        }
    }
    
    public func toggleBit(at index: Int) {
        engine.toggleBit(at: index)
    }
    
    public func isBitSet(at index: Int) -> Bool {
        engine.bitValue(at: index)
    }
}
