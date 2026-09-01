//
//  ProgrammerEngine.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation

public enum RadixBase: Int, CaseIterable, Identifiable, Sendable {
    case hex = 16
    case dec = 10
    case oct = 8
    case bin = 2
    
    public var id: Int { rawValue }
    
    public var label: String {
        switch self {
        case .hex: return "HEX"
        case .dec: return "DEC"
        case .oct: return "OCT"
        case .bin: return "BIN"
        }
    }
}

public final class ProgrammerEngine {
    public var currentValue: UInt64 = 0 {
        didSet {
            currentValue = wordSize.clamp(currentValue)
        }
    }
    
    public var wordSize: WordSize = .qword {
        didSet {
            currentValue = wordSize.clamp(currentValue)
        }
    }
    
    public var activeBase: RadixBase = .dec
    public var isSigned: Bool = false
    
    public private(set) var pendingOperation: BitwiseOperator?
    public private(set) var storedValue: UInt64?
    
    public init() {}
    
    // MARK: - Radix Strings
    
    public var hexString: String {
        let hex = String(currentValue, radix: 16, uppercase: true)
        return hex.isEmpty ? "0" : hex
    }
    
    public var decString: String {
        if isSigned {
            switch wordSize {
            case .byte:
                return String(Int8(bitPattern: UInt8(currentValue & 0xFF)))
            case .word:
                return String(Int16(bitPattern: UInt16(currentValue & 0xFFFF)))
            case .dword:
                return String(Int32(bitPattern: UInt32(currentValue & 0xFFFF_FFFF)))
            case .qword:
                return String(Int64(bitPattern: currentValue))
            }
        } else {
            return String(currentValue)
        }
    }
    
    public var octString: String {
        let oct = String(currentValue, radix: 8)
        return oct.isEmpty ? "0" : oct
    }
    
    public var binString: String {
        let bin = String(currentValue, radix: 2)
        let padLength = wordSize.bitCount
        let padded = String(repeating: "0", count: max(0, padLength - bin.count)) + bin
        
        var grouped = ""
        for (idx, char) in padded.enumerated() {
            if idx > 0 && (padded.count - idx) % 4 == 0 {
                grouped.append(" ")
            }
            grouped.append(char)
        }
        return grouped
    }
    
    // MARK: - Input
    
    public func inputDigit(_ char: Character) {
        guard let digitValue = char.hexDigitValue, digitValue < activeBase.rawValue else {
            return
        }
        
        let base = UInt64(activeBase.rawValue)
        let (mult, overflow1) = currentValue.multipliedReportingOverflow(by: base)
        if overflow1 { return }
        
        let (sum, overflow2) = mult.addingReportingOverflow(UInt64(digitValue))
        if overflow2 { return }
        
        currentValue = wordSize.clamp(sum)
    }
    
    public func backspace() {
        currentValue /= UInt64(activeBase.rawValue)
    }
    
    public func clear() {
        currentValue = 0
        pendingOperation = nil
        storedValue = nil
    }
    
    // MARK: - Bit Visualizer
    
    public func bitValue(at index: Int) -> Bool {
        guard index >= 0 && index < wordSize.bitCount else { return false }
        return (currentValue & (1 << index)) != 0
    }
    
    public func toggleBit(at index: Int) {
        guard index >= 0 && index < wordSize.bitCount else { return }
        currentValue ^= (1 << index)
    }
    
    public func setBit(at index: Int, to value: Bool) {
        guard index >= 0 && index < wordSize.bitCount else { return }
        if value {
            currentValue |= (1 << index)
        } else {
            currentValue &= ~(1 << index)
        }
    }
    
    // MARK: - Operations
    
    public func setPendingOperation(_ op: BitwiseOperator) {
        switch op {
        case .not:
            currentValue = wordSize.clamp(~currentValue)
        case .negate:
            let (neg, _) = (~currentValue).addingReportingOverflow(1)
            currentValue = wordSize.clamp(neg)
        default:
            storedValue = currentValue
            pendingOperation = op
            currentValue = 0
        }
    }
    
    public func computeEquals() {
        guard let op = pendingOperation, let stored = storedValue else { return }
        
        let a = stored
        let b = currentValue
        let result: UInt64
        
        switch op {
        case .and:
            result = a & b
        case .or:
            result = a | b
        case .xor:
            result = a ^ b
        case .nand:
            result = ~(a & b)
        case .nor:
            result = ~(a | b)
        case .xnor:
            result = ~(a ^ b)
        case .lsh:
            let shift = Int(b % UInt64(wordSize.bitCount))
            result = a << shift
        case .rsh:
            let shift = Int(b % UInt64(wordSize.bitCount))
            result = a >> shift
        case .rol:
            let shift = Int(b % UInt64(wordSize.bitCount))
            let bits = wordSize.bitCount
            result = shift == 0 ? a : ((a << shift) | (a >> (bits - shift)))
        case .ror:
            let shift = Int(b % UInt64(wordSize.bitCount))
            let bits = wordSize.bitCount
            result = shift == 0 ? a : ((a >> shift) | (a << (bits - shift)))
        case .add:
            let (sum, _) = a.addingReportingOverflow(b)
            result = sum
        case .subtract:
            let (diff, _) = a.subtractingReportingOverflow(b)
            result = diff
        case .multiply:
            let (prod, _) = a.multipliedReportingOverflow(by: b)
            result = prod
        case .divide:
            result = b == 0 ? 0 : a / b
        case .mod:
            result = b == 0 ? 0 : a % b
        case .not:
            result = ~b
        case .negate:
            let (neg, _) = (~b).addingReportingOverflow(1)
            result = neg
        }
        
        currentValue = wordSize.clamp(result)
        pendingOperation = nil
        storedValue = nil
    }
}
