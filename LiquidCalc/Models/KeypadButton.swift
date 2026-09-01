//
//  KeypadButton.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public enum KeypadButtonType: Equatable {
    case digit(String)
    case decimal
    case operation(String)
    case equals
    case clear
    case allClear
    case delete
    case signToggle
    case percent
    case parenthesis(String)
    case scientific(String)
    case constant(String)
    case memory(String)
    case hexDigit(String)
    case bitwise(String)
}

public struct KeypadButton: Identifiable, Equatable {
    public let id = UUID()
    public let label: String
    public let type: KeypadButtonType
    public let secondaryLabel: String?
    public let isWide: Bool
    
    public init(label: String, type: KeypadButtonType, secondaryLabel: String? = nil, isWide: Bool = false) {
        self.label = label
        self.type = type
        self.secondaryLabel = secondaryLabel
        self.isWide = isWide
    }
    
    public var accentStyle: KeypadAccentStyle {
        switch type {
        case .equals:
            return .accentOrange
        case .operation, .bitwise:
            return .accentCyan
        case .clear, .allClear, .delete, .signToggle, .percent:
            return .functionGray
        case .scientific, .parenthesis, .constant, .memory:
            return .scientificViolet
        case .hexDigit:
            return .hexBlue
        case .digit, .decimal:
            return .digitDark
        }
    }
}

public enum KeypadAccentStyle {
    case digitDark
    case functionGray
    case accentOrange
    case accentCyan
    case scientificViolet
    case hexBlue
    
    public var backgroundColors: [Color] {
        switch self {
        case .digitDark:
            return [Color(white: 0.18, opacity: 0.75), Color(white: 0.12, opacity: 0.85)]
        case .functionGray:
            return [Color(white: 0.35, opacity: 0.75), Color(white: 0.25, opacity: 0.85)]
        case .accentOrange:
            return [Color.orange.opacity(0.85), Color.red.opacity(0.85)]
        case .accentCyan:
            return [Color.cyan.opacity(0.85), Color.blue.opacity(0.85)]
        case .scientificViolet:
            return [Color.purple.opacity(0.7), Color.indigo.opacity(0.8)]
        case .hexBlue:
            return [Color.blue.opacity(0.6), Color.teal.opacity(0.7)]
        }
    }
    
    public var foregroundColor: Color {
        switch self {
        case .functionGray, .digitDark, .accentOrange, .accentCyan, .scientificViolet, .hexBlue:
            return .white
        }
    }
}
