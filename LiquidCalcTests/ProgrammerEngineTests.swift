//
//  ProgrammerEngineTests.swift
//  LiquidCalcTests
//
//  Created for LiquidCalc iOS 18+.
//

import XCTest
#if canImport(LiquidCalcCore)
@testable import LiquidCalcCore
#endif

final class ProgrammerEngineTests: XCTestCase {
    
    func testRadixRepresentations() {
        let engine = ProgrammerEngine()
        engine.wordSize = .dword
        engine.currentValue = 255
        
        XCTAssertEqual(engine.hexString, "FF")
        XCTAssertEqual(engine.decString, "255")
        XCTAssertEqual(engine.octString, "377")
        // Check binary ends with 1111 1111
        XCTAssertTrue(engine.binString.hasSuffix("1111 1111"))
    }
    
    func testBitwiseOperations() {
        let engine = ProgrammerEngine()
        engine.wordSize = .byte
        
        // 0b1010_1010 = 0xAA = 170
        // 0b0101_0101 = 0x55 = 85
        // 170 & 85 = 0
        engine.currentValue = 170
        engine.setPendingOperation(.and)
        engine.currentValue = 85
        engine.computeEquals()
        XCTAssertEqual(engine.currentValue, 0)
        
        // 170 | 85 = 255
        engine.currentValue = 170
        engine.setPendingOperation(.or)
        engine.currentValue = 85
        engine.computeEquals()
        XCTAssertEqual(engine.currentValue, 255)
        
        // 170 ^ 85 = 255
        engine.currentValue = 170
        engine.setPendingOperation(.xor)
        engine.currentValue = 85
        engine.computeEquals()
        XCTAssertEqual(engine.currentValue, 255)
    }
    
    func testBitToggling() {
        let engine = ProgrammerEngine()
        engine.wordSize = .byte
        engine.currentValue = 0
        
        // Toggle bit 0 (value becomes 1)
        engine.toggleBit(at: 0)
        XCTAssertEqual(engine.currentValue, 1)
        XCTAssertTrue(engine.bitValue(at: 0))
        
        // Toggle bit 3 (value becomes 1 + 8 = 9)
        engine.toggleBit(at: 3)
        XCTAssertEqual(engine.currentValue, 9)
        XCTAssertTrue(engine.bitValue(at: 3))
        
        // Toggle bit 0 off (value becomes 8)
        engine.toggleBit(at: 0)
        XCTAssertEqual(engine.currentValue, 8)
        XCTAssertFalse(engine.bitValue(at: 0))
    }
    
    func testWordSizeClamping() {
        let engine = ProgrammerEngine()
        engine.wordSize = .byte
        engine.currentValue = 0x1FFF
        // Clamped to 8-bit: 0xFF = 255
        XCTAssertEqual(engine.currentValue, 0xFF)
    }
}
