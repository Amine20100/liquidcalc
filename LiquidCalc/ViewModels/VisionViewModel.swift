//
//  VisionViewModel.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Advanced Smart Vision & Receipt Processing ViewModel with CoreImage, VisionKit & Multimodal AI
//

import SwiftUI
import PhotosUI

#if canImport(Vision)
import Vision
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(CoreMedia)
import CoreMedia
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

public enum VisionScanMode: String, CaseIterable, Identifiable {
    case guided = "Guided"
    case live = "Live"
    case visionKit = "VisionKit"
    
    public var id: String { rawValue }
}

@Observable
public final class VisionViewModel {
    public let cameraService = CameraCaptureService()
    private let scanner = VisionMathScanner()
    private let analyzer = VisionFrameworkAnalyzer.shared
    private let orchestrator = VisionMultimodalOrchestrator.shared
    private let historyManager = HistoryManager.shared
    
    public var selectedSubMode: VisionSubMode = .equation
    public var scanMode: VisionScanMode = .guided
    public var isScanning: Bool = false
    public var recognitionConfidence: Double = 0
    public var lastScanSource: String = "Camera"
    public var detectedExpression: String = ""
    public var solvedResult: String? = nil
    public var detectedSteps: [String] = []
    public var detectedExplanation: String? = nil
    public var scannedObservations: [ScannedTextObservation] = []
    
    // Advanced Framework State
    public let tracker = VisionObjectTracker()
    public var trackedBoundingBox: CGRect? = nil
    public var detectedQuad: QuadrilateralCorners? = nil
    public var contourResult: ContourAnalysisResult? = nil
    public var isDeskewEnabled: Bool = true
    public var isEnhanceEnabled: Bool = true
    public var zoomFactor: CGFloat = 1.0
    public var tapFocusLocation: CGPoint? = nil
    public var showTapFocusReticle: Bool = false
    public var isExposureLocked: Bool = false
    public var loadedPhotoForAnalysis: UIImage? = nil
    public var showLiveTextAnalysisSheet: Bool = false
    
    // Receipt Splitter State
    public var receiptItems: [ReceiptLineItem] = []
    public var detectedCurrency: SupportedCurrency = .usd
    public var tipPercentage: Double = 18.0
    public var splitCount: Int = 2
    public var taxRate: Double = 8.875
    
    public var isVisionKitSupported: Bool {
        VisionKitBridge.shared.queryCapabilities().isFullyOperational
    }
    
    public var hasDetectedTarget: Bool {
        if selectedSubMode == .equation {
            return !detectedExpression.isEmpty
        } else {
            return !receiptItems.isEmpty
        }
    }
    
    public var targetBoundingBox: CGRect? {
        trackedBoundingBox ?? scannedObservations.first?.boundingBox
    }
    
    public var selectedPhotoItem: PhotosPickerItem? = nil {
        didSet {
            loadSelectedPhoto()
        }
    }
    
    public init() {}
    
    public func startCamera() {
        cameraService.delegate = self
        cameraService.checkPermissions { [weak self] granted in
            if granted {
                self?.cameraService.startSession()
            }
        }
    }
    
    public func stopCamera() {
        SoundAndHapticManager.shared.stopContinuousScanningHum()
        cameraService.stopSession()
        cameraService.delegate = nil
        tracker.reset()
        trackedBoundingBox = nil
    }
    
    public func clearResults() {
        SoundAndHapticManager.shared.stopContinuousScanningHum()
        tracker.reset()
        withAnimation(.easeInOut(duration: 0.2)) {
            detectedExpression = ""
            solvedResult = nil
            detectedSteps = []
            detectedExplanation = nil
            scannedObservations = []
            receiptItems = []
            detectedQuad = nil
            contourResult = nil
            loadedPhotoForAnalysis = nil
            trackedBoundingBox = nil
        }
    }
    
    // MARK: - Advanced Camera Controls: Tap-to-Focus & Pinch-to-Zoom
    
    public func handleTapToFocus(pointInView: CGPoint, viewBounds: CGRect) {
        tapFocusLocation = pointInView
        showTapFocusReticle = true
        cameraService.focusAtPointInView(pointInView, viewBounds: viewBounds)
        SoundAndHapticManager.shared.triggerHaptic(.light)
        
        // Reticle fades after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) {
                self?.showTapFocusReticle = false
            }
        }
    }
    
    public func handleZoomChange(_ factor: CGFloat) {
        self.zoomFactor = factor
        cameraService.setZoomFactor(factor)
    }
    
    public func toggleExposureLock() {
        isExposureLocked.toggle()
        cameraService.setExposureLocked(isExposureLocked)
        SoundAndHapticManager.shared.triggerHaptic(.selection)
    }
    
    // MARK: - Scanning Pipeline with CoreImage Preprocessing & Deskewing
    
    public func scanCurrentFrame() {
        guard !isScanning else { return }
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
            // Optional Contour Analysis for Equation Mode
            if self.selectedSubMode == .equation {
                self.analyzer.detectEquationContours(in: cgImage) { [weak self] contourRes in
                    DispatchQueue.main.async {
                        self?.contourResult = contourRes
                    }
                }
            }
            
            // Perspective Deskewing and Pre-OCR Enhancement
            if self.isDeskewEnabled {
                self.analyzer.deskewAndScanDocument(cgImage: cgImage, autoEnhance: self.isEnhanceEnabled) { [weak self] result in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        SoundAndHapticManager.shared.stopContinuousScanningHum()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.isScanning = false
                        }
                        
                        switch result {
                        case .success(let (observations, quad)):
                            self.detectedQuad = quad
                            self.scannedObservations = observations
                            self.processScannedResults(observations)
                        case .failure:
                            SoundAndHapticManager.shared.triggerHaptic(.error)
                        }
                    }
                }
            } else {
                self.scanner.scanImage(cgImage) { [weak self] result in
                    guard let self = self else { return }
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
            }
            #else
            DispatchQueue.main.async {
                SoundAndHapticManager.shared.stopContinuousScanningHum()
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.isScanning = false
                }
            }
            #endif
            
            #if canImport(UIKit)
            let uiImage = UIImage(cgImage: cgImage)
            Task {
                await self.analyzeCurrentPhotoWithGemini(uiImage: uiImage)
            }
            #endif
        }
    }
    
    // MARK: - VisionKit Bridge Callbacks
    
    public func handleVisionKitRecognized(texts: [String]) {
        guard !texts.isEmpty else { return }
        let joined = texts.joined(separator: " ")
        if selectedSubMode == .equation {
            let sanitized = scanner.sanitizeMathString(joined)
            if !sanitized.isEmpty && sanitized != detectedExpression {
                self.detectedExpression = sanitized
                let solution = orchestrator.solveOnDevice(expression: sanitized)
                self.solvedResult = solution.result
                self.detectedSteps = solution.steps
                self.detectedExplanation = solution.explanation
            }
        }
    }
    
    public func handleVisionKitItemTapped(text: String) {
        SoundAndHapticManager.shared.triggerHaptic(.selection)
        let sanitized = scanner.sanitizeMathString(text)
        self.detectedExpression = sanitized
        let solution = orchestrator.solveOnDevice(expression: sanitized)
        self.solvedResult = solution.result
        self.detectedSteps = solution.steps
        self.detectedExplanation = solution.explanation
    }
    
    // MARK: - Process Scanned Results
    
    public func processScannedResults(_ observations: [ScannedTextObservation]) {
        recognitionConfidence = observations.isEmpty ? 0 : min(0.98, 0.45 + Double(observations.count) * 0.12)
        if selectedSubMode == .equation {
            var bestExpression: String = ""
            var bestResult: String? = nil
            
            for obs in observations {
                let candidate = obs.sanitizedExpression
                let sol = orchestrator.solveOnDevice(expression: candidate)
                if sol.result != "Unresolved" && sol.result != "Empty Expression" {
                    bestExpression = candidate
                    bestResult = sol.result
                    self.detectedSteps = sol.steps
                    self.detectedExplanation = sol.explanation
                    break
                }
            }
            
            if bestExpression.isEmpty, let first = observations.first {
                bestExpression = first.sanitizedExpression
                let sol = orchestrator.solveOnDevice(expression: bestExpression)
                bestResult = sol.result
                self.detectedSteps = sol.steps
                self.detectedExplanation = sol.explanation
            }
            
            if !bestExpression.isEmpty {
                if let firstBox = observations.first?.boundingBox {
                    tracker.startTracking(boundingBox: firstBox)
                    self.trackedBoundingBox = firstBox
                }
                SoundAndHapticManager.shared.playDigitClick()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.70)) {
                    self.detectedExpression = bestExpression
                    self.solvedResult = bestResult
                }
                
                if let res = bestResult, res != "Unresolved" && res != "Error" {
                    historyManager.addItem(expression: bestExpression, result: res, mode: "Vision")
                    SoundAndHapticManager.shared.triggerHaptic(.success)
                    SoundAndHapticManager.shared.playSuccessSound()
                }
            }
        } else {
            let breakdown = orchestrator.processReceiptOnDevice(
                observations: observations,
                tipPercent: tipPercentage,
                splitCount: splitCount
            )
            self.detectedCurrency = breakdown.currency
            
            if !breakdown.items.isEmpty {
                SoundAndHapticManager.shared.playDigitClick()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.70)) {
                    self.receiptItems = breakdown.items
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
        let sol = orchestrator.solveOnDevice(expression: detectedExpression)
        if sol.result != "Unresolved" {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.70)) {
                self.solvedResult = sol.result
                self.detectedSteps = sol.steps
                self.detectedExplanation = sol.explanation
            }
            historyManager.addItem(expression: detectedExpression, result: sol.result, mode: "Vision")
            SoundAndHapticManager.shared.triggerHaptic(.success)
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.70)) {
                self.solvedResult = "Error"
            }
            SoundAndHapticManager.shared.triggerHaptic(.error)
        }
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
            switch result {
            case .success(let data):
                #if canImport(UIKit)
                if let data = data, let uiImage = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.loadedPhotoForAnalysis = uiImage
                    }
                    
                    Task {
                        await self.analyzeCurrentPhotoWithGemini(uiImage: uiImage)
                        
                        if let cgImage = uiImage.cgImage {
                            #if canImport(Vision)
                            self.analyzer.deskewAndScanDocument(cgImage: cgImage, autoEnhance: self.isEnhanceEnabled) { scanRes in
                                DispatchQueue.main.async {
                                    SoundAndHapticManager.shared.stopContinuousScanningHum()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        self.isScanning = false
                                    }
                                    if case .success(let (obs, quad)) = scanRes {
                                        self.scannedObservations = obs
                                        self.detectedQuad = quad
                                        if self.detectedExpression.isEmpty && self.receiptItems.isEmpty {
                                            self.processScannedResults(obs)
                                        }
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
                } else {
                    DispatchQueue.main.async {
                        SoundAndHapticManager.shared.stopContinuousScanningHum()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.isScanning = false
                        }
                    }
                }
                #endif
            case .failure:
                DispatchQueue.main.async {
                    SoundAndHapticManager.shared.stopContinuousScanningHum()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isScanning = false
                    }
                    SoundAndHapticManager.shared.triggerHaptic(.error)
                }
            }
        }
    }
    
    // MARK: - Gemini 2.5 Flash Multimodal AI Solver & Receipt Engine
    
    #if canImport(UIKit)
    public func analyzeCurrentPhotoWithGemini(uiImage: UIImage) async {
        SoundAndHapticManager.shared.triggerHaptic(.medium)
        if selectedSubMode == .receipt {
            let breakdown = await orchestrator.processReceipt(
                observations: scannedObservations,
                image: uiImage,
                preferAI: true,
                tipPercent: tipPercentage,
                splitCount: splitCount
            )
            await MainActor.run {
                if !breakdown.items.isEmpty {
                    self.receiptItems = breakdown.items
                }
                self.detectedCurrency = breakdown.currency
                SoundAndHapticManager.shared.triggerHaptic(.success)
                SoundAndHapticManager.shared.playSuccessSound()
            }
        } else {
            let solution = await orchestrator.solveMathProblem(
                expression: detectedExpression,
                image: uiImage,
                preferAI: true
            )
            await MainActor.run {
                self.detectedExpression = solution.expression
                self.solvedResult = solution.result
                self.detectedSteps = solution.steps
                self.detectedExplanation = solution.explanation
                if solution.result != "Unresolved" {
                    self.historyManager.addItem(expression: solution.expression, result: solution.result, mode: "Vision AI")
                    SoundAndHapticManager.shared.triggerHaptic(.success)
                    SoundAndHapticManager.shared.playSuccessSound()
                }
            }
        }
    }
    #endif
}

// MARK: - Real-Time 60fps Camera Frame Delegate & Object Tracking

#if canImport(AVFoundation) && canImport(CoreMedia)
extension VisionViewModel: CameraCaptureDelegate {
    public func cameraDidCaptureFrame(_ sampleBuffer: CMSampleBuffer) {
        #if canImport(Vision)
        guard tracker.isTracking else { return }
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            if let newBox = tracker.trackNextFrame(pixelBuffer: pixelBuffer) {
                DispatchQueue.main.async { [weak self] in
                    self?.trackedBoundingBox = newBox
                }
            }
        }
        #endif
    }
}
#else
extension VisionViewModel: CameraCaptureDelegate {}
#endif

