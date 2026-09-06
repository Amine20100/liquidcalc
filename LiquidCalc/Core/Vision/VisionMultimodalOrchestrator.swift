//
//  VisionMultimodalOrchestrator.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Unified Multimodal AI & On-Device Vision Intelligence Orchestrator
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

public enum VisionSolutionSource: String, Sendable {
    case onDeviceEngine = "On-Device Neural Engine"
    case multimodalAI = "Gemini 2.5 Flash Multimodal AI"
}

public struct VisionSolution: Equatable, Sendable {
    public let expression: String
    public let result: String
    public let steps: [String]
    public let explanation: String?
    public let source: VisionSolutionSource
    
    public init(
        expression: String,
        result: String,
        steps: [String] = [],
        explanation: String? = nil,
        source: VisionSolutionSource = .onDeviceEngine
    ) {
        self.expression = expression
        self.result = result
        self.steps = steps
        self.explanation = explanation
        self.source = source
    }
}

public struct ReceiptBreakdown: Equatable, Sendable {
    public let storeName: String?
    public let currency: SupportedCurrency
    public let items: [ReceiptLineItem]
    public let subtotal: Double
    public let tax: Double
    public let tip: Double
    public let total: Double
    public let splitPerPerson: Double
    public let source: VisionSolutionSource
    
    public init(
        storeName: String? = nil,
        currency: SupportedCurrency = .usd,
        items: [ReceiptLineItem] = [],
        subtotal: Double = 0.0,
        tax: Double = 0.0,
        tip: Double = 0.0,
        total: Double = 0.0,
        splitPerPerson: Double = 0.0,
        source: VisionSolutionSource = .onDeviceEngine
    ) {
        self.storeName = storeName
        self.currency = currency
        self.items = items
        self.subtotal = subtotal
        self.tax = tax
        self.tip = tip
        self.total = total
        self.splitPerPerson = splitPerPerson
        self.source = source
    }
}

public final class VisionMultimodalOrchestrator: Sendable {
    public static let shared = VisionMultimodalOrchestrator()
    
    private let evaluator = MathEvaluator(angleUnit: .degrees)
    private let scanner = VisionMathScanner()
    private let algebraicSolver = AlgebraicSolver.shared
    private let calculusEngine = CalculusEngine.shared
    
    public init() {}
    
    // MARK: - Unified Math Problem Solver (On-Device + Cloud AI Fallback)
    
    #if canImport(UIKit)
    public func solveMathProblem(
        expression: String,
        image: UIImage? = nil,
        preferAI: Bool = true
    ) async -> VisionSolution {
        let clean = scanner.sanitizeMathString(expression)
        
        // 1. Try Gemini 2.5 Flash Multimodal AI if requested
        if preferAI {
            do {
                let aiResponse = try await GeminiService.shared.solveMath(image: image, expressionText: clean.isEmpty ? nil : clean)
                return VisionSolution(
                    expression: aiResponse.expression.isEmpty ? clean : aiResponse.expression,
                    result: aiResponse.result,
                    steps: aiResponse.steps,
                    explanation: aiResponse.explanation,
                    source: .multimodalAI
                )
            } catch {
                // Seamless fallback to On-Device solver
            }
        }
        
        // 2. On-Device Solver Fallback
        return solveOnDevice(expression: clean)
    }
    #else
    public func solveMathProblem(expression: String) -> VisionSolution {
        let clean = scanner.sanitizeMathString(expression)
        return solveOnDevice(expression: clean)
    }
    #endif
    
    public func solveOnDevice(expression: String) -> VisionSolution {
        let clean = scanner.sanitizeMathString(expression)
        guard !clean.isEmpty else {
            return VisionSolution(expression: expression, result: "Empty Expression", steps: [], source: .onDeviceEngine)
        }
        
        // A. Check for Calculus: Derivatives or Integrals
        if let calculusSol = parseAndSolveCalculus(clean) {
            return calculusSol
        }
        
        // B. Check for Quadratic Equation: ax^2 + bx + c = 0
        if clean.contains("^2") || clean.contains("²") {
            if let quad = parseAndSolveQuadratic(clean) {
                return VisionSolution(
                    expression: clean,
                    result: "x₁ = \(quad.root1String), x₂ = \(quad.root2String)",
                    steps: quad.steps,
                    explanation: "Solved using on-device quadratic formula with discriminant Δ = \(quad.discriminant)",
                    source: .onDeviceEngine
                )
            }
        }
        
        // B. Check for Linear Equation: ax + b = c
        if clean.contains("=") && (clean.contains("x") || clean.contains("X")) {
            if let (res, steps) = solveLinearEquation(clean) {
                return VisionSolution(
                    expression: clean,
                    result: res,
                    steps: steps,
                    explanation: "Solved linear equation on-device using algebraic balance.",
                    source: .onDeviceEngine
                )
            }
        }
        
        // C. Standard Arithmetic Evaluation
        let mathOnly = clean.replacingOccurrences(of: "=", with: "").trimmingCharacters(in: .whitespaces)
        if let val = try? evaluator.evaluate(expression: mathOnly) {
            let formatted = MathEvaluator.formatResult(val)
            return VisionSolution(
                expression: clean,
                result: formatted,
                steps: [
                    "Input expression: \(mathOnly)",
                    "Evaluated with operator precedence: \(formatted)"
                ],
                explanation: "Evaluated using LiquidCalc high-precision math evaluator.",
                source: .onDeviceEngine
            )
        }
        
        return VisionSolution(
            expression: clean,
            result: "Unresolved",
            steps: ["Expression could not be evaluated symbolically."],
            explanation: nil,
            source: .onDeviceEngine
        )
    }
    
    // MARK: - Unified Receipt Processing (On-Device + Cloud AI Fallback)
    
    #if canImport(UIKit)
    public func processReceipt(
        observations: [ScannedTextObservation],
        image: UIImage? = nil,
        preferAI: Bool = true,
        tipPercent: Double = 18.0,
        splitCount: Int = 1
    ) async -> ReceiptBreakdown {
        // 1. Try Gemini 2.5 Flash Multimodal Receipt AI
        if preferAI, let img = image {
            do {
                let aiReceipt = try await GeminiService.shared.analyzeReceipt(image: img)
                var items: [ReceiptLineItem] = []
                for it in aiReceipt.items {
                    items.append(ReceiptLineItem(title: it.name, amount: it.price))
                }
                
                let cur = aiReceipt.currency.flatMap { SupportedCurrency(rawValue: $0.uppercased()) } ?? .usd
                let subtotal = aiReceipt.subtotal ?? items.reduce(0.0) { $0 + $1.amount }
                let tax = aiReceipt.tax ?? 0.0
                let tip = subtotal * (tipPercent / 100.0)
                let total = aiReceipt.total ?? (subtotal + tax + tip)
                let perPerson = splitCount > 0 ? total / Double(splitCount) : total
                
                return ReceiptBreakdown(
                    storeName: aiReceipt.storeName,
                    currency: cur,
                    items: items,
                    subtotal: subtotal,
                    tax: tax,
                    tip: tip,
                    total: total,
                    splitPerPerson: perPerson,
                    source: .multimodalAI
                )
            } catch {
                // Fall back to On-Device NLP
            }
        }
        
        // 2. On-Device Local NLP Fallback
        return processReceiptOnDevice(observations: observations, tipPercent: tipPercent, splitCount: splitCount)
    }
    #endif
    
    public func processReceiptOnDevice(
        observations: [ScannedTextObservation],
        tipPercent: Double = 18.0,
        splitCount: Int = 1
    ) -> ReceiptBreakdown {
        let parsed = scanner.parseReceipt(from: observations)
        let subtotal = parsed.detectedSubtotal ?? parsed.items.reduce(0.0) { $0 + $1.amount }
        let tax = parsed.detectedTax ?? 0.0
        let tip = subtotal * (tipPercent / 100.0)
        let total = parsed.detectedTotal ?? (subtotal + tax + tip)
        let perPerson = splitCount > 0 ? total / Double(splitCount) : total
        
        return ReceiptBreakdown(
            storeName: nil,
            currency: parsed.detectedCurrency,
            items: parsed.items,
            subtotal: subtotal,
            tax: tax,
            tip: tip,
            total: total,
            splitPerPerson: perPerson,
            source: .onDeviceEngine
        )
    }
    
    // MARK: - Private Equation & Calculus Solvers
    
    /// Evaluates a mathematical function string with variable x replaced by a specific Double value.
    public func evaluateWithX(_ expr: String, x: Double) -> Double {
        var s = expr
        // Insert implicit multiplication: e.g. 3x -> 3*(x)
        s = s.replacingOccurrences(of: #"(\d)([xX])"#, with: "$1*($2)", options: .regularExpression)
        // Replace isolated x or X with value (so we don't replace 'x' in 'exp')
        s = s.replacingOccurrences(of: #"(?<![a-zA-Z])([xX])(?![a-zA-Z])"#, with: "(\(x))", options: .regularExpression)
        return (try? evaluator.evaluate(expression: s)) ?? Double.nan
    }
    
    private func parseAndSolveCalculus(_ expr: String) -> VisionSolution? {
        let lower = expr.lowercased()
        
        // 1. Derivative: d/dx(f(x)) [at x = a] or derivative of f(x) [at x=a]
        if lower.contains("d/dx") || lower.contains("derivative") {
            var formula = ""
            var xVal: Double = 1.0 // default evaluation point if not specified
            
            if let regex = try? NSRegularExpression(pattern: #"(?:d\/dx|derivative\s+of)\s*\(?([^()]+?)\)?(?:\s+(?:at\s+)?x\s*=\s*([+-]?\d+(?:\.\d+)?))?$"#, options: [.caseInsensitive]),
               let m = regex.firstMatch(in: expr, options: [], range: NSRange(location: 0, length: expr.utf16.count)) {
                if m.range(at: 1).location != NSNotFound, let r1 = Range(m.range(at: 1), in: expr) {
                    formula = String(expr[r1]).trimmingCharacters(in: .whitespaces)
                }
                if m.range(at: 2).location != NSNotFound, let r2 = Range(m.range(at: 2), in: expr) {
                    if let parsedX = Double(String(expr[r2])) {
                        xVal = parsedX
                    }
                }
            } else if lower.hasPrefix("d/dx") {
                formula = expr.replacingOccurrences(of: "d/dx", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            
            guard !formula.isEmpty else { return nil }
            
            let deriv = calculusEngine.derivative(at: xVal) { [self] x in
                evaluateWithX(formula, x: x)
            }
            
            guard deriv.isFinite else { return nil }
            let formattedResult = MathEvaluator.formatResult(deriv)
            let steps = [
                "Target function: f(x) = \(formula)",
                "Evaluation point: x = \(MathEvaluator.formatResult(xVal))",
                "Applied 5-point central difference numerical stencil: f'(x) ≈ (-f(x+2h) + 8f(x+h) - 8f(x-h) + f(x-2h)) / (12h)",
                "Calculated numerical derivative: f'(\(MathEvaluator.formatResult(xVal))) = \(formattedResult)"
            ]
            return VisionSolution(
                expression: expr,
                result: "f'(\(MathEvaluator.formatResult(xVal))) = \(formattedResult)",
                steps: steps,
                explanation: "Numerical differentiation evaluated with LiquidCalc CalculusEngine.",
                source: .onDeviceEngine
            )
        }
        
        // 2. Definite Integral: ∫[a, b] f(x) dx or int(a, b, f(x)) or integral from a to b of f(x)
        if lower.contains("∫") || lower.contains("int") || lower.contains("integral") {
            var a: Double = 0.0
            var b: Double = 1.0
            var formula = ""
            
            let integralPattern = #"(?:∫|integral|int)\s*(?:\[|\()?\s*([+-]?\d+(?:\.\d+)?)\s*(?:,|\s+to\s+|\.\.)\s*([+-]?\d+(?:\.\d+)?)\s*(?:\]|\))?\s*(?:of\s+)?(.+?)(?:\s*dx)?$"#
            if let regex = try? NSRegularExpression(pattern: integralPattern, options: [.caseInsensitive]),
               let m = regex.firstMatch(in: expr, options: [], range: NSRange(location: 0, length: expr.utf16.count)) {
                if m.range(at: 1).location != NSNotFound, let r1 = Range(m.range(at: 1), in: expr), let parsedA = Double(String(expr[r1])) {
                    a = parsedA
                }
                if m.range(at: 2).location != NSNotFound, let r2 = Range(m.range(at: 2), in: expr), let parsedB = Double(String(expr[r2])) {
                    b = parsedB
                }
                if m.range(at: 3).location != NSNotFound, let r3 = Range(m.range(at: 3), in: expr) {
                    formula = String(expr[r3]).trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "dx", with: "", options: .caseInsensitive)
                        .trimmingCharacters(in: .whitespaces)
                }
            }
            
            guard !formula.isEmpty else { return nil }
            
            let intVal = calculusEngine.integrate(from: a, to: b, intervals: 1000) { [self] x in
                evaluateWithX(formula, x: x)
            }
            
            guard intVal.isFinite else { return nil }
            let formattedResult = MathEvaluator.formatResult(intVal)
            let steps = [
                "Integrand: f(x) = \(formula) on [\(MathEvaluator.formatResult(a)), \(MathEvaluator.formatResult(b))]",
                "Applied adaptive composite Simpson's 3/8 rule with 1000 subintervals",
                "Numerical definite integral result: \(formattedResult)"
            ]
            return VisionSolution(
                expression: expr,
                result: formattedResult,
                steps: steps,
                explanation: "Definite integral area evaluated with LiquidCalc CalculusEngine.",
                source: .onDeviceEngine
            )
        }
        
        return nil
    }
    
    private func parseAndSolveQuadratic(_ expr: String) -> QuadraticSolution? {
        // 1. Direct Pattern Match: ax^2 + bx + c = 0
        var s = expr.replacingOccurrences(of: "²", with: "^2").replacingOccurrences(of: "= 0", with: "").replacingOccurrences(of: "=0", with: "")
        s = s.replacingOccurrences(of: " ", with: "")
        
        let pattern = #"^([+-]?\d*(?:\.\d+)?)x\^2([+-]?\d*(?:\.\d+)?)x([+-]?\d*(?:\.\d+)?)$"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: s, options: [], range: NSRange(location: 0, length: s.utf16.count)) {
            
            func extractCoeff(at index: Int, defaultVal: Double) -> Double {
                guard match.range(at: index).location != NSNotFound,
                      let r = Range(match.range(at: index), in: s) else { return defaultVal }
                let str = String(s[r])
                if str.isEmpty || str == "+" { return 1.0 }
                if str == "-" { return -1.0 }
                return Double(str) ?? defaultVal
            }
            
            let a = extractCoeff(at: 1, defaultVal: 1.0)
            let b = extractCoeff(at: 2, defaultVal: 0.0)
            let c = extractCoeff(at: 3, defaultVal: 0.0)
            
            if abs(a) > 1e-12 {
                return algebraicSolver.solveQuadratic(a: a, b: b, c: c)
            }
        }
        
        // 2. Numerical Polynomial Sampling (handles missing linear/constant terms, e.g. x^2 - 4 = 0, 2x^2 = 8)
        let parts = expr.split(separator: "=")
        let leftExpr = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let rightVal = parts.count > 1 ? ((try? evaluator.evaluate(expression: String(parts[1]).trimmingCharacters(in: .whitespaces))) ?? 0.0) : 0.0
        
        let f0 = evaluateWithX(leftExpr, x: 0) - rightVal
        let f1 = evaluateWithX(leftExpr, x: 1) - rightVal
        let fm1 = evaluateWithX(leftExpr, x: -1) - rightVal
        let f2 = evaluateWithX(leftExpr, x: 2) - rightVal
        
        guard f0.isFinite, f1.isFinite, fm1.isFinite, f2.isFinite else { return nil }
        
        let c = f0
        let a = (f1 + fm1 - 2.0 * c) / 2.0
        let b = (f1 - fm1) / 2.0
        
        let expectedF2 = 4.0 * a + 2.0 * b + c
        guard abs(a) > 1e-6, abs(f2 - expectedF2) < 1e-4 else { return nil }
        
        return algebraicSolver.solveQuadratic(a: a, b: b, c: c)
    }
    
    private func solveLinearEquation(_ expr: String) -> (String, [String])? {
        let parts = expr.split(separator: "=")
        guard parts.count == 2 else { return nil }
        
        let left = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let right = String(parts[1]).trimmingCharacters(in: .whitespaces)
        
        guard let rightVal = try? evaluator.evaluate(expression: right) else { return nil }
        
        let b = evaluateWithX(left, x: 0)
        let f1 = evaluateWithX(left, x: 1)
        
        guard b.isFinite, f1.isFinite else { return nil }
        
        let a = f1 - b
        guard abs(a) > 1e-12 else { return nil }
        
        let x = (rightVal - b) / a
        let formatted = MathEvaluator.formatResult(x)
        let (_, steps) = algebraicSolver.solveLinear(a: a, b: b, c: rightVal)
        let resStr = "x = \(formatted)"
        return (resStr, steps.isEmpty ? ["Isolated x: \(resStr)"] : steps)
    }
}
