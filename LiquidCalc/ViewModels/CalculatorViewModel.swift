//
//  CalculatorViewModel.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation
import SwiftUI

@Observable
public final class CalculatorViewModel {
    public var expression: String = "" {
        didSet {
            updateLivePreview()
        }
    }
    public var displayResult: String = "0"
    public var livePreview: String? = nil
    public var currentMode: CalculatorMode = .standard
    public var angleUnit: AngleUnit = .degrees {
        didSet {
            evaluator.angleUnit = angleUnit
            updateLivePreview()
        }
    }
    
    public var memoryValue: Double = 0.0
    public var hasMemory: Bool = false
    public var isSecondFunctionActive: Bool = false
    public var hasError: Bool = false
    public var errorMessage: String? = nil
    public var shouldShakeDisplay: Bool = false
    public var evaluationTriggerCount: Int = 0
    
    // Hidden Liquid Signer Stealth Vault State
    public var isUnlockingSigner: Bool = false
    public var showLiquidSigner: Bool = false
    public var secretPIN: String {
        get {
            UserDefaults.standard.string(forKey: "LiquidCalc_SignerSecretPIN") ?? "1337"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "LiquidCalc_SignerSecretPIN")
        }
    }
    
    private let evaluator = MathEvaluator(angleUnit: .degrees)
    private let historyManager = HistoryManager.shared
    
    public init() {}
    
    // MARK: - Input Handling
    
    public func handleButtonPress(_ button: KeypadButton) {
        switch button.type {
        case .digit(let d):
            appendDigit(d)
        case .decimal:
            appendDecimal()
        case .operation(let op):
            appendOperation(op)
        case .parenthesis(let paren):
            appendParenthesis(paren)
        case .scientific(let fn):
            appendFunction(fn)
        case .constant(let c):
            appendConstant(c)
        case .clear:
            clearCurrent()
        case .allClear:
            clearAll()
        case .delete:
            deleteBackward()
        case .signToggle:
            toggleSign()
        case .percent:
            applyPercent()
        case .equals:
            evaluateFinal()
        case .memory(let action):
            handleMemory(action)
        case .hexDigit, .bitwise:
            break
        }
    }
    
    private func appendDigit(_ digit: String) {
        if hasError { clearAll() }
        
        if expression == "0" && digit != "0" {
            expression = digit
        } else if expression != "0" {
            expression += digit
        }
        displayResult = expression
    }
    
    private func appendDecimal() {
        if hasError { clearAll() }
        
        if expression.isEmpty {
            expression = "0."
        } else {
            // Check if last token already has a decimal
            let lastComponent = expression.split { "+-*/^()%".contains($0) }.last ?? ""
            if !lastComponent.contains(".") {
                expression += "."
            }
        }
        displayResult = expression
    }
    
    private func appendOperation(_ op: String) {
        if hasError { hasError = false }
        
        guard !expression.isEmpty else {
            if op == "-" {
                expression = "-"
                displayResult = expression
            }
            return
        }
        
        // If last character is already an operator, replace it (unless it's closing paren)
        let lastChar = expression.last!
        if "+-*/^%".contains(lastChar) {
            expression.removeLast()
        }
        
        expression += op
        displayResult = expression
    }
    
    private func appendParenthesis(_ paren: String) {
        if hasError { clearAll() }
        expression += paren
        displayResult = expression
    }
    
    private func appendFunction(_ fn: String) {
        if hasError { clearAll() }
        
        switch fn {
        case "x²":
            expression += "^2"
        case "x³":
            expression += "^3"
        case "xʸ":
            expression += "^"
        case "10ˣ":
            expression += "10^("
        case "eˣ":
            expression += "e^("
        case "1/x":
            expression = "inv(\(expression))"
        case "x!":
            expression = "fact(\(expression))"
        default:
            // Trig, log, roots, etc.
            expression += "\(fn)("
        }
        displayResult = expression
    }
    
    private func appendConstant(_ c: String) {
        if hasError { clearAll() }
        expression += c
        displayResult = expression
    }
    
    public func clearAll() {
        expression = ""
        displayResult = "0"
        livePreview = nil
        hasError = false
        errorMessage = nil
    }
    
    public func clearCurrent() {
        if hasError {
            clearAll()
        } else {
            expression = ""
            displayResult = "0"
            livePreview = nil
        }
    }
    
    public func deleteBackward() {
        guard !expression.isEmpty else { return }
        expression.removeLast()
        displayResult = expression.isEmpty ? "0" : expression
    }
    
    public func toggleSign() {
        guard !expression.isEmpty else { return }
        
        // If starts with unary minus, strip it, otherwise prefix it
        if expression.hasPrefix("-(") && expression.hasSuffix(")") {
            expression.removeFirst(2)
            expression.removeLast()
        } else if expression.hasPrefix("-") {
            expression.removeFirst()
        } else {
            expression = "-(" + expression + ")"
        }
        displayResult = expression
    }
    
    public func applyPercent() {
        guard !expression.isEmpty else { return }
        expression += "%"
        displayResult = expression
    }
    
    // MARK: - Evaluation
    
    public func evaluateFinal() {
        guard !expression.isEmpty else { return }
        
        // Secret Stealth Code Intercept for Liquid Signer Vault
        if expression.trimmingCharacters(in: .whitespaces) == secretPIN {
            expression = ""
            displayResult = "0"
            livePreview = nil
            hasError = false
            
            SoundAndHapticManager.shared.triggerHaptic(.heavy)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isUnlockingSigner = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                    self.showLiquidSigner = true
                    self.isUnlockingSigner = false
                }
                SoundAndHapticManager.shared.triggerHaptic(.success)
                SoundAndHapticManager.shared.playSuccessSound()
            }
            return
        }
        
        do {
            let result = try evaluator.evaluate(expression: expression)
            let formatted = MathEvaluator.formatResult(result)
            
            // Record to history
            historyManager.addItem(expression: expression, result: formatted, mode: currentMode.rawValue)
            
            displayResult = formatted
            expression = formatted
            livePreview = nil
            hasError = false
            evaluationTriggerCount += 1
        } catch {
            triggerError(error.localizedDescription)
        }
    }
    
    private func updateLivePreview() {
        guard !expression.isEmpty else {
            livePreview = nil
            return
        }
        
        // Attempt speculative evaluation
        if let result = try? evaluator.evaluate(expression: expression) {
            livePreview = MathEvaluator.formatResult(result)
        } else {
            livePreview = nil
        }
    }
    
    private func triggerError(_ message: String) {
        hasError = true
        errorMessage = message
        displayResult = "Error"
        livePreview = nil
        shouldShakeDisplay = true
        
        // Reset shake trigger after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.shouldShakeDisplay = false
        }
    }
    
    // MARK: - Memory Handling
    
    private func handleMemory(_ action: String) {
        switch action {
        case "MC":
            memoryValue = 0.0
            hasMemory = false
        case "MR":
            if hasMemory {
                expression += MathEvaluator.formatResult(memoryValue)
                displayResult = expression
            }
        case "M+":
            if let val = try? evaluator.evaluate(expression: expression) {
                memoryValue += val
                hasMemory = true
            }
        case "M-":
            if let val = try? evaluator.evaluate(expression: expression) {
                memoryValue -= val
                hasMemory = true
            }
        default:
            break
        }
    }
    
    public func insertFromHistory(_ item: HistoryItem) {
        expression = item.result
        displayResult = item.result
        hasError = false
        updateLivePreview()
    }
}
