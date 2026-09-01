//
//  VisionMathScanner.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation
import CoreGraphics
#if canImport(Vision)
import Vision
#endif
#if canImport(UIKit)
import UIKit
#endif

public struct ScannedTextObservation: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let rawText: String
    public let sanitizedExpression: String
    public let boundingBox: CGRect
    public let confidence: Float
    
    public init(id: UUID = UUID(), rawText: String, sanitizedExpression: String, boundingBox: CGRect, confidence: Float) {
        self.id = id
        self.rawText = rawText
        self.sanitizedExpression = sanitizedExpression
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

public struct ReceiptLineItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var amount: Double
    public var isSelected: Bool
    
    public var price: Double {
        get { amount }
        set { amount = newValue }
    }
    
    public var name: String {
        get { title }
        set { title = newValue }
    }
    
    public init(id: UUID = UUID(), title: String, amount: Double, isSelected: Bool = true) {
        self.id = id
        self.title = title
        self.amount = amount
        self.isSelected = isSelected
    }
    
    public init(id: UUID = UUID(), name: String, amount: Double, isSelected: Bool = true) {
        self.id = id
        self.title = name
        self.amount = amount
        self.isSelected = isSelected
    }
    
    public init(id: UUID = UUID(), title: String, price: Double, isSelected: Bool = true) {
        self.id = id
        self.title = title
        self.amount = price
        self.isSelected = isSelected
    }
    
    public init(id: UUID = UUID(), name: String, price: Double, isSelected: Bool = true) {
        self.id = id
        self.title = name
        self.amount = price
        self.isSelected = isSelected
    }
}

public struct ReceiptParseResult: Equatable, Sendable {
    public var items: [ReceiptLineItem]
    public var detectedCurrency: SupportedCurrency
    public var detectedSubtotal: Double?
    public var detectedTax: Double?
    public var detectedTotal: Double?
    
    public init(
        items: [ReceiptLineItem] = [],
        detectedCurrency: SupportedCurrency = .usd,
        detectedSubtotal: Double? = nil,
        detectedTax: Double? = nil,
        detectedTotal: Double? = nil
    ) {
        self.items = items
        self.detectedCurrency = detectedCurrency
        self.detectedSubtotal = detectedSubtotal
        self.detectedTax = detectedTax
        self.detectedTotal = detectedTotal
    }
}

public final class VisionMathScanner {
    public init() {}
    
    #if canImport(Vision)
    /// Scans a CGImage for mathematical expressions using Apple Vision VNRecognizeTextRequest
    public func scanImage(_ cgImage: CGImage, completion: @escaping (Result<[ScannedTextObservation], Error>) -> Void) {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.success([]))
                return
            }
            
            let scannedItems: [ScannedTextObservation] = observations.compactMap { obs in
                guard let candidate = obs.topCandidates(1).first else { return nil }
                let raw = candidate.string
                let sanitized = self?.sanitizeMathString(raw) ?? raw
                return ScannedTextObservation(
                    rawText: raw,
                    sanitizedExpression: sanitized,
                    boundingBox: obs.boundingBox,
                    confidence: candidate.confidence
                )
            }
            
            completion(.success(scannedItems))
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false // Essential for mathematical symbols and digits
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }
    #endif
    
    /// Sanitizes raw OCR text into a clean mathematical expression compatible with MathLexer
    public func sanitizeMathString(_ input: String) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove trailing or leading equals signs often written in math notes: "5 + 3 =" -> "5 + 3"
        if text.hasSuffix("=") {
            text.removeLast()
        }
        if text.hasPrefix("=") {
            text.removeFirst()
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Normalize Unicode vulgar fractions
        let vulgarFractions: [String: String] = [
            "½": "(1/2)", "⅓": "(1/3)", "⅔": "(2/3)", "¼": "(1/4)",
            "¾": "(3/4)", "⅕": "(1/5)", "⅖": "(2/5)", "⅗": "(3/5)",
            "⅘": "(4/5)", "⅙": "(1/6)", "⅚": "(5/6)", "⅛": "(1/8)",
            "⅜": "(3/8)", "⅝": "(5/8)", "⅞": "(7/8)", "⅑": "(1/9)",
            "⅒": "(1/10)"
        ]
        for (vulgar, standard) in vulgarFractions {
            text = text.replacingOccurrences(of: vulgar, with: standard)
        }
        
        // Normalize mixed fractions e.g. "3 1/2" -> "3 + 1/2" or "3 (1/2)" -> "3 + (1/2)"
        if let mixedRegex = try? NSRegularExpression(pattern: #"(\d+)\s+(\(?\d+\s*\/\s*\d+\)?)"#, options: []) {
            let range = NSRange(location: 0, length: text.utf16.count)
            text = mixedRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1 + $2")
        }
        
        // Normalize Unicode superscripts
        let superscripts: [String: String] = [
            "⁰": "^0", "¹": "^1", "²": "^2", "³": "^3", "⁴": "^4",
            "⁵": "^5", "⁶": "^6", "⁷": "^7", "⁸": "^8", "⁹": "^9",
            "⁺": "^+", "⁻": "^-"
        ]
        for (sup, standard) in superscripts {
            text = text.replacingOccurrences(of: sup, with: standard)
        }
        
        // Collapse consecutive power signs: e.g. ^2^3 -> ^23 for multi-digit superscripts
        if let powerRegex = try? NSRegularExpression(pattern: #"\^(\d+)\^(\d+)"#, options: []) {
            var prev = text
            repeat {
                prev = text
                let range = NSRange(location: 0, length: text.utf16.count)
                text = powerRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "^$1$2")
            } while text != prev
        }
        
        // Common OCR operator replacements
        text = text.replacingOccurrences(of: "×", with: "*")
        text = text.replacingOccurrences(of: "÷", with: "/")
        text = text.replacingOccurrences(of: "−", with: "-")
        text = text.replacingOccurrences(of: "—", with: "-")
        text = text.replacingOccurrences(of: "–", with: "-")
        text = text.replacingOccurrences(of: "·", with: "*")
        
        // Fix letter 'x' or 'X' used as multiplication between numbers (e.g. 5x4 or 5 x 4)
        if let regex = try? NSRegularExpression(pattern: #"(\d+)\s*[xX]\s*(\d+)"#, options: []) {
            let range = NSRange(location: 0, length: text.utf16.count)
            text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1 * $2")
        }
        
        // Replace square root words or symbols
        text = text.replacingOccurrences(of: "SQRT", with: "sqrt")
        text = text.replacingOccurrences(of: "√", with: "sqrt")
        text = text.replacingOccurrences(of: "∛", with: "cbrt")
        
        // Replace pi symbols
        text = text.replacingOccurrences(of: "π", with: "pi")
        
        // Clean multiple spaces
        text = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
        
        return text
    }
    
    /// Parses line items and details from a receipt or bill
    public func parseReceipt(from observations: [ScannedTextObservation]) -> ReceiptParseResult {
        var items: [ReceiptLineItem] = []
        var detectedSubtotal: Double? = nil
        var detectedTax: Double? = nil
        var detectedTotal: Double? = nil
        
        // 1. Detect currency from all observations
        var currencyCounts: [SupportedCurrency: Int] = [:]
        for obs in observations {
            if let cur = SupportedCurrency.detect(from: obs.rawText) {
                currencyCounts[cur, default: 0] += 1
            }
        }
        let detectedCurrency = currencyCounts.max(by: { $0.value < $1.value })?.key ?? .usd
        
        // Regex to extract price amounts (supporting standard, comma, and integer formats)
        // Matches e.g. "$14.50", "12,50 €", "150 MAD", "¥1500", "45.00"
        let priceRegex = try? NSRegularExpression(
            pattern: #"(?:[\$€£¥₹]|CA\$|A\$|R\$|CHF|MAD|DH|Dhs|EUR|GBP|JPY|CAD|AUD|INR|BRL|د\.م\.|円)?\s*(\d{1,5}(?:[.,]\d{2})?|\d{2,6})\s*(?:[\$€£¥₹]|CA\$|A\$|R\$|CHF|MAD|DH|Dhs|EUR|GBP|JPY|CAD|AUD|INR|BRL|د\.م\.|円)?"#,
            options: [.caseInsensitive]
        )
        
        for obs in observations {
            let text = obs.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            
            let lower = text.lowercased()
            let range = NSRange(location: 0, length: text.utf16.count)
            
            // Check for price match in line
            guard let match = priceRegex?.firstMatch(in: text, options: [], range: range),
                  let priceRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            
            let priceRawString = String(text[priceRange])
            guard let amount = parseAmount(priceRawString), amount > 0 else {
                continue
            }
            
            // Classify line to filter summary lines
            if isSubtotalLine(lower) {
                detectedSubtotal = amount
                continue
            }
            if isTaxLine(lower) {
                detectedTax = amount
                continue
            }
            if isTipLine(lower) {
                continue
            }
            if isTotalLine(lower) {
                detectedTotal = amount
                continue
            }
            if isHeaderOrFooterNoise(lower) {
                continue
            }
            
            // Extract item title (text preceding or surrounding the price)
            var title = text
            if let matchRange = Range(match.range, in: text) {
                let prefix = String(text[..<matchRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let suffix = String(text[matchRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !prefix.isEmpty {
                    title = prefix
                } else if !suffix.isEmpty {
                    title = suffix
                }
            }
            
            // Clean up title noise (leading quantities, bullet points)
            title = cleanTitle(title, fallbackIndex: items.count + 1)
            
            items.append(ReceiptLineItem(title: title, amount: amount))
        }
        
        return ReceiptParseResult(
            items: items,
            detectedCurrency: detectedCurrency,
            detectedSubtotal: detectedSubtotal,
            detectedTax: detectedTax,
            detectedTotal: detectedTotal
        )
    }
    
    /// Parses line items from a receipt or bill (backward-compatible convenience API)
    public func parseReceiptItems(from observations: [ScannedTextObservation]) -> [ReceiptLineItem] {
        return parseReceipt(from: observations).items
    }
    
    // MARK: - Private Receipt Parsing Helpers
    
    private func parseAmount(_ string: String) -> Double? {
        var clean = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.contains(".") && clean.contains(",") {
            if let dotIdx = clean.firstIndex(of: "."), let commaIdx = clean.firstIndex(of: ",") {
                if dotIdx < commaIdx {
                    // European format 1.250,50
                    clean = clean.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                } else {
                    // Standard format 1,250.50
                    clean = clean.replacingOccurrences(of: ",", with: "")
                }
            }
        } else if clean.contains(",") {
            clean = clean.replacingOccurrences(of: ",", with: ".")
        }
        return Double(clean)
    }
    
    private func isSubtotalLine(_ lower: String) -> Bool {
        return lower.contains("subtotal") ||
               lower.contains("sub total") ||
               lower.contains("sub-total") ||
               lower.contains("sous-total") ||
               lower.contains("sous total") ||
               lower.contains("zwischensumme")
    }
    
    private func isTaxLine(_ lower: String) -> Bool {
        return lower.contains("tax") ||
               lower.contains("taxe") ||
               lower.contains("tva") ||
               lower.contains("vat") ||
               lower.contains("mwst") ||
               lower.contains("gst") ||
               lower.contains("hst") ||
               lower.contains("tps") ||
               lower.contains("tvq") ||
               lower.contains("impuesto") ||
               lower.contains("impôt")
    }
    
    private func isTipLine(_ lower: String) -> Bool {
        return lower.contains("tip") ||
               lower.contains("gratuity") ||
               lower.contains("pourboire") ||
               lower.contains("propina") ||
               lower.contains("service charge") ||
               lower.contains("trinkgeld")
    }
    
    private func isTotalLine(_ lower: String) -> Bool {
        return lower.contains("total") ||
               lower.contains("total due") ||
               lower.contains("amount due") ||
               lower.contains("grand total") ||
               lower.contains("balance due") ||
               lower.contains("total ttc") ||
               lower.contains("total ht") ||
               lower.contains("total à payer") ||
               lower.contains("endsumme") ||
               lower.contains("gesamtsumme")
    }
    
    private func isHeaderOrFooterNoise(_ lower: String) -> Bool {
        let noiseKeywords = [
            "thank you", "merci", "welcome", "bienvenue", "quittung",
            "receipt", "invoice", "facture", "order #", "table #",
            "guest", "server", "cashier", "date:", "time:", "visa",
            "mastercard", "amex", "change due", "cash", "credit card",
            "terminal", "merchant", "approved", "customer copy"
        ]
        return noiseKeywords.contains(where: { lower.contains($0) })
    }
    
    private func cleanTitle(_ title: String, fallbackIndex: Int) -> String {
        var clean = title
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "₹", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Strip leading item bullet points or numbers like "1. ", "2) "
        if let leadingNumRegex = try? NSRegularExpression(pattern: #"^\d+[\.\)\-]\s*"#, options: []) {
            let range = NSRange(location: 0, length: clean.utf16.count)
            clean = leadingNumRegex.stringByReplacingMatches(in: clean, options: [], range: range, withTemplate: "")
        }
        
        clean = clean.trimmingCharacters(in: CharacterSet(charactersIn: " -:.,*#"))
        if clean.isEmpty {
            return "Line Item #\(fallbackIndex)"
        }
        return clean
    }
}
