//
//  SupportedCurrency.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation

public enum SupportedCurrency: String, CaseIterable, Identifiable, Codable, Sendable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case mad = "MAD"
    case jpy = "JPY"
    case chf = "CHF"
    case cad = "CAD"
    case aud = "AUD"
    case inr = "INR"
    case brl = "BRL"
    
    public var id: String { rawValue }
    public var code: String { rawValue }
    
    public var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .mad: return "MAD"
        case .jpy: return "¥"
        case .chf: return "CHF"
        case .cad: return "CA$"
        case .aud: return "A$"
        case .inr: return "₹"
        case .brl: return "R$"
        }
    }
    
    public var displayName: String {
        switch self {
        case .usd: return "US Dollar ($)"
        case .eur: return "Euro (€)"
        case .gbp: return "British Pound (£)"
        case .mad: return "Moroccan Dirham (MAD)"
        case .jpy: return "Japanese Yen (¥)"
        case .chf: return "Swiss Franc (CHF)"
        case .cad: return "Canadian Dollar (CA$)"
        case .aud: return "Australian Dollar (A$)"
        case .inr: return "Indian Rupee (₹)"
        case .brl: return "Brazilian Real (R$)"
        }
    }
    
    public var flag: String {
        switch self {
        case .usd: return "🇺🇸"
        case .eur: return "🇪🇺"
        case .gbp: return "🇬🇧"
        case .mad: return "🇲🇦"
        case .jpy: return "🇯🇵"
        case .chf: return "🇨🇭"
        case .cad: return "🇨🇦"
        case .aud: return "🇦🇺"
        case .inr: return "🇮🇳"
        case .brl: return "🇧🇷"
        }
    }
    
    public var decimalPlaces: Int {
        switch self {
        case .jpy:
            return 0
        default:
            return 2
        }
    }
    
    public var isSymbolPrefix: Bool {
        switch self {
        case .usd, .gbp, .jpy, .cad, .aud, .inr, .brl:
            return true
        case .eur, .mad, .chf:
            return false
        }
    }
    
    public func format(amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        
        let formattedNumber = formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.\(decimalPlaces)f", amount)
        
        switch self {
        case .usd:
            return "$\(formattedNumber)"
        case .eur:
            return "\(formattedNumber) €"
        case .gbp:
            return "£\(formattedNumber)"
        case .mad:
            return "\(formattedNumber) MAD"
        case .jpy:
            return "¥\(formattedNumber)"
        case .chf:
            return "CHF \(formattedNumber)"
        case .cad:
            return "CA$\(formattedNumber)"
        case .aud:
            return "A$\(formattedNumber)"
        case .inr:
            return "₹\(formattedNumber)"
        case .brl:
            return "R$ \(formattedNumber)"
        }
    }
    
    public static func detect(from text: String) -> SupportedCurrency? {
        let upper = text.uppercased()
        
        // Check multi-character / unique codes first
        if upper.contains("MAD") || upper.contains("DHS") || upper.contains("DH") || upper.contains("DIRHAM") || text.contains("د.م.") {
            return .mad
        }
        if upper.contains("CA$") || upper.contains("CAD") || upper.contains("C$") {
            return .cad
        }
        if upper.contains("A$") || upper.contains("AUD") || upper.contains("AU$") {
            return .aud
        }
        if upper.contains("R$") || upper.contains("BRL") || upper.contains("REAIS") {
            return .brl
        }
        if upper.contains("CHF") || upper.contains("FR.") {
            return .chf
        }
        if text.contains("₹") || upper.contains("INR") || upper.contains("RS.") || upper.contains("RS ") {
            return .inr
        }
        if text.contains("¥") || upper.contains("JPY") || text.contains("円") || upper.contains("YEN") {
            return .jpy
        }
        if text.contains("£") || upper.contains("GBP") || upper.contains("POUND") {
            return .gbp
        }
        if text.contains("€") || upper.contains("EUR") || upper.contains("EURO") {
            return .eur
        }
        if text.contains("$") || upper.contains("USD") {
            return .usd
        }
        
        return nil
    }
}
