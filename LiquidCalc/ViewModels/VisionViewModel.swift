//
//  VisionViewModel.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Resilient Smart Vision & Receipt Processing ViewModel
//

import SwiftUI
import PhotosUI
#if canImport(Vision)
import Vision
#endif

public enum VisionSubMode: String, CaseIterable, Identifiable {
    case equation = "Math Equation"
    case receipt = "Receipt & Split"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .equation: return "function"
        case .receipt: return "doc.text.magnifyingglass"
        }
    }
}

@Observable
public final class VisionViewModel {
    public let cameraService = CameraCaptureService()
    private let scanner = VisionMathScanner()
    private let evaluator = MathEvaluator(angleUnit: .degrees)
    private let historyManager = HistoryManager.shared
    
    public var selectedSubMode: VisionSubMode = .equation
    public var isScanning: Bool = false
    public var detectedExpression: String = ""
    public var solvedResult: String? = nil
    public var scannedObservations: [ScannedTextObservation] = []
    
    // Receipt Splitter State
    public var receiptItems: [ReceiptLineItem] = []
    public var detectedCurrency: SupportedCurrency = .usd
    public var tipPercentage: Double = 18.0
    public var splitCount: Int = 2
    public var taxRate: Double = 8.875
    
    public var hasDetectedTarget: Bool {
        if selectedSubMode == .equation {
            return !detectedExpression.isEmpty
        } else {
            return !receiptItems.isEmpty
        }
    }
    
    public var targetBoundingBox: CGRect? {
        scannedObservations.first?.boundingBox
    }
    
    public var selectedPhotoItem: PhotosPickerItem? = nil {
        didSet {
            loadSelectedPhoto()
        }
    }
    
    public init() {}
    
    public func startCamera() {
        cameraService.checkPermissions { [weak self] granted in
            if granted {
                self?.cameraService.startSession()
            }
        }
    }
    
    public func stopCamera() {
        SoundAndHapticManager.shared.stopContinuousScanningHum()
        cameraService.stopSession()
    }
    
    public func clearResults() {
        SoundAndHapticManager.shared.stopContinuousScanningHum()
        withAnimation(.easeInOut(duration: 0.2)) {
            detectedExpression = ""
            solvedResult = nil
            scannedObservations = []
            receiptItems = []
        }
    }
    
    public func scanCurrentFrame() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isScanning = true
        }
        SoundAndHapticManager.shared.startContinuousScanningHum()
        SoundAndHapticManager.shared.triggerHaptic(.medium)
        
        cameraService.capturePhoto { [weak self] cgImage in
            guard let self = self, let cgImage = cgImage else {
                DispatchQueue.main.async {
                    SoundAndHapticManager.shared.stopContinuousScanningHum()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self?.isScanning = false
                    }
                }
                return
            }
            
            #if canImport(Vision)
            self.scanner.scanImage(cgImage) { result in
                DispatchQueue.main.async {
                    SoundAndHapticManager.shared.stopContinuousScanningHum()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isScanning = false
                    }
                    switch result {
                    case .success(let observations):
                        self.scannedObservations = observations
                        self.processScannedResults(observations)
                    case .failure:
                        SoundAndHapticManager.shared.triggerHaptic(.error)
                    }
                }
            }
            #else
            DispatchQueue.main.async {
                SoundAndHapticManager.shared.stopContinuousScanningHum()
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.isScanning = false
                }
            }
            #endif
        }
    }
    
    public func processScannedResults(_ observations: [ScannedTextObservation]) {
        if selectedSubMode == .equation {
            // Find best evaluating mathematical candidate
            var bestExpression: String = ""
            var bestResult: String? = nil
            
            for obs in observations {
                let candidate = obs.sanitizedExpression
                if let solved = trySolveExpression(candidate) {
                    bestExpression = candidate
                    bestResult = solved
                    break
                }
            }
            
            // Fallback to first sanitized expression if solver didn't match
            if bestExpression.isEmpty, let first = observations.first {
                bestExpression = first.sanitizedExpression
                bestResult = trySolveExpression(bestExpression)
            }
            
            if !bestExpression.isEmpty {
                SoundAndHapticManager.shared.playDigitClick()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.70)) {
                    self.detectedExpression = bestExpression
                    self.solvedResult = bestResult
                }
                
                if let res = bestResult, res != "Error" {
                    historyManager.addItem(expression: bestExpression, result: res, mode: "Vision")
                    SoundAndHapticManager.shared.triggerHaptic(.success)
                    SoundAndHapticManager.shared.playSuccessSound()
                }
            }
        } else {
            // Parse receipt items
            let parseResult = scanner.parseReceipt(from: observations)
            self.detectedCurrency = parseResult.detectedCurrency
            
            if !parseResult.items.isEmpty {
                SoundAndHapticManager.shared.playDigitClick()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.70)) {
                    self.receiptItems = parseResult.items
                }
                SoundAndHapticManager.shared.triggerHaptic(.success)
            } else {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.70)) {
                    self.receiptItems = []
                }
                if !observations.isEmpty {
                    SoundAndHapticManager.shared.triggerHaptic(.error)
                }
            }
        }
    }
    
    public func solveDetectedExpression() {
        guard !detectedExpression.isEmpty else { return }
        if let res = trySolveExpression(detectedExpression) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.70)) {
                self.solvedResult = res
            }
            historyManager.addItem(expression: detectedExpression, result: res, mode: "Vision")
            SoundAndHapticManager.shared.triggerHaptic(.success)
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.70)) {
                self.solvedResult = "Error"
            }
            SoundAndHapticManager.shared.triggerHaptic(.error)
        }
    }
    
    // MARK: - Smart Multi-Strategy Math Solver
    
    private func trySolveExpression(_ expr: String) -> String? {
        let clean = expr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        
        // 1. Try standard evaluation
        if let val = try? evaluator.evaluate(expression: clean) {
            return MathEvaluator.formatResult(val)
        }
        
        // 2. Try solving as Linear Equation: "ax + b = c" or "2x + 5 = 15"
        if clean.contains("=") && (clean.contains("x") || clean.contains("X")) {
            if let linearRes = trySolveLinearEquation(clean) {
                return linearRes
            }
        }
        
        // 3. Try solving expression without trailing noise
        let cleanedMath = clean.replacingOccurrences(of: "=", with: "").trimmingCharacters(in: .whitespaces)
        if let val = try? evaluator.evaluate(expression: cleanedMath) {
            return MathEvaluator.formatResult(val)
        }
        
        return nil
    }
    
    private func trySolveLinearEquation(_ equation: String) -> String? {
        // Simple linear equation parsing e.g. "2*x + 4 = 10" or "2x + 4 = 10"
        let parts = equation.split(separator: "=")
        guard parts.count == 2 else { return nil }
        
        let left = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let right = String(parts[1]).trimmingCharacters(in: .whitespaces)
        
        guard let rightVal = try? evaluator.evaluate(expression: right) else { return nil }
        
        // Evaluate at x = 0 and x = 1 to find slope and intercept: f(x) = ax + b
        let evalAt0 = left.replacingOccurrences(of: "x", with: "(0)").replacingOccurrences(of: "X", with: "(0)")
        let evalAt1 = left.replacingOccurrences(of: "x", with: "(1)").replacingOccurrences(of: "X", with: "(1)")
        
        guard let b = try? evaluator.evaluate(expression: evalAt0),
              let f1 = try? evaluator.evaluate(expression: evalAt1) else {
            return nil
        }
        
        let a = f1 - b
        guard abs(a) > 1e-12 else { return nil }
        
        let x = (rightVal - b) / a
        return "x = " + MathEvaluator.formatResult(x)
    }
    
    // MARK: - Receipt Calculations
    
    public var receiptSubtotal: Double {
        receiptItems.filter { $0.isSelected }.reduce(0.0) { $0 + $1.amount }
    }
    
    public var receiptTipAmount: Double {
        receiptSubtotal * (tipPercentage / 100.0)
    }
    
    public var receiptTaxAmount: Double {
        receiptSubtotal * (taxRate / 100.0)
    }
    
    public var receiptTotal: Double {
        receiptSubtotal + receiptTipAmount + receiptTaxAmount
    }
    
    public var receiptPerPerson: Double {
        guard splitCount > 0 else { return receiptTotal }
        return receiptTotal / Double(splitCount)
    }
    
    // MARK: - Photo Library Loader
    
    private func loadSelectedPhoto() {
        guard let item = selectedPhotoItem else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            isScanning = true
        }
        SoundAndHapticManager.shared.startContinuousScanningHum()
        
        item.loadTransferable(type: Data.self) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                SoundAndHapticManager.shared.stopContinuousScanningHum()
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.isScanning = false
                }
                switch result {
                case .success(let data):
                    #if canImport(UIKit)
                    if let data = data, let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage {
                        #if canImport(Vision)
                        self.scanner.scanImage(cgImage) { scanRes in
                            DispatchQueue.main.async {
                                if case .success(let obs) = scanRes {
                                    self.scannedObservations = obs
                                    self.processScannedResults(obs)
                                }
                            }
                        }
                        #endif
                    }
                    #endif
                case .failure:
                    SoundAndHapticManager.shared.triggerHaptic(.error)
                }
            }
        }
    }
}
