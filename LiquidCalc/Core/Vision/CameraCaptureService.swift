//
//  CameraCaptureService.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  High-Performance Low-Latency Camera Capture Pipeline
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
    func cameraDidCaptureFrame(_ sampleBuffer: CMSampleBuffer)
}

public final class CameraCaptureService: NSObject {
    #if canImport(AVFoundation)
    public let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDevice: AVCaptureDevice?
    private let cameraQueue = DispatchQueue(label: "com.liquidcalc.cameraQueue", qos: .userInitiated)
    #endif
    
    public weak var delegate: CameraCaptureDelegate?
    public var isTorchOn: Bool = false
    public var isAuthorized: Bool = false
    
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
                
                // Optimize autofocus
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
            
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.isHighResolutionCaptureEnabled = false // Prevent 48MP stalls
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
