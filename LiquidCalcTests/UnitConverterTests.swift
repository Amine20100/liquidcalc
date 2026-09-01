//
//  UnitConverterTests.swift
//  LiquidCalcTests
//
//  Created for LiquidCalc iOS 18+.
//

import XCTest
#if canImport(LiquidCalcCore)
@testable import LiquidCalcCore
#endif

final class UnitConverterTests: XCTestCase {
    
    func testLengthConversion() {
        let engine = UnitConverterEngine()
        let km = UnitItem(id: "km", name: "Kilometers", symbol: "km", factorToBase: 1000.0)
        let m = UnitItem(id: "m", name: "Meters", symbol: "m", factorToBase: 1.0)
        
        let result = engine.convert(value: 5.0, from: km, to: m, category: .length)
        XCTAssertEqual(result, 5000.0, accuracy: 1e-9)
    }
    
    func testTemperatureConversion() {
        let engine = UnitConverterEngine()
        let c = UnitItem(id: "c", name: "Celsius", symbol: "°C", factorToBase: 1.0)
        let f = UnitItem(id: "f", name: "Fahrenheit", symbol: "°F", factorToBase: 1.0)
        let k = UnitItem(id: "k", name: "Kelvin", symbol: "K", factorToBase: 1.0)
        
        // 0 °C = 32 °F
        let f32 = engine.convert(value: 0.0, from: c, to: f, category: .temperature)
        XCTAssertEqual(f32, 32.0, accuracy: 1e-4)
        
        // 100 °C = 212 °F
        let f212 = engine.convert(value: 100.0, from: c, to: f, category: .temperature)
        XCTAssertEqual(f212, 212.0, accuracy: 1e-4)
        
        // 0 °C = 273.15 K
        let k273 = engine.convert(value: 0.0, from: c, to: k, category: .temperature)
        XCTAssertEqual(k273, 273.15, accuracy: 1e-4)
    }
    
    func testDataStorageConversion() {
        let engine = UnitConverterEngine()
        let mb = UnitItem(id: "mb", name: "Megabytes", symbol: "MB", factorToBase: 1024.0 * 1024.0)
        let gb = UnitItem(id: "gb", name: "Gigabytes", symbol: "GB", factorToBase: 1024.0 * 1024.0 * 1024.0)
        
        let result = engine.convert(value: 2048.0, from: mb, to: gb, category: .dataStorage)
        XCTAssertEqual(result, 2.0, accuracy: 1e-9)
    }
}
