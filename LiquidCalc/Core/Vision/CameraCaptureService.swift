//
//  CameraCaptureService.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
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
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDevice: AVCaptureDevice?
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
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                self.videoDevice = device
                if let input = try? AVCaptureDeviceInput(device: device), self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
            }
            
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
        }
        #endif
    }
    
    public func stopSession() {
        #if canImport(AVFoundation)
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
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
                try device.setTorchModeOn(level: 1.0)
                isTorchOn = true
            }
            device.unlockForConfiguration()
        } catch {}
        #endif
    }
    
    public func capturePhoto(completion: @escaping (CGImage?) -> Void) {
        #if canImport(AVFoundation)
        let settings = AVCapturePhotoSettings()
        let photoDelegate = PhotoCaptureDelegate { cgImage in
            completion(cgImage)
        }
        self.activePhotoDelegate = photoDelegate
        self.photoOutput.capturePhoto(with: settings, delegate: photoDelegate)
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
            completion(nil)
            return
        }
        completion(cgImage)
    }
}
#endif
