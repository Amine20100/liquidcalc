//
//  VisionImageEnhancer.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Advanced CoreImage Computer Vision Preprocessing & Enhancement Pipeline
//

import Foundation
import CoreGraphics

#if canImport(CoreImage)
import CoreImage
#if canImport(CoreImage.CIFilterBuiltins)
import CoreImage.CIFilterBuiltins
#endif
#endif

#if canImport(UIKit)
import UIKit
#endif

/// Quadrilateral corner coordinates for perspective correction and document deskewing.
public struct QuadrilateralCorners: Equatable, Sendable {
    public let topLeft: CGPoint
    public let topRight: CGPoint
    public let bottomRight: CGPoint
    public let bottomLeft: CGPoint
    
    public init(topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }
}

/// Configuration options for the pre-OCR enhancement pipeline.
public struct ImageEnhancementOptions: Sendable {
    public var shouldDenoise: Bool
    public var shouldAdjustExposure: Bool
    public var exposureEV: Float
    public var shouldSharpen: Bool
    public var sharpenIntensity: Float
    public var shouldBinarize: Bool
    public var contrast: Float
    public var targetDeskew: QuadrilateralCorners?
    
    public init(
        shouldDenoise: Bool = true,
        shouldAdjustExposure: Bool = true,
        exposureEV: Float = 0.35,
        shouldSharpen: Bool = true,
        sharpenIntensity: Float = 0.65,
        shouldBinarize: Bool = false,
        contrast: Float = 1.35,
        targetDeskew: QuadrilateralCorners? = nil
    ) {
        self.shouldDenoise = shouldDenoise
        self.shouldAdjustExposure = shouldAdjustExposure
        self.exposureEV = exposureEV
        self.shouldSharpen = shouldSharpen
        self.sharpenIntensity = sharpenIntensity
        self.shouldBinarize = shouldBinarize
        self.contrast = contrast
        self.targetDeskew = targetDeskew
    }
}

/// Hardware-accelerated CoreImage preprocessing pipeline for mathematical OCR and document deskewing.
public final class VisionImageEnhancer: @unchecked Sendable {
    public static let shared = VisionImageEnhancer()
    
    #if canImport(CoreImage)
    private let ciContext: CIContext
    
    public init() {
        // Initialize high-performance CIContext with GPU acceleration
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .priorityRequestLow: false
        ]
        self.ciContext = CIContext(options: options)
    }
    #else
    public init() {}
    #endif
    
    #if canImport(CoreImage)
    /// Enhances a CGImage with CoreImage filters to optimize readability for Vision OCR and Gemini AI.
    public func enhanceImage(_ cgImage: CGImage, options: ImageEnhancementOptions = ImageEnhancementOptions()) -> CGImage {
        var currentImage = CIImage(cgImage: cgImage)
        let extent = currentImage.extent
        
        // 1. Perspective Deskewing (if corners are provided)
        if let quad = options.targetDeskew {
            currentImage = applyPerspectiveCorrection(to: currentImage, corners: quad, imageSize: extent.size)
        }
        
        // 2. Exposure & Shadow Adjustment
        if options.shouldAdjustExposure {
            if let exposureFilter = CIFilter(name: "CIExposureAdjust") {
                exposureFilter.setValue(currentImage, forKey: kCIInputImageKey)
                exposureFilter.setValue(options.exposureEV, forKey: kCIInputEVKey)
                if let output = exposureFilter.outputImage {
                    currentImage = output
                }
            }
            
            if let shadowFilter = CIFilter(name: "CIHighlightShadowAdjust") {
                shadowFilter.setValue(currentImage, forKey: kCIInputImageKey)
                shadowFilter.setValue(1.15, forKey: "inputShadowAmount")
                shadowFilter.setValue(0.85, forKey: "inputHighlightAmount")
                if let output = shadowFilter.outputImage {
                    currentImage = output
                }
            }
        }
        
        // 3. Noise Reduction (smoothes camera sensor noise and paper grain)
        if options.shouldDenoise {
            if let noiseFilter = CIFilter(name: "CINoiseReduction") {
                noiseFilter.setValue(currentImage, forKey: kCIInputImageKey)
                noiseFilter.setValue(0.02, forKey: "inputNoiseLevel")
                noiseFilter.setValue(0.40, forKey: "inputSharpness")
                if let output = noiseFilter.outputImage {
                    currentImage = output
                }
            }
        }
        
        // 4. Contrast & Grayscale / Adaptive Thresholding
        if options.shouldBinarize {
            // Convert to grayscale with boosted contrast
            if let colorControls = CIFilter(name: "CIColorControls") {
                colorControls.setValue(currentImage, forKey: kCIInputImageKey)
                colorControls.setValue(0.0, forKey: kCIInputSaturationKey) // Grayscale
                colorControls.setValue(options.contrast, forKey: kCIInputContrastKey)
                colorControls.setValue(0.05, forKey: kCIInputBrightnessKey)
                if let output = colorControls.outputImage {
                    currentImage = output
                }
            }
        } else if options.contrast != 1.0 {
            if let colorControls = CIFilter(name: "CIColorControls") {
                colorControls.setValue(currentImage, forKey: kCIInputImageKey)
                colorControls.setValue(options.contrast, forKey: kCIInputContrastKey)
                if let output = colorControls.outputImage {
                    currentImage = output
                }
            }
        }
        
        // 5. Sharpening (enhances thin fractions, square root signs, exponents)
        if options.shouldSharpen {
            if let unsharpFilter = CIFilter(name: "CIUnsharpMask") {
                unsharpFilter.setValue(currentImage, forKey: kCIInputImageKey)
                unsharpFilter.setValue(2.5, forKey: kCIInputRadiusKey)
                unsharpFilter.setValue(options.sharpenIntensity, forKey: kCIInputIntensityKey)
                if let output = unsharpFilter.outputImage {
                    currentImage = output
                }
            }
        }
        
        // Render final CGImage within target bounds
        let renderBounds = currentImage.extent.isInfinite ? extent : currentImage.extent
        if let resultCGImage = ciContext.createCGImage(currentImage, from: renderBounds) {
            return resultCGImage
        }
        
        return cgImage
    }
    
    /// Converts QuadrilateralCorners (normalized or pixel) to CoreImage coordinate vectors.
    /// Note: Both Apple Vision and CoreImage use a lower-left coordinate origin.
    public func coreImageVectors(
        for corners: QuadrilateralCorners,
        imageSize: CGSize
    ) -> (topLeft: CIVector, topRight: CIVector, bottomRight: CIVector, bottomLeft: CIVector) {
        let isNormalized = corners.topLeft.x <= 1.0 && corners.topRight.x <= 1.0 &&
                           corners.bottomRight.x <= 1.0 && corners.bottomLeft.x <= 1.0 &&
                           corners.topLeft.y <= 1.0 && corners.topRight.y <= 1.0 &&
                           corners.bottomRight.y <= 1.0 && corners.bottomLeft.y <= 1.0
        
        let scaleX = isNormalized ? imageSize.width : 1.0
        let scaleY = isNormalized ? imageSize.height : 1.0
        
        let tl = CIVector(x: corners.topLeft.x * scaleX, y: corners.topLeft.y * scaleY)
        let tr = CIVector(x: corners.topRight.x * scaleX, y: corners.topRight.y * scaleY)
        let br = CIVector(x: corners.bottomRight.x * scaleX, y: corners.bottomRight.y * scaleY)
        let bl = CIVector(x: corners.bottomLeft.x * scaleX, y: corners.bottomLeft.y * scaleY)
        
        return (topLeft: tl, topRight: tr, bottomRight: br, bottomLeft: bl)
    }
    
    /// Applies perspective correction to deskew a document or receipt given 4 detected quadrilateral points.
    public func applyPerspectiveCorrection(
        to ciImage: CIImage,
        corners: QuadrilateralCorners,
        imageSize: CGSize
    ) -> CIImage {
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return ciImage }
        
        let vectors = coreImageVectors(for: corners, imageSize: imageSize)
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(vectors.topLeft, forKey: "inputTopLeft")
        filter.setValue(vectors.topRight, forKey: "inputTopRight")
        filter.setValue(vectors.bottomRight, forKey: "inputBottomRight")
        filter.setValue(vectors.bottomLeft, forKey: "inputBottomLeft")
        
        return filter.outputImage ?? ciImage
    }
    #endif
    
    #if canImport(UIKit)
    /// Convenience helper for UIImages
    public func enhanceUIImage(_ image: UIImage, options: ImageEnhancementOptions = ImageEnhancementOptions()) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        #if canImport(CoreImage)
        let enhanced = enhanceImage(cgImage, options: options)
        return UIImage(cgImage: enhanced, scale: image.scale, orientation: image.imageOrientation)
        #else
        return image
        #endif
    }
    #endif
}
