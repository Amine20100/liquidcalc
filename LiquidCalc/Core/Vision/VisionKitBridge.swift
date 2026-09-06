//
//  VisionKitBridge.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Native Apple VisionKit DataScanner & Live Text ImageAnalysis Suite
//

import Foundation
import CoreGraphics

#if canImport(VisionKit)
import VisionKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// Capabilities and hardware readiness for Apple VisionKit features.
public struct VisionKitCapabilities: Sendable {
    public let isDataScannerSupported: Bool
    public let isDataScannerAvailable: Bool
    public let isImageAnalysisSupported: Bool
    
    public var isFullyOperational: Bool {
        isDataScannerSupported && isDataScannerAvailable
    }
}

/// Bridge service providing compatibility and state inspection for Apple VisionKit.
public final class VisionKitBridge: @unchecked Sendable {
    public static let shared = VisionKitBridge()
    
    public init() {}
    
    /// Queries the device for VisionKit hardware and OS support.
    public func queryCapabilities() -> VisionKitCapabilities {
        #if canImport(VisionKit) && canImport(UIKit)
        if #available(iOS 16.0, *) {
            let dataScannerSupported = DataScannerViewController.isSupported
            let dataScannerAvailable = DataScannerViewController.isAvailable
            let imageAnalysisSupported = ImageAnalyzer.isSupported
            return VisionKitCapabilities(
                isDataScannerSupported: dataScannerSupported,
                isDataScannerAvailable: dataScannerAvailable,
                isImageAnalysisSupported: imageAnalysisSupported
            )
        }
        #endif
        return VisionKitCapabilities(
            isDataScannerSupported: false,
            isDataScannerAvailable: false,
            isImageAnalysisSupported: false
        )
    }
    
    #if canImport(VisionKit) && canImport(UIKit)
    /// Analyzes a UIImage with native VisionKit ImageAnalyzer for Live Text selection.
    @available(iOS 16.0, *)
    public func analyzeLiveTextImage(_ image: UIImage) async throws -> ImageAnalysis {
        let analyzer = ImageAnalyzer()
        let configuration = ImageAnalyzer.Configuration([.text, .machineReadableCode])
        return try await analyzer.image(from: image, configuration: configuration)
    }
    #endif
}
