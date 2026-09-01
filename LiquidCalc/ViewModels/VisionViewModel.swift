//
//  VisionViewModel.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Milestone M2 & M3: Synchronized Vision Scanner Motion FX & Haptics
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
    public var tipPercentage: Double = 18.0
    public var splitCount: Int = 2
    public var taxRate: Double = 8.875
    
    // Target Lock Detection
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
    
    // Photo Picker
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
        // Start continuous scanning hum and initial shutter feedback
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
            // Find observation that best resembles a mathematical expression
            let mathCandidates = observations.filter { obs in
                let s = obs.sanitizedExpression
                return s.contains("+") || s.contains("-") || s.contains("*") || s.contains("/") ||
                       s.contains("^") || s.contains("sqrt") || s.contains("sin") || s.contains("cos")
            }
            
            let target = mathCandidates.first ?? observations.first
            if let best = target {
                // Lock-on tick when math target is identified
                SoundAndHapticManager.shared.playDigitClick()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.70)) {
                    self.detectedExpression = best.sanitizedExpression
                }
                self.solveDetectedExpression()
            }
        } else {
            // Parse receipt items
            let items = scanner.parseReceiptItems(from: observations)
            if !items.isEmpty {
                // Lock-on tick when receipt items are identified
                SoundAndHapticManager.shared.playDigitClick()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.70)) {
                    self.receiptItems = items
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
        do {
            let result = try evaluator.evaluate(expression: detectedExpression)
            let formatted = MathEvaluator.formatResult(result)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.70)) {
                self.solvedResult = formatted
            }
            
            // Save to history tape
            historyManager.addItem(expression: detectedExpression, result: formatted, mode: "Vision")
            SoundAndHapticManager.shared.triggerHaptic(.success)
            SoundAndHapticManager.shared.playSuccessSound()
        } catch {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.70)) {
                self.solvedResult = "Error"
            }
            SoundAndHapticManager.shared.triggerHaptic(.error)
        }
    }
    
    // MARK: - Receipt Calculations
    
    public var receiptSubtotal: Double {
        receiptItems.reduce(0.0) { $0 + $1.amount }
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
