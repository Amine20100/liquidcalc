//
//  AdvancedVisionFrameworkTests.swift
//  LiquidCalcTests
//
//  Created for LiquidCalc iOS 18+.
//  Unit Test Suite for Advanced Vision Frameworks:
//  VisionKit, Vision (Rectangles, Contours, Tracking), CoreImage Enhancement,
//  AVFoundation Camera Controls, and Multimodal AI Orchestrator
//

import XCTest
import CoreGraphics

#if canImport(LiquidCalc)
@testable import LiquidCalc
#elseif canImport(LiquidCalcCore)
@testable import LiquidCalcCore
#endif

final class AdvancedVisionFrameworkTests: XCTestCase {
    
    // MARK: - 1. CoreImage Enhancement & Geometry Tests
    
    func testQuadrilateralCornersInitialization() {
        let tl = CGPoint(x: 0.1, y: 0.1)
        let tr = CGPoint(x: 0.9, y: 0.12)
        let br = CGPoint(x: 0.88, y: 0.85)
        let bl = CGPoint(x: 0.08, y: 0.82)
        
        let quad = QuadrilateralCorners(topLeft: tl, topRight: tr, bottomRight: br, bottomLeft: bl)
        XCTAssertEqual(quad.topLeft, tl)
        XCTAssertEqual(quad.topRight, tr)
        XCTAssertEqual(quad.bottomRight, br)
        XCTAssertEqual(quad.bottomLeft, bl)
    }
    
    func testImageEnhancementOptionsDefaults() {
        let options = ImageEnhancementOptions()
        XCTAssertTrue(options.shouldDenoise)
        XCTAssertTrue(options.shouldAdjustExposure)
        XCTAssertTrue(options.shouldSharpen)
        XCTAssertFalse(options.shouldBinarize)
        XCTAssertEqual(options.contrast, 1.35, accuracy: 0.001)
        XCTAssertNil(options.targetDeskew)
    }
    
    func testImageEnhancerSingleton() {
        let enhancer = VisionImageEnhancer.shared
        XCTAssertNotNil(enhancer)
    }
    
    // MARK: - 2. Vision Framework Contour & Object Tracking Tests
    
    func testContourAnalysisResultLogic() {
        let handwritten = ContourAnalysisResult(
            contourCount: 8,
            topLevelContourCount: 3,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 50),
            complexityIndex: 18.0,
            isLikelyHandwritten: true
        )
        XCTAssertTrue(handwritten.isLikelyHandwritten)
        XCTAssertEqual(handwritten.contourCount, 8)
        XCTAssertEqual(handwritten.complexityIndex, 18.0)
        
        let printed = ContourAnalysisResult(
            contourCount: 2,
            topLevelContourCount: 1,
            boundingBox: CGRect(x: 0, y: 0, width: 50, height: 20),
            complexityIndex: 5.0,
            isLikelyHandwritten: false
        )
        XCTAssertFalse(printed.isLikelyHandwritten)
    }
    
    func testVisionObjectTrackerState() {
        let tracker = VisionObjectTracker()
        let initialBox = CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.2)
        tracker.startTracking(boundingBox: initialBox)
        tracker.reset()
        // Tracker resets cleanly without throwing
        XCTAssertNotNil(tracker)
    }
    
    // MARK: - 3. VisionKit Bridge Capability Query
    
    func testVisionKitBridgeCapabilities() {
        let bridge = VisionKitBridge.shared
        let caps = bridge.queryCapabilities()
        // In unit test environment, capabilities return valid boolean values without crashing
        XCTAssertNotNil(caps.isDataScannerSupported)
        XCTAssertNotNil(caps.isDataScannerAvailable)
        XCTAssertNotNil(caps.isImageAnalysisSupported)
    }
    
    // MARK: - 4. AVFoundation Camera Controls & Coordinate Translation
    
    func testCameraCaptureServiceZoomClamping() {
        let camera = CameraCaptureService()
        XCTAssertEqual(camera.currentZoomFactor, 1.0)
        
        // Clamp to max
        camera.setZoomFactor(20.0)
        XCTAssertLessThanOrEqual(camera.currentZoomFactor, camera.maxZoomFactor)
        
        // Clamp to min
        camera.setZoomFactor(0.2)
        XCTAssertGreaterThanOrEqual(camera.currentZoomFactor, camera.minZoomFactor)
    }
    
    func testCameraCaptureServiceFocusPointInView() {
        let camera = CameraCaptureService()
        let viewBounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        let tapPoint = CGPoint(x: 200, y: 300)
        
        camera.focusAtPointInView(tapPoint, viewBounds: viewBounds)
        XCTAssertEqual(camera.lastFocusTapLocation, tapPoint)
    }
    
    func testCameraExposureLockToggle() {
        let camera = CameraCaptureService()
        XCTAssertFalse(camera.isExposureLocked)
        
        camera.setExposureLocked(true)
        XCTAssertTrue(camera.isExposureLocked)
        
        camera.setExposureLocked(false)
        XCTAssertFalse(camera.isExposureLocked)
    }
    
    // MARK: - 5. Multimodal AI & On-Device Equation Solver
    
    func testOrchestratorStandardArithmetic() {
        let orchestrator = VisionMultimodalOrchestrator.shared
        let solution = orchestrator.solveOnDevice(expression: "15 * 4 + 10")
        XCTAssertEqual(solution.result, "70")
        XCTAssertEqual(solution.source, .onDeviceEngine)
        XCTAssertFalse(solution.steps.isEmpty)
    }
    
    func testOrchestratorLinearEquationSolving() {
        let orchestrator = VisionMultimodalOrchestrator.shared
        let solution = orchestrator.solveOnDevice(expression: "2x + 6 = 16")
        XCTAssertTrue(solution.result.contains("5"), "2x + 6 = 16 should solve to x = 5. Result: \(solution.result)")
        XCTAssertFalse(solution.steps.isEmpty)
    }
    
    func testOrchestratorQuadraticEquationSolving() {
        let orchestrator = VisionMultimodalOrchestrator.shared
        let solution = orchestrator.solveOnDevice(expression: "x^2 - 5x + 6 = 0")
        XCTAssertTrue(solution.result.contains("2") && solution.result.contains("3"), "x^2 - 5x + 6 = 0 roots are 2 and 3. Result: \(solution.result)")
        XCTAssertNotNil(solution.explanation)
    }
    
    func testOrchestratorReceiptBreakdownCalculation() {
        let orchestrator = VisionMultimodalOrchestrator.shared
        let obs = [
            ScannedTextObservation(rawText: "Burger $12.00", sanitizedExpression: "Burger 12.00", boundingBox: .zero, confidence: 0.98),
            ScannedTextObservation(rawText: "Fries $4.00", sanitizedExpression: "Fries 4.00", boundingBox: .zero, confidence: 0.98),
            ScannedTextObservation(rawText: "Soda $3.00", sanitizedExpression: "Soda 3.00", boundingBox: .zero, confidence: 0.98),
            ScannedTextObservation(rawText: "Tax $1.50", sanitizedExpression: "Tax 1.50", boundingBox: .zero, confidence: 0.95),
            ScannedTextObservation(rawText: "Total $20.50", sanitizedExpression: "Total 20.50", boundingBox: .zero, confidence: 0.99)
        ]
        
        let breakdown = orchestrator.processReceiptOnDevice(observations: obs, tipPercent: 20.0, splitCount: 2)
        XCTAssertEqual(breakdown.currency, .usd)
        XCTAssertEqual(breakdown.items.count, 3)
        XCTAssertEqual(breakdown.subtotal, 19.0, accuracy: 0.01)
        XCTAssertEqual(breakdown.tax, 1.50, accuracy: 0.01)
        XCTAssertEqual(breakdown.tip, 19.0 * 0.20, accuracy: 0.01) // $3.80
        let expectedTotal = 19.0 + 1.50 + 3.80 // $24.30
        XCTAssertEqual(breakdown.total, expectedTotal, accuracy: 0.01)
        XCTAssertEqual(breakdown.splitPerPerson, expectedTotal / 2.0, accuracy: 0.01)
    }
    
    // MARK: - 6. Calculus & Advanced Equation Solving Tests
    
    func testOrchestratorCalculusDerivative() {
        let orchestrator = VisionMultimodalOrchestrator.shared
        let solution = orchestrator.solveOnDevice(expression: "d/dx(x^2) at x=3")
        XCTAssertTrue(solution.result.contains("6"), "d/dx(x^2) at x=3 should be 6. Result: \(solution.result)")
        XCTAssertFalse(solution.steps.isEmpty)
        XCTAssertEqual(solution.source, .onDeviceEngine)
    }
    
    func testOrchestratorCalculusIntegral() {
        let orchestrator = VisionMultimodalOrchestrator.shared
        let solution = orchestrator.solveOnDevice(expression: "int(0, 1, x^2)")
        let val = Double(solution.result) ?? 0.0
        XCTAssertEqual(val, 1.0 / 3.0, accuracy: 0.02)
        XCTAssertFalse(solution.steps.isEmpty)
    }
    
    func testOrchestratorQuadraticWithMissingTerms() {
        let orchestrator = VisionMultimodalOrchestrator.shared
        let solution = orchestrator.solveOnDevice(expression: "x^2 - 4 = 0")
        XCTAssertTrue(solution.result.contains("2") && solution.result.contains("-2"), "x^2 - 4 = 0 roots are 2 and -2. Result: \(solution.result)")
    }
    
    func testVisionObjectTrackerStateLifecycle() {
        let tracker = VisionObjectTracker()
        XCTAssertFalse(tracker.isTracking)
        XCTAssertNil(tracker.currentBoundingBox)
        
        let initialBox = CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.3)
        tracker.startTracking(boundingBox: initialBox)
        XCTAssertTrue(tracker.isTracking)
        XCTAssertEqual(tracker.currentBoundingBox, initialBox)
        
        tracker.reset()
        XCTAssertFalse(tracker.isTracking)
        XCTAssertNil(tracker.currentBoundingBox)
    }
    
    func testCoreImagePerspectiveVectorsPreserveLowerLeftOrigin() {
        let enhancer = VisionImageEnhancer.shared
        let quad = QuadrilateralCorners(
            topLeft: CGPoint(x: 0.1, y: 0.9),
            topRight: CGPoint(x: 0.9, y: 0.9),
            bottomRight: CGPoint(x: 0.85, y: 0.1),
            bottomLeft: CGPoint(x: 0.15, y: 0.1)
        )
        let size = CGSize(width: 1000, height: 2000)
        let vectors = enhancer.coreImageVectors(for: quad, imageSize: size)
        
        // Top-left in lower-left coordinate origin has high Y (near height)
        XCTAssertEqual(vectors.topLeft.x, 100.0, accuracy: 0.01)
        XCTAssertEqual(vectors.topLeft.y, 1800.0, accuracy: 0.01)
        
        // Bottom-left in lower-left coordinate origin has low Y (near 0)
        XCTAssertEqual(vectors.bottomLeft.x, 150.0, accuracy: 0.01)
        XCTAssertEqual(vectors.bottomLeft.y, 200.0, accuracy: 0.01)
    }
}
