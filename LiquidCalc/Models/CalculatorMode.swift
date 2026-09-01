//
//  CalculatorMode.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation

public enum CalculatorMode: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case scientific = "Scientific"
    case programmer = "Programmer"
    case converter = "Converter"
    case vision = "Vision"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .standard: return "plus.slash.minus"
        case .scientific: return "function"
        case .programmer: return "chevron.left.forwardslash.chevron.right"
        case .converter: return "arrow.triangle.2.circlepath"
        case .vision: return "camera.viewfinder"
        }
    }
}

public enum AngleUnit: String, CaseIterable, Identifiable {
    case radians = "Rad"
    case degrees = "Deg"
    
    public var id: String { rawValue }
}
