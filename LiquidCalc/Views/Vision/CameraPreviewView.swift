//
//  CameraPreviewView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Zero-Lag Hardware-Accelerated Camera Preview Layer with Tap-to-Focus & Pinch-to-Zoom
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
    
    public weak var captureService: CameraCaptureService?
    public var onFocusTap: ((CGPoint, CGRect) -> Void)?
    private var baseZoomFactor: CGFloat = 1.0
    private var focusBoxView: UIView?
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
        isUserInteractionEnabled = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinchGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        if bounds.width > 0 && bounds.height > 0 {
            let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
            captureService?.focus(at: devicePoint)
            captureService?.lastFocusTapLocation = point
        } else {
            captureService?.focusAtPointInView(point, viewBounds: bounds)
        }
        showFocusAnimation(at: point)
        onFocusTap?(point, bounds)
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let service = captureService else { return }
        switch gesture.state {
        case .began:
            baseZoomFactor = service.currentZoomFactor
        case .changed:
            let targetZoom = baseZoomFactor * gesture.scale
            service.setZoomFactor(targetZoom)
        default:
            break
        }
    }
    
    private func showFocusAnimation(at point: CGPoint) {
        focusBoxView?.removeFromSuperview()
        
        let boxSize: CGFloat = 64
        let box = UIView(frame: CGRect(x: point.x - boxSize / 2, y: point.y - boxSize / 2, width: boxSize, height: boxSize))
        box.layer.borderColor = UIColor.systemYellow.cgColor
        box.layer.borderWidth = 1.5
        box.layer.cornerRadius = 8
        box.backgroundColor = UIColor.clear
        box.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        box.alpha = 0.0
        addSubview(box)
        self.focusBoxView = box
        
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            box.transform = .identity
            box.alpha = 1.0
        } completion: { _ in
            UIView.animate(withDuration: 0.35, delay: 0.8, options: .curveEaseIn) {
                box.alpha = 0.0
            } completion: { _ in
                box.removeFromSuperview()
            }
        }
    }
}
#endif

public struct CameraPreviewView: UIViewRepresentable {
    public let captureService: CameraCaptureService
    public var onFocusTap: ((CGPoint, CGRect) -> Void)? = nil
    
    public init(captureService: CameraCaptureService, onFocusTap: ((CGPoint, CGRect) -> Void)? = nil) {
        self.captureService = captureService
        self.onFocusTap = onFocusTap
    }
    
    public func makeUIView(context: Context) -> UIView {
        #if canImport(AVFoundation) && canImport(UIKit)
        let view = CameraPreviewLayerView(frame: .zero)
        view.captureService = captureService
        view.onFocusTap = onFocusTap
        view.previewLayer.session = captureService.session
        return view
        #else
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        return view
        #endif
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        #if canImport(AVFoundation) && canImport(UIKit)
        if let previewView = uiView as? CameraPreviewLayerView {
            previewView.captureService = captureService
            previewView.onFocusTap = onFocusTap
        }
        #endif
    }
}
