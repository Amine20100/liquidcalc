//
//  WordSize.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation

public enum WordSize: String, CaseIterable, Identifiable {
    case qword = "64-bit"
    case dword = "32-bit"
    case word = "16-bit"
    case byte = "8-bit"
    
    public var id: String { rawValue }
    
    public var bitCount: Int {
        switch self {
        case .qword: return 64
        case .dword: return 32
        case .word: return 16
        case .byte: return 8
        }
    }
    
    public var bitMask: UInt64 {
        switch self {
        case .qword: return UInt64.max
        case .dword: return 0xFFFF_FFFF
        case .word: return 0xFFFF
        case .byte: return 0xFF
        }
    }
    
    public var hexCharactersCount: Int {
        return bitCount / 4
    }
    
    public func clamp(_ value: UInt64) -> UInt64 {
        return value & bitMask
    }
}
