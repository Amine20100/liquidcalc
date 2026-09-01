//
//  HandwritingMathRecognizer.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  On-Device Handwriting Math Recognition & Real-Time Evaluator
//

import Foundation
import CoreGraphics
#if canImport(Vision)
import Vision
#endif
#if canImport(UIKit)
import UIKit
#endif

public struct HandwritingMathResult: Equatable, Sendable {
    public let recognizedText: String
    public let sanitizedExpression: String
    public let solvedResult: String?
    public let isEquation: Bool
    public let boundingBox: CGRect
}

public final class HandwritingMathRecognizer: @unchecked Sendable {
    public static let shared = HandwritingMathRecognizer()
    
    private let scanner = VisionMathScanner()
    private let evaluator = MathEvaluator(angleUnit: .degrees)
    
    public init() {}
    
    #if canImport(UIKit)
    /// Renders strokes onto a high-contrast UIImage for Vision and Gemini AI multimodal processing
    public func renderImage(from strokes: [DrawingStroke], canvasSize: CGSize) -> UIImage? {
        guard !strokes.isEmpty, canvasSize.width > 10, canvasSize.height > 10 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))
            
            ctx.cgContext.setLineCap(.round)
            ctx.cgContext.setLineJoin(.round)
            
            for stroke in strokes {
                guard stroke.tool != .eraser, stroke.points.count > 1 else { continue }
                ctx.cgContext.setStrokeColor(UIColor.black.cgColor)
                ctx.cgContext.setLineWidth(max(4.0, stroke.lineWidth * 1.5))
                
                let points = stroke.points.map { $0.point }
                ctx.cgContext.beginPath()
                ctx.cgContext.move(to: points[0])
                for i in 1..<points.count {
                    ctx.cgContext.addLine(to: points[i])
                }
                ctx.cgContext.strokePath()
            }
        }
    }
    
    /// Converts strokes to an optimized image and recognizes handwriting via Apple Vision
    public func recognizeStrokes(
        _ strokes: [DrawingStroke],
        canvasSize: CGSize,
        completion: @escaping @Sendable (HandwritingMathResult?) -> Void
    ) {
        guard let image = renderImage(from: strokes, canvasSize: canvasSize), let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        #if canImport(Vision)
        let request = VNRecognizeTextRequest { [weak self] req, err in
            guard let self = self, err == nil,
                  let observations = req.results as? [VNRecognizedTextObservation],
                  !observations.isEmpty else {
                completion(nil)
                return
            }
            
            // Collect all recognized text lines sorted vertically/horizontally
            let sortedObs = observations.sorted { (a, b) -> Bool in
                if abs(a.boundingBox.midY - b.boundingBox.midY) > 0.05 {
                    return a.boundingBox.midY > b.boundingBox.midY
                }
                return a.boundingBox.minX < b.boundingBox.minX
            }
            
            let fullText = sortedObs.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            let sanitized = self.scanner.sanitizeMathString(fullText)
            let solved = self.solveExpression(sanitized)
            
            let overallBounds = sortedObs.reduce(CGRect.null) { $0.union($1.boundingBox) }
            
            let result = HandwritingMathResult(
                recognizedText: fullText,
                sanitizedExpression: sanitized,
                solvedResult: solved,
                isEquation: sanitized.contains("="),
                boundingBox: overallBounds
            )
            
            completion(result)
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(nil)
            }
        }
        #else
        completion(nil)
        #endif
    }
    #endif
    
    // MARK: - Solver
    
    public func solveExpression(_ expr: String) -> String? {
        let clean = expr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        
        // 1. Direct arithmetic evaluate
        if let val = try? evaluator.evaluate(expression: clean) {
            return MathEvaluator.formatResult(val)
        }
        
        // 2. Linear equation solving: 2x + 5 = 15
        if clean.contains("=") && (clean.contains("x") || clean.contains("X")) {
            let parts = clean.split(separator: "=")
            if parts.count == 2 {
                let left = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let right = String(parts[1]).trimmingCharacters(in: .whitespaces)
                if let rightVal = try? evaluator.evaluate(expression: right) {
                    let eval0 = left.replacingOccurrences(of: "x", with: "(0)").replacingOccurrences(of: "X", with: "(0)")
                    let eval1 = left.replacingOccurrences(of: "x", with: "(1)").replacingOccurrences(of: "X", with: "(1)")
                    if let b = try? evaluator.evaluate(expression: eval0),
                       let f1 = try? evaluator.evaluate(expression: eval1) {
                        let a = f1 - b
                        if abs(a) > 1e-12 {
                            let x = (rightVal - b) / a
                            return "x = " + MathEvaluator.formatResult(x)
                        }
                    }
                }
            }
        }
        
        // 3. Strip trailing = sign: "12 * 5 + 4 =" -> 64
        let cleanedMath = clean.replacingOccurrences(of: "=", with: "").trimmingCharacters(in: .whitespaces)
        if let val = try? evaluator.evaluate(expression: cleanedMath) {
            return MathEvaluator.formatResult(val)
        }
        
        return nil
    }
}
