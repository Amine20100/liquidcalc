//
//  CameraPreviewView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(UIKit)
import UIKit
#endif

public struct CameraPreviewView: UIViewRepresentable {
    public let captureService: CameraCaptureService
    
    public init(captureService: CameraCaptureService) {
        self.captureService = captureService
    }
    
    public func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        #if canImport(AVFoundation)
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureService.session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        #endif
        
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        #if canImport(AVFoundation)
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
        #endif
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public final class Coordinator {
        #if canImport(AVFoundation)
        var previewLayer: AVCaptureVideoPreviewLayer?
        #endif
    }
}
