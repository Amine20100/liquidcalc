//
//  CameraPreviewView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Zero-Lag Hardware-Accelerated Camera Preview Layer
//

import SwiftUI

#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(UIKit)
import UIKit
#endif

#if canImport(AVFoundation) && canImport(UIKit)
public final class CameraPreviewLayerView: UIView {
    public override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    public var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
    }
}
#endif

public struct CameraPreviewView: UIViewRepresentable {
    public let captureService: CameraCaptureService
    
    public init(captureService: CameraCaptureService) {
        self.captureService = captureService
    }
    
    public func makeUIView(context: Context) -> UIView {
        #if canImport(AVFoundation) && canImport(UIKit)
        let view = CameraPreviewLayerView(frame: .zero)
        view.previewLayer.session = captureService.session
        return view
        #else
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        return view
        #endif
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        // Handled automatically by UIView layer layout without main-queue thrashing
    }
}
