//
//  UnitCategory.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation

public struct UnitItem: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let symbol: String
    public let factorToBase: Double // How many base units 1 of this unit equals
    public let baseOffset: Double  // Offset from base (e.g. for Celsius/Kelvin)
    
    public init(id: String, name: String, symbol: String, factorToBase: Double, baseOffset: Double = 0.0) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.factorToBase = factorToBase
        self.baseOffset = baseOffset
    }
}

public typealias UnitCategory = UnitCategoryType

public enum UnitCategoryType: String, CaseIterable, Identifiable {
    case length = "Length"
    case mass = "Mass & Weight"
    case temperature = "Temperature"
    case speed = "Speed"
    case area = "Area"
    case volume = "Volume"
    case dataStorage = "Data Storage"
    case time = "Time"
    case pressure = "Pressure"
    case energy = "Energy"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .length: return "ruler"
        case .mass: return "scalemass"
        case .temperature: return "thermometer.medium"
        case .speed: return "speedometer"
        case .area: return "square.dashed"
        case .volume: return "drop.fill"
        case .dataStorage: return "externaldrive.fill"
        case .time: return "clock.fill"
        case .pressure: return "gauge.with.needle"
        case .energy: return "bolt.fill"
        }
    }
    
    public var units: [UnitItem] {
        switch self {
        case .length:
            return [
                UnitItem(id: "m", name: "Meters", symbol: "m", factorToBase: 1.0),
                UnitItem(id: "km", name: "Kilometers", symbol: "km", factorToBase: 1000.0),
                UnitItem(id: "cm", name: "Centimeters", symbol: "cm", factorToBase: 0.01),
                UnitItem(id: "mm", name: "Millimeters", symbol: "mm", factorToBase: 0.001),
                UnitItem(id: "in", name: "Inches", symbol: "in", factorToBase: 0.0254),
                UnitItem(id: "ft", name: "Feet", symbol: "ft", factorToBase: 0.3048),
                UnitItem(id: "yd", name: "Yards", symbol: "yd", factorToBase: 0.9144),
                UnitItem(id: "mi", name: "Miles", symbol: "mi", factorToBase: 1609.344),
                UnitItem(id: "nmi", name: "Nautical Miles", symbol: "NM", factorToBase: 1852.0)
            ]
            
        case .mass:
            return [
                UnitItem(id: "kg", name: "Kilograms", symbol: "kg", factorToBase: 1.0),
                UnitItem(id: "g", name: "Grams", symbol: "g", factorToBase: 0.001),
                UnitItem(id: "mg", name: "Milligrams", symbol: "mg", factorToBase: 0.000001),
                UnitItem(id: "lb", name: "Pounds", symbol: "lb", factorToBase: 0.45359237),
                UnitItem(id: "oz", name: "Ounces", symbol: "oz", factorToBase: 0.028349523125),
                UnitItem(id: "ton", name: "Metric Tons", symbol: "t", factorToBase: 1000.0),
                UnitItem(id: "st", name: "Stones", symbol: "st", factorToBase: 6.35029)
            ]
            
        case .temperature:
            // Base unit: Kelvin
            return [
                UnitItem(id: "c", name: "Celsius", symbol: "°C", factorToBase: 1.0, baseOffset: 273.15),
                UnitItem(id: "f", name: "Fahrenheit", symbol: "°F", factorToBase: 5.0 / 9.0, baseOffset: 459.67 * (5.0 / 9.0)),
                UnitItem(id: "k", name: "Kelvin", symbol: "K", factorToBase: 1.0, baseOffset: 0.0)
            ]
            
        case .speed:
            return [
                UnitItem(id: "mps", name: "Meters per second", symbol: "m/s", factorToBase: 1.0),
                UnitItem(id: "kph", name: "Kilometers per hour", symbol: "km/h", factorToBase: 1.0 / 3.6),
                UnitItem(id: "mph", name: "Miles per hour", symbol: "mph", factorToBase: 0.44704),
                UnitItem(id: "knot", name: "Knots", symbol: "kn", factorToBase: 0.514444)
            ]
            
        case .area:
            return [
                UnitItem(id: "sqm", name: "Square Meters", symbol: "m²", factorToBase: 1.0),
                UnitItem(id: "sqkm", name: "Square Kilometers", symbol: "km²", factorToBase: 1_000_000.0),
                UnitItem(id: "sqft", name: "Square Feet", symbol: "ft²", factorToBase: 0.092903),
                UnitItem(id: "sqyd", name: "Square Yards", symbol: "yd²", factorToBase: 0.836127),
                UnitItem(id: "acre", name: "Acres", symbol: "ac", factorToBase: 4046.8564224),
                UnitItem(id: "ha", name: "Hectares", symbol: "ha", factorToBase: 10_000.0)
            ]
            
        case .volume:
            return [
                UnitItem(id: "l", name: "Liters", symbol: "L", factorToBase: 1.0),
                UnitItem(id: "ml", name: "Milliliters", symbol: "mL", factorToBase: 0.001),
                UnitItem(id: "gal", name: "US Gallons", symbol: "gal", factorToBase: 3.78541),
                UnitItem(id: "qt", name: "US Quarts", symbol: "qt", factorToBase: 0.946353),
                UnitItem(id: "pt", name: "US Pints", symbol: "pt", factorToBase: 0.473176),
                UnitItem(id: "cup", name: "US Cups", symbol: "cup", factorToBase: 0.236588),
                UnitItem(id: "floz", name: "Fluid Ounces", symbol: "fl oz", factorToBase: 0.0295735)
            ]
            
        case .dataStorage:
            return [
                UnitItem(id: "b", name: "Bytes", symbol: "B", factorToBase: 1.0),
                UnitItem(id: "kb", name: "Kilobytes", symbol: "KB", factorToBase: 1024.0),
                UnitItem(id: "mb", name: "Megabytes", symbol: "MB", factorToBase: 1024.0 * 1024.0),
                UnitItem(id: "gb", name: "Gigabytes", symbol: "GB", factorToBase: 1024.0 * 1024.0 * 1024.0),
                UnitItem(id: "tb", name: "Terabytes", symbol: "TB", factorToBase: pow(1024.0, 4)),
                UnitItem(id: "pb", name: "Petabytes", symbol: "PB", factorToBase: pow(1024.0, 5))
            ]
            
        case .time:
            return [
                UnitItem(id: "s", name: "Seconds", symbol: "s", factorToBase: 1.0),
                UnitItem(id: "ms", name: "Milliseconds", symbol: "ms", factorToBase: 0.001),
                UnitItem(id: "min", name: "Minutes", symbol: "min", factorToBase: 60.0),
                UnitItem(id: "hr", name: "Hours", symbol: "hr", factorToBase: 3600.0),
                UnitItem(id: "day", name: "Days", symbol: "d", factorToBase: 86400.0),
                UnitItem(id: "wk", name: "Weeks", symbol: "wk", factorToBase: 604800.0),
                UnitItem(id: "yr", name: "Years", symbol: "yr", factorToBase: 31536000.0)
            ]
            
        case .pressure:
            return [
                UnitItem(id: "pa", name: "Pascals", symbol: "Pa", factorToBase: 1.0),
                UnitItem(id: "kpa", name: "Kilopascals", symbol: "kPa", factorToBase: 1000.0),
                UnitItem(id: "bar", name: "Bar", symbol: "bar", factorToBase: 100000.0),
                UnitItem(id: "psi", name: "Pounds per sq inch", symbol: "psi", factorToBase: 6894.757),
                UnitItem(id: "atm", name: "Atmospheres", symbol: "atm", factorToBase: 101325.0)
            ]
            
        case .energy:
            return [
                UnitItem(id: "j", name: "Joules", symbol: "J", factorToBase: 1.0),
                UnitItem(id: "kj", name: "Kilojoules", symbol: "kJ", factorToBase: 1000.0),
                UnitItem(id: "cal", name: "Calories", symbol: "cal", factorToBase: 4.184),
                UnitItem(id: "kcal", name: "Kilocalories", symbol: "kcal", factorToBase: 4184.0),
                UnitItem(id: "wh", name: "Watt-hours", symbol: "Wh", factorToBase: 3600.0),
                UnitItem(id: "kwh", name: "Kilowatt-hours", symbol: "kWh", factorToBase: 3.6e6),
                UnitItem(id: "btu", name: "BTU", symbol: "BTU", factorToBase: 1055.06)
            ]
        }
    }
}
