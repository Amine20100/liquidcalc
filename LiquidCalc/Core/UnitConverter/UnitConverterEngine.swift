//
//  UnitConverterEngine.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation

public final class UnitConverterEngine {
    public init() {}
    
    public func convert(value: Double, from fromUnit: UnitItem, to toUnit: UnitItem, category: UnitCategoryType) -> Double {
        if category == .temperature {
            return convertTemperature(value: value, from: fromUnit, to: toUnit)
        }
        
        // General linear conversion via base unit
        // value * fromFactor = baseValue
        let baseValue = value * fromUnit.factorToBase
        // baseValue / toFactor = targetValue
        return baseValue / toUnit.factorToBase
    }
    
    private func convertTemperature(value: Double, from fromUnit: UnitItem, to toUnit: UnitItem) -> Double {
        // Convert input to Kelvin
        var kelvin: Double
        switch fromUnit.id {
        case "c":
            kelvin = value + 273.15
        case "f":
            kelvin = (value + 459.67) * (5.0 / 9.0)
        case "k":
            kelvin = value
        default:
            kelvin = value
        }
        
        // Convert Kelvin to target
        switch toUnit.id {
        case "c":
            return kelvin - 273.15
        case "f":
            return kelvin * (9.0 / 5.0) - 459.67
        case "k":
            return kelvin
        default:
            return kelvin
        }
    }
}
