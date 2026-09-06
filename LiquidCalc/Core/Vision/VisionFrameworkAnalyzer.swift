//
//  VisionFrameworkAnalyzer.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Advanced Vision Framework Suite: Real-Time Rectangles, Contour Tracing, & Object Tracking
//

import Foundation
import CoreGraphics

#if canImport(Vision)
import Vision
#endif

#if canImport(CoreImage)
import CoreImage
#endif

#if canImport(UIKit)
import UIKit
#endif

/// Result of a contour analysis for handwritten math equations.
public struct ContourAnalysisResult: Equatable, Sendable {
    public let contourCount: Int
    public let topLevelContourCount: Int
    public let boundingBox: CGRect
    public let complexityIndex: Double
    public let isLikelyHandwritten: Bool
    
    public init(
        contourCount: Int,
        topLevelContourCount: Int,
        boundingBox: CGRect,
        complexityIndex: Double,
        isLikelyHandwritten: Bool
    ) {
        self.contourCount = contourCount
        self.topLevelContourCount = topLevelContourCount
        self.boundingBox = boundingBox
        self.complexityIndex = complexityIndex
        self.isLikelyHandwritten = isLikelyHandwritten
    }
}

/// Persistent object tracker across camera video frames using VNSequenceRequestHandler & VNTrackObjectRequest.
public final class VisionObjectTracker: @unchecked Sendable {
    #if canImport(Vision)
    private let sequenceHandler = VNSequenceRequestHandler()
    private var lastObservation: VNDetectedObjectObservation?
    #endif
    
    public init() {}
    
    /// Initializes tracking on a newly detected bounding box in normalized coordinates.
    public func startTracking(boundingBox: CGRect) {
        #if canImport(Vision)
        self.lastObservation = VNDetectedObjectObservation(boundingBox: boundingBox)
        #endif
    }
    
    public var isTracking: Bool {
        #if canImport(Vision)
        return lastObservation != nil
        #else
        return false
        #endif
    }
    
    public var currentBoundingBox: CGRect? {
        #if canImport(Vision)
        return lastObservation?.boundingBox
        #else
        return nil
        #endif
    }
    
    /// Resets the tracker.
    public func reset() {
        #if canImport(Vision)
        self.lastObservation = nil
        #endif
    }
    
    #if canImport(Vision)
    /// Tracks the target object in the next video frame.
    public func trackNextFrame(pixelBuffer: CVPixelBuffer) -> CGRect? {
        guard let last = lastObservation else { return nil }
        
        let request = VNTrackObjectRequest(detectedObjectObservation: last)
        request.trackingLevel = .accurate
        
        do {
            try sequenceHandler.perform([request], on: pixelBuffer)
            if let results = request.results as? [VNDetectedObjectObservation], let newObs = results.first {
                if newObs.confidence > 0.3 {
                    self.lastObservation = newObs
                    return newObs.boundingBox
                }
            }
        } catch {
            return nil
        }
        return nil
    }
    
    /// Tracks the target object in a CGImage frame.
    public func trackNextFrame(cgImage: CGImage) -> CGRect? {
        guard let last = lastObservation else { return nil }
        
        let request = VNTrackObjectRequest(detectedObjectObservation: last)
        request.trackingLevel = .accurate
        
        do {
            try sequenceHandler.perform([request], on: cgImage)
            if let results = request.results as? [VNDetectedObjectObservation], let newObs = results.first {
                if newObs.confidence > 0.3 {
                    self.lastObservation = newObs
                    return newObs.boundingBox
                }
            }
        } catch {
            return nil
        }
        return nil
    }
    #endif
}

/// Advanced Vision Framework analyzer orchestrating Rectangle Detection, Contour Tracing, and Deskewed OCR.
public final class VisionFrameworkAnalyzer: @unchecked Sendable {
    public static let shared = VisionFrameworkAnalyzer()
    
    private let enhancer = VisionImageEnhancer.shared
    private let scanner = VisionMathScanner()
    
    public init() {}
    
    // MARK: - 1. Real-Time Document / Receipt Rectangle Boundary Detection
    
    #if canImport(Vision)
    /// Detects quadrilateral document boundaries using VNDetectRectanglesRequest.
    public func detectDocumentRectangles(
        in cgImage: CGImage,
        minimumConfidence: Float = 0.55,
        completion: @escaping @Sendable (QuadrilateralCorners?) -> Void
    ) {
        let request = VNDetectRectanglesRequest { req, error in
            guard error == nil,
                  let observations = req.results as? [VNRectangleObservation],
                  let best = observations.first(where: { $0.confidence >= minimumConfidence }) ?? observations.first else {
                completion(nil)
                return
            }
            
            let corners = QuadrilateralCorners(
                topLeft: best.topLeft,
                topRight: best.topRight,
                bottomRight: best.bottomRight,
                bottomLeft: best.bottomLeft
            )
            completion(corners)
        }
        
        request.maximumObservations = 1
        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.15
        request.minimumConfidence = minimumConfidence
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(nil)
            }
        }
    }
    #endif
    
    // MARK: - 2. Handwritten Math Contour Tracing & Stroke Analysis
    
    #if canImport(Vision)
    /// Traces contours of handwritten math equations using VNDetectContoursRequest.
    public func detectEquationContours(
        in cgImage: CGImage,
        completion: @escaping @Sendable (ContourAnalysisResult?) -> Void
    ) {
        let request = VNDetectContoursRequest { req, error in
            guard error == nil,
                  let observations = req.results as? [VNContoursObservation],
                  let obs = observations.first else {
                completion(nil)
                return
            }
            
            let totalCount = obs.contourCount
            let topCount = obs.topLevelContourCount
            
            // Calculate complexity index: ratio of contours to normalized area
            let bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
            let complexity = Double(totalCount) * 1.5 + Double(topCount) * 2.0
            let isHandwritten = totalCount >= 4 && complexity >= 10.0
            
            let result = ContourAnalysisResult(
                contourCount: totalCount,
                topLevelContourCount: topCount,
                boundingBox: bounds,
                complexityIndex: complexity,
                isLikelyHandwritten: isHandwritten
            )
            completion(result)
        }
        
        request.contrastAdjustment = 1.6
        request.maximumImageDimension = 1024
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(nil)
            }
        }
    }
    #endif
    
    // MARK: - 3. End-to-End Perspective Deskewing & High-Accuracy OCR Pipeline
    
    #if canImport(Vision)
    /// Automatically detects document quad bounds, deskews perspective with CoreImage, and performs high-accuracy OCR.
    public func deskewAndScanDocument(
        cgImage: CGImage,
        autoEnhance: Bool = true,
        completion: @escaping @Sendable (Result<([ScannedTextObservation], QuadrilateralCorners?), Error>) -> Void
    ) {
        detectDocumentRectangles(in: cgImage) { [weak self] detectedQuad in
            guard let self = self else { return }
            
            var targetImage = cgImage
            
            #if canImport(CoreImage)
            if let quad = detectedQuad {
                var options = ImageEnhancementOptions()
                options.targetDeskew = quad
                options.shouldSharpen = autoEnhance
                options.shouldAdjustExposure = autoEnhance
                targetImage = self.enhancer.enhanceImage(cgImage, options: options)
            } else if autoEnhance {
                var options = ImageEnhancementOptions()
                options.shouldSharpen = true
                options.shouldAdjustExposure = true
                targetImage = self.enhancer.enhanceImage(cgImage, options: options)
            }
            #endif
            
            self.scanner.scanImage(targetImage) { scanResult in
                switch scanResult {
                case .success(let observations):
                    completion(.success((observations, detectedQuad)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    #endif
}
