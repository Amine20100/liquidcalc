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
    case geminiAI = "Gemini AI"
    case advancedMath = "Math Lab"
    case graphing = "Grapher"
    case mathDraw = "Draw Calc"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .standard: return "plus.slash.minus"
        case .scientific: return "function"
        case .programmer: return "chevron.left.forwardslash.chevron.right"
        case .converter: return "arrow.triangle.2.circlepath"
        case .vision: return "camera.viewfinder"
        case .geminiAI: return "sparkles"
        case .advancedMath: return "atom"
        case .graphing: return "waveform.path.ecg"
        case .mathDraw: return "hand.draw.fill"
        }
    }
}

public enum AngleUnit: String, CaseIterable, Identifiable {
    case radians = "Rad"
    case degrees = "Deg"
    
    public var id: String { rawValue }
}
