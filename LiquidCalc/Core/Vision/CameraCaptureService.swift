//
//  CameraCaptureService.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  High-Performance Low-Latency Camera Capture Pipeline with 60fps Streaming & Tap-to-Focus
//

import Foundation
import CoreGraphics

#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(UIKit)
import UIKit
#endif

public protocol CameraCaptureDelegate: AnyObject {
    #if canImport(AVFoundation)
    func cameraDidCaptureFrame(_ sampleBuffer: CMSampleBuffer)
    #endif
}

public final class CameraCaptureService: NSObject {
    #if canImport(AVFoundation)
    public let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var videoDevice: AVCaptureDevice?
    private let cameraQueue = DispatchQueue(label: "com.liquidcalc.cameraQueue", qos: .userInitiated)
    private let videoDataQueue = DispatchQueue(label: "com.liquidcalc.videoDataQueue", qos: .userInteractive)
    #endif
    
    public weak var delegate: CameraCaptureDelegate?
    public var isTorchOn: Bool = false
    public var isAuthorized: Bool = false
    public var isExposureLocked: Bool = false
    public var lastFocusTapLocation: CGPoint? = nil
    
    public var currentZoomFactor: CGFloat = 1.0
    public var minZoomFactor: CGFloat = 1.0
    public var maxZoomFactor: CGFloat = 5.0
    
    public override init() {
        super.init()
    }
    
    public func checkPermissions(completion: @escaping (Bool) -> Void) {
        #if canImport(AVFoundation)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isAuthorized = true
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    completion(granted)
                }
            }
        default:
            self.isAuthorized = false
            completion(false)
        }
        #else
        completion(false)
        #endif
    }
    
    public func startSession() {
        #if canImport(AVFoundation)
        guard !session.isRunning else { return }
        
        cameraQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            
            // Use optimal 1080p for crisp OCR without massive memory or thermal overhead
            if self.session.canSetSessionPreset(.hd1920x1080) {
                self.session.sessionPreset = .hd1920x1080
            } else {
                self.session.sessionPreset = .high
            }
            
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                self.videoDevice = device
                self.minZoomFactor = device.minAvailableVideoZoomFactor
                self.maxZoomFactor = min(device.maxAvailableVideoZoomFactor, 6.0)
                
                // Optimize autofocus and autoexposure
                do {
                    try device.lockForConfiguration()
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                    device.unlockForConfiguration()
                } catch {}
                
                if let input = try? AVCaptureDeviceInput(device: device), self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
            }
            
            // Configure Still Photo Output
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.isHighResolutionCaptureEnabled = false // Prevent stalls
            }
            
            // Configure Continuous 60fps Video Data Output
            if self.session.canAddOutput(self.videoDataOutput) {
                self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
                self.videoDataOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoDataQueue)
                self.session.addOutput(self.videoDataOutput)
                
                if let connection = self.videoDataOutput.connection(with: .video) {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                }
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
        }
        #endif
    }
    
    public func stopSession() {
        #if canImport(AVFoundation)
        guard session.isRunning else { return }
        cameraQueue.async { [weak self] in
            self?.session.stopRunning()
        }
        #endif
    }
    
    // MARK: - Advanced Controls: Tap-to-Focus & Tap-to-Expose
    
    /// Translates a tap location from SwiftUI view bounds to the normalized camera sensor coordinates and focuses.
    public func focusAtPointInView(_ point: CGPoint, viewBounds: CGRect) {
        guard viewBounds.width > 0, viewBounds.height > 0 else { return }
        self.lastFocusTapLocation = point
        
        // Portrait orientation: X is normalized Y, Y is normalized 1 - X
        let devicePoint = CGPoint(
            x: max(0.0, min(1.0, point.y / viewBounds.height)),
            y: max(0.0, min(1.0, 1.0 - (point.x / viewBounds.width)))
        )
        focus(at: devicePoint)
    }
    
    public func focus(at devicePoint: CGPoint, isContinuous: Bool = false) {
        #if canImport(AVFoundation)
        cameraQueue.async { [weak self] in
            guard let self = self, let device = self.videoDevice else { return }
            do {
                try device.lockForConfiguration()
                
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = isContinuous ? .continuousAutoFocus : .autoFocus
                }
                
                if device.isExposurePointOfInterestSupported && !self.isExposureLocked {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = isContinuous ? .continuousAutoExposure : .autoExpose
                }
                
                device.unlockForConfiguration()
            } catch {}
        }
        #endif
    }
    
    // MARK: - Auto-Exposure Lock
    
    public func setExposureLocked(_ locked: Bool) {
        #if canImport(AVFoundation)
        cameraQueue.async { [weak self] in
            guard let self = self, let device = self.videoDevice else { return }
            do {
                try device.lockForConfiguration()
                if locked {
                    if device.isExposureModeSupported(.locked) {
                        device.exposureMode = .locked
                        self.isExposureLocked = true
                    }
                } else {
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                        self.isExposureLocked = false
                    }
                }
                device.unlockForConfiguration()
            } catch {}
        }
        #else
        self.isExposureLocked = locked
        #endif
    }
    
    // MARK: - Pinch-to-Zoom
    
    public func setZoomFactor(_ factor: CGFloat) {
        let clamped = max(minZoomFactor, min(factor, maxZoomFactor))
        self.currentZoomFactor = clamped
        
        #if canImport(AVFoundation)
        cameraQueue.async { [weak self] in
            guard let self = self, let device = self.videoDevice else { return }
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch {}
        }
        #endif
    }
    
    // MARK: - Torch / Flashlight Control
    
    public func toggleTorch() {
        #if canImport(AVFoundation)
        guard let device = videoDevice, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if device.torchMode == .on {
                device.torchMode = .off
                isTorchOn = false
            } else {
                try device.setTorchModeOn(level: 0.7)
                isTorchOn = true
            }
            device.unlockForConfiguration()
        } catch {}
        #endif
    }
    
    // MARK: - Still Photo Capture
    
    public func capturePhoto(completion: @escaping (CGImage?) -> Void) {
        #if canImport(AVFoundation)
        cameraQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let settings = AVCapturePhotoSettings()
            let photoDelegate = PhotoCaptureDelegate { cgImage in
                completion(cgImage)
            }
            self.activePhotoDelegate = photoDelegate
            self.photoOutput.capturePhoto(with: settings, delegate: photoDelegate)
        }
        #else
        completion(nil)
        #endif
    }
    
    #if canImport(AVFoundation)
    private var activePhotoDelegate: PhotoCaptureDelegate?
    #endif
}

#if canImport(AVFoundation)
extension CameraCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        delegate?.cameraDidCaptureFrame(sampleBuffer)
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (CGImage?) -> Void
    
    init(completion: @escaping (CGImage?) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let cgImage = photo.cgImageRepresentation() else {
            DispatchQueue.main.async { self.completion(nil) }
            return
        }
        
        // Downscale in background if larger than 1920 to ensure 60fps responsiveness
        let width = cgImage.width
        let height = cgImage.height
        let maxDim = max(width, height)
        
        if maxDim > 1920 {
            let scale = 1920.0 / Double(maxDim)
            let newWidth = Int(Double(width) * scale)
            let newHeight = Int(Double(height) * scale)
            
            if let colorSpace = cgImage.colorSpace,
               let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: cgImage.bitmapInfo.rawValue
               ) {
                context.interpolationQuality = .medium
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
                if let resized = context.makeImage() {
                    self.completion(resized)
                    return
                }
            }
        }
        
        self.completion(cgImage)
    }
}
#endif
