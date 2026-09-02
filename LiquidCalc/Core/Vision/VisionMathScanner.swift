//
//  VisionMathScanner.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Robust Intelligent Math OCR & Multi-Line Receipt NLP Engine
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

public final class VisionMathScanner: Sendable {
    public init() {}
    
    #if canImport(Vision)
    /// Scans a CGImage for mathematical expressions and text using Apple Vision VNRecognizeTextRequest
    public func scanImage(_ cgImage: CGImage, completion: @escaping @Sendable (Result<[ScannedTextObservation], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    completion(.success([]))
                    return
                }
                
                let scanner = VisionMathScanner()
                let scannedItems: [ScannedTextObservation] = observations.compactMap { obs in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    let raw = candidate.string
                    let sanitized = scanner.sanitizeMathString(raw)
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
            request.usesLanguageCorrection = false
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }
    #endif
    
    // MARK: - Mathematical String Sanitizer & Heuristic Normalizer
    
    public func sanitizeMathString(_ input: String) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Strip trailing question marks and placeholders: e.g. "5 + 3 = ?" -> "5 + 3 ="
        text = text.replacingOccurrences(of: "\\?", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\.{2,}", with: "", options: .regularExpression)
        
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
        
        // Normalize Unicode superscripts
        let superscripts: [String: String] = [
            "⁰": "^0", "¹": "^1", "²": "^2", "³": "^3", "⁴": "^4",
            "⁵": "^5", "⁶": "^6", "⁷": "^7", "⁸": "^8", "⁹": "^9",
            "⁺": "^+", "⁻": "^-"
        ]
        for (sup, standard) in superscripts {
            text = text.replacingOccurrences(of: sup, with: standard)
        }
        
        // Common OCR operator replacements
        text = text.replacingOccurrences(of: "×", with: "*")
        text = text.replacingOccurrences(of: "÷", with: "/")
        text = text.replacingOccurrences(of: "−", with: "-")
        text = text.replacingOccurrences(of: "—", with: "-")
        text = text.replacingOccurrences(of: "–", with: "-")
        text = text.replacingOccurrences(of: "·", with: "*")
        text = text.replacingOccurrences(of: "•", with: "*")
        text = text.replacingOccurrences(of: "SQRT", with: "sqrt")
        text = text.replacingOccurrences(of: "√", with: "sqrt")
        text = text.replacingOccurrences(of: "∛", with: "cbrt")
        text = text.replacingOccurrences(of: "π", with: "pi")
        
        // Insert implicit multiplication: e.g. "5(3+2)" -> "5*(3+2)" or "(2+3)(4+5)" -> "(2+3)*(4+5)"
        if let parenMultRegex = try? NSRegularExpression(pattern: #"(\d+)\s*\("#, options: []) {
            let range = NSRange(location: 0, length: text.utf16.count)
            text = parenMultRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1 * (")
        }
        if let closeParenRegex = try? NSRegularExpression(pattern: #"\)\s*(\d+|\()"#, options: []) {
            let range = NSRange(location: 0, length: text.utf16.count)
            text = closeParenRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: ") * $1")
        }
        
        // Fix letter 'x' or 'X' as multiplication when between numbers (e.g. "5 x 4" -> "5 * 4")
        if let multXRegex = try? NSRegularExpression(pattern: #"(\d+)\s*[xX]\s*(\d+)"#, options: []) {
            let range = NSRange(location: 0, length: text.utf16.count)
            text = multXRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1 * $2")
        }
        
        // Fix implicit coefficient multiplication: "5x" -> "5*x" (if variable equation)
        if let coeffRegex = try? NSRegularExpression(pattern: #"(\d+)\s*([a-zA-Z])"#, options: []) {
            let range = NSRange(location: 0, length: text.utf16.count)
            text = coeffRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1 * $2")
        }
        
        // Clean trailing equals: "5 + 3 =" -> "5 + 3" (unless it's an algebraic equation like "2x + 4 = 10")
        if text.hasSuffix("=") {
            text.removeLast()
        }
        if text.hasPrefix("=") {
            text.removeFirst()
        }
        
        text = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
        return text
    }
    
    // MARK: - Intelligent Multi-Line Receipt NLP Parser
    
    public func parseReceipt(from observations: [ScannedTextObservation]) -> ReceiptParseResult {
        var items: [ReceiptLineItem] = []
        var detectedSubtotal: Double? = nil
        var detectedTax: Double? = nil
        var detectedTotal: Double? = nil
        
        // 1. Currency Detection
        var currencyCounts: [SupportedCurrency: Int] = [:]
        for obs in observations {
            if let cur = SupportedCurrency.detect(from: obs.rawText) {
                currencyCounts[cur, default: 0] += 1
            }
        }
        let detectedCurrency = currencyCounts.max(by: { $0.value < $1.value })?.key ?? .usd
        
        // Strict Price Regex: must have explicit currency symbol OR exactly 2 decimals
        // Pattern 1: $30.00, 30.00 MAD, 18,50 €
        // Pattern 2: 30.00 (with decimal point/comma)
        let pricePattern = #"(?:[\$€£¥₹]|CA\$|A\$|R\$|CHF|MAD|DH|Dhs|EUR|GBP|JPY|CAD|AUD|INR|BRL|د\.م\.|円)\s*(\d{1,5}(?:[.,]\d{1,2})?)|(\d{1,5}[.,]\d{2})\s*(?:[\$€£¥₹]|CA\$|A\$|R\$|CHF|MAD|DH|Dhs|EUR|GBP|JPY|CAD|AUD|INR|BRL|د\.م\.|円)?"#
        guard let priceRegex = try? NSRegularExpression(pattern: pricePattern, options: [.caseInsensitive]) else {
            return ReceiptParseResult(detectedCurrency: detectedCurrency)
        }
        
        var pendingMultiLineDescription = ""
        
        for obs in observations {
            let text = obs.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            
            let lower = text.lowercased()
            
            // Check for Summary Lines (Subtotal, Tax, Tip, Total)
            if isTotalLine(lower) {
                let range = NSRange(location: 0, length: text.utf16.count)
                if let match = priceRegex.firstMatch(in: text, options: [], range: range) {
                    let priceStr = extractPriceString(from: text, match: match)
                    if let amt = parseAmount(priceStr) {
                        detectedTotal = amt
                    }
                }
                pendingMultiLineDescription = ""
                continue
            }
            
            if isSubtotalLine(lower) {
                let range = NSRange(location: 0, length: text.utf16.count)
                if let match = priceRegex.firstMatch(in: text, options: [], range: range) {
                    let priceStr = extractPriceString(from: text, match: match)
                    if let amt = parseAmount(priceStr) {
                        detectedSubtotal = amt
                    }
                }
                pendingMultiLineDescription = ""
                continue
            }
            
            if isTaxLine(lower) {
                let range = NSRange(location: 0, length: text.utf16.count)
                if let match = priceRegex.firstMatch(in: text, options: [], range: range) {
                    let priceStr = extractPriceString(from: text, match: match)
                    if let amt = parseAmount(priceStr) {
                        detectedTax = amt
                    }
                }
                pendingMultiLineDescription = ""
                continue
            }
            
            if isTipLine(lower) {
                pendingMultiLineDescription = ""
                continue
            }
            
            // Filter out non-item noise (dates, times, addresses, phone numbers, merchant info)
            if isHeaderOrFooterNoise(text) {
                pendingMultiLineDescription = ""
                continue
            }
            
            let range = NSRange(location: 0, length: text.utf16.count)
            let matches = priceRegex.matches(in: text, options: [], range: range)
            
            if let lastMatch = matches.last {
                let priceStr = extractPriceString(from: text, match: lastMatch)
                guard let amount = parseAmount(priceStr), amount > 0.05 else {
                    continue
                }
                
                // Extract Item Title
                var rawTitle = text
                if let matchRange = Range(lastMatch.range, in: text) {
                    rawTitle.removeSubrange(matchRange)
                }
                
                // Combine with pending multi-line description if available
                var combinedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !pendingMultiLineDescription.isEmpty {
                    combinedTitle = "\(pendingMultiLineDescription) \(combinedTitle)".trimmingCharacters(in: .whitespacesAndNewlines)
                    pendingMultiLineDescription = ""
                }
                
                let title = cleanTitle(combinedTitle, fallbackIndex: items.count + 1)
                
                // Add valid line item
                if !title.isEmpty {
                    items.append(ReceiptLineItem(title: title, amount: amount))
                }
            } else {
                // Multi-line item description continuation (e.g. "Lorem ipsum dolor sit")
                if text.count > 2 && !text.hasPrefix("-") && !text.hasPrefix("=") {
                    pendingMultiLineDescription = text
                }
            }
        }
        
        // Reconcile Subtotal if not detected
        let computedSubtotal = items.reduce(0.0) { $0 + $1.amount }
        let finalSubtotal = detectedSubtotal ?? computedSubtotal
        let finalTotal = detectedTotal ?? finalSubtotal
        
        return ReceiptParseResult(
            items: items,
            detectedCurrency: detectedCurrency,
            detectedSubtotal: finalSubtotal,
            detectedTax: detectedTax,
            detectedTotal: finalTotal
        )
    }
    
    public func parseReceiptItems(from observations: [ScannedTextObservation]) -> [ReceiptLineItem] {
        parseReceipt(from: observations).items
    }
    
    // MARK: - Private Helpers
    
    private func extractPriceString(from text: String, match: NSTextCheckingResult) -> String {
        // Group 1 (with currency prefix) or Group 2 (decimal without currency)
        if match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound {
            if let r = Range(match.range(at: 1), in: text) {
                return String(text[r])
            }
        }
        if match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound {
            if let r = Range(match.range(at: 2), in: text) {
                return String(text[r])
            }
        }
        if let r = Range(match.range, in: text) {
            return String(text[r])
        }
        return ""
    }
    
    private func parseAmount(_ string: String) -> Double? {
        var clean = string.trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "MAD", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "DH", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "CHF", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if clean.contains(".") && clean.contains(",") {
            if let dot = clean.firstIndex(of: "."), let comma = clean.firstIndex(of: ",") {
                if dot < comma {
                    clean = clean.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                } else {
                    clean = clean.replacingOccurrences(of: ",", with: "")
                }
            }
        } else if clean.contains(",") {
            clean = clean.replacingOccurrences(of: ",", with: ".")
        }
        return Double(clean)
    }
    
    private func isSubtotalLine(_ lower: String) -> Bool {
        lower.contains("subtotal") || lower.contains("sub total") ||
        lower.contains("sous-total") || lower.contains("sous total") ||
        lower.contains("sub-total") || lower.contains("zwischensumme")
    }
    
    private func isTaxLine(_ lower: String) -> Bool {
        lower.contains("tax") || lower.contains("taxe") ||
        lower.contains("tva") || lower.contains("vat") ||
        lower.contains("gst") || lower.contains("hst") ||
        lower.contains("mwst") || lower.contains("tvq")
    }
    
    private func isTipLine(_ lower: String) -> Bool {
        lower.contains("tip") || lower.contains("gratuity") ||
        lower.contains("pourboire") || lower.contains("service charge")
    }
    
    private func isTotalLine(_ lower: String) -> Bool {
        lower.contains("total") || lower.contains("total due") ||
        lower.contains("amount due") || lower.contains("grand total") ||
        lower.contains("total ttc") || lower.contains("total à payer") ||
        lower.contains("net payable")
    }
    
    private func isHeaderOrFooterNoise(_ text: String) -> Bool {
        let lower = text.lowercased()
        
        // 1. Separators & Dashes: "-----", "======", "******"
        if text.range(of: #"^[\s\-=_*#~.]{3,}$"#, options: .regularExpression) != nil {
            return true
        }
        
        // 2. Dates (e.g. 02/05/2023, 2023-05-02, 02.05.2023)
        if text.range(of: #"\b\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}\b"#, options: .regularExpression) != nil {
            return true
        }
        
        // 3. Times (e.g. 11:58:20 AM, 23:45)
        if lower.range(of: #"\b\d{1,2}:\d{2}(?::\d{2})?\s*(?:am|pm)?\b"#, options: .regularExpression) != nil {
            return true
        }
        
        // 4. Card Numbers & Masked PAN (e.g. xxxx 1234, Visa/5544)
        if lower.range(of: #"x{3,}|[*]{3,}|\bvisa\b|\bmastercard\b|\bamex\b|\bdiscover\b"#, options: .regularExpression) != nil {
            return true
        }
        
        // 5. Postal codes (e.g. BC X5T5C2, 90210)
        if text.range(of: #"\b[A-Z]\d[A-Z]\s*\d[A-Z]\d\b"#, options: .regularExpression) != nil {
            return true
        }
        
        // 6. Address & Location Keywords
        let addressKeywords = [
            "address", "apt", "apt.", "suite", "ste", "ste.", "floor", "fl.", "box", "p.o.",
            "street", "st.", "avenue", "ave", "ave.", "road", "rd", "rd.", "blvd", "boulevard",
            "drive", "dr.", "lane", "ln", "gardens", "pkwy", "highway", "hwy",
            "city", "state", "zip", "postal", "province"
        ]
        for kw in addressKeywords {
            if lower.range(of: "\\b" + kw + "\\b", options: .regularExpression) != nil {
                return true
            }
        }
        
        // 7. Metadata / Staff / Greetings
        let metaKeywords = [
            "receipt", "invoice", "facture", "ticket", "bill", "order", "table",
            "manager", "server", "cashier", "waiter", "guest", "host", "pos",
            "terminal", "merchant", "auth", "approval", "tax id", "reg #", "vat #",
            "tel", "phone", "fax", "www.", "http", "thank you", "welcome", "merci"
        ]
        for kw in metaKeywords {
            if lower.range(of: "\\b" + kw + "\\b", options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func cleanTitle(_ title: String, fallbackIndex: Int) -> String {
        var clean = title
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: "\\.{2,}", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let numRegex = try? NSRegularExpression(pattern: #"^\d+[\.\)\-xX]\s*"#, options: []) {
            let range = NSRange(location: 0, length: clean.utf16.count)
            clean = numRegex.stringByReplacingMatches(in: clean, options: [], range: range, withTemplate: "")
        }
        
        clean = clean.trimmingCharacters(in: CharacterSet(charactersIn: " -:.,*#_"))
        return clean.isEmpty ? "Item #\(fallbackIndex)" : clean
    }
}
