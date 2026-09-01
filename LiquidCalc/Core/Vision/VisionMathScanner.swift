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

public struct ScannedTextObservation: Identifiable, Equatable {
    public let id = UUID()
    public let rawText: String
    public let sanitizedExpression: String
    public let boundingBox: CGRect
    public let confidence: Float
    
    public init(rawText: String, sanitizedExpression: String, boundingBox: CGRect, confidence: Float) {
        self.rawText = rawText
        self.sanitizedExpression = sanitizedExpression
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

public struct ReceiptLineItem: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let amount: Double
    
    public init(title: String, amount: Double) {
        self.title = title
        self.amount = amount
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
        
        // Common OCR replacements
        text = text.replacingOccurrences(of: "×", with: "*")
        text = text.replacingOccurrences(of: "÷", with: "/")
        text = text.replacingOccurrences(of: "−", with: "-")
        text = text.replacingOccurrences(of: "—", with: "-")
        text = text.replacingOccurrences(of: "–", with: "-")
        
        // Fix letter 'x' or 'X' used as multiplication between numbers (e.g. 5x4 or 5 x 4)
        if let regex = try? NSRegularExpression(pattern: #"(\d+)\s*[xX]\s*(\d+)"#, options: []) {
            let range = NSRange(location: 0, length: text.utf16.count)
            text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1 * $2")
        }
        
        // Replace square root words or symbols
        text = text.replacingOccurrences(of: "sqrt", with: "sqrt")
        text = text.replacingOccurrences(of: "SQRT", with: "sqrt")
        text = text.replacingOccurrences(of: "√", with: "sqrt")
        
        // Replace pi symbols
        text = text.replacingOccurrences(of: "π", with: "pi")
        
        // Clean multiple spaces
        text = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
        
        return text
    }
    
    /// Parses line items from a receipt or bill
    public func parseReceiptItems(from observations: [ScannedTextObservation]) -> [ReceiptLineItem] {
        var items: [ReceiptLineItem] = []
        
        // Regex to match currency or decimal amounts: e.g. "$12.99" or "45.00"
        let priceRegex = try? NSRegularExpression(pattern: #"\$?\s*(\d+[.,]\d{2})\b"#, options: [])
        
        for obs in observations {
            let text = obs.rawText
            let range = NSRange(location: 0, length: text.utf16.count)
            
            if let match = priceRegex?.firstMatch(in: text, options: [], range: range) {
                if let priceRange = Range(match.range(at: 1), in: text) {
                    let priceString = String(text[priceRange]).replacingOccurrences(of: ",", with: ".")
                    if let amount = Double(priceString), amount > 0 {
                        // Title is whatever precedes the price
                        var title = text
                        if let fullMatchRange = Range(match.range, in: text) {
                            title = String(text[..<fullMatchRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        if title.isEmpty {
                            title = "Line Item #\(items.count + 1)"
                        }
                        items.append(ReceiptLineItem(title: title, amount: amount))
                    }
                }
            }
        }
        
        return items
    }
}
