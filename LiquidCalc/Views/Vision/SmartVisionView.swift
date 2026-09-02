//
//  SmartVisionView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Milestone M2: Vision Scanner Motion & Visual FX
//

import SwiftUI
import PhotosUI

#if canImport(UIKit)
import UIKit
#endif

public struct SmartVisionView: View {
    @State private var viewModel = VisionViewModel()
    @Bindable var calculatorViewModel: CalculatorViewModel
    @State private var isTorchOn: Bool = false
    
    public init(calculatorViewModel: CalculatorViewModel) {
        self.calculatorViewModel = calculatorViewModel
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Sub-mode pill (Math vs Receipt)
            HStack(spacing: 4) {
                ForEach(VisionSubMode.allCases) { subMode in
                    Button(action: {
                        SoundAndHapticManager.shared.triggerHaptic(.selection)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            viewModel.selectedSubMode = subMode
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: subMode.iconName)
                                .font(.system(size: 11))
                            Text(subMode.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(viewModel.selectedSubMode == subMode ? Color.cyan.opacity(0.35) : Color.clear)
                        )
                        .foregroundColor(viewModel.selectedSubMode == subMode ? .white : .white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Capsule().fill(Color.black.opacity(0.4)))
            
            // Viewfinder Container
            ZStack {
                // Camera Preview Feed
                CameraPreviewView(captureService: viewModel.cameraService)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                
                // Outer Cyan/Blue Gradient Border Stroke
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(viewModel.hasDetectedTarget ? 0.3 : 0.8),
                                Color.blue.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                
                // Feature F2: Expanding Sonar/Radar Wave Pulse Rings (Underneath reticle and laser)
                if viewModel.isScanning {
                    SonarWaveRingsView(isScanning: viewModel.isScanning)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
                
                // Feature F6: State-Driven Pulsing & Locking Reticle Overlay
                ReticleOverlayView(
                    isScanning: viewModel.isScanning,
                    hasTarget: viewModel.hasDetectedTarget,
                    targetBoundingBox: viewModel.targetBoundingBox
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                
                // Feature F5: Animated Scanning Laser Sweep Line
                if viewModel.isScanning {
                    LaserSweepLineView(isScanning: viewModel.isScanning)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                
                // Feature F7: Solved Result Reveal Card Overlay (Equation Mode)
                if viewModel.selectedSubMode == .equation && !viewModel.detectedExpression.isEmpty {
                    VStack {
                        Spacer()
                        SolvedResultCardView(
                            expression: viewModel.detectedExpression,
                            result: viewModel.solvedResult,
                            steps: viewModel.detectedSteps,
                            explanation: viewModel.detectedExplanation,
                            onOpenInCalc: {
                                calculatorViewModel.expression = viewModel.detectedExpression
                                calculatorViewModel.evaluateFinal()
                                SoundAndHapticManager.shared.triggerHaptic(.success)
                            },
                            onCopy: {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = viewModel.solvedResult ?? viewModel.detectedExpression
                                #endif
                            }
                        )
                        .padding(10)
                    }
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.84, anchor: .bottom)
                                .combined(with: .opacity)
                                .combined(with: .offset(y: 24)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        )
                    )
                }
            }
            .frame(height: 260)
            .padding(.horizontal, 12)
            
            // Receipt Splitter (If in Receipt Mode)
            if viewModel.selectedSubMode == .receipt {
                ReceiptSplitterView(viewModel: viewModel)
            }
            
            Spacer(minLength: 8)
            
            // Bottom Action Controls
            HStack(spacing: 20) {
                // Torch Button
                Button(action: {
                    SoundAndHapticManager.shared.triggerHaptic(.light)
                    viewModel.cameraService.toggleTorch()
                    isTorchOn.toggle()
                }) {
                    Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: 18))
                        .foregroundColor(isTorchOn ? .yellow : .white)
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                // Primary Shutter / Scan Button with Spring Dynamics
                Button(action: {
                    viewModel.scanCurrentFrame()
                }) {
                    ZStack {
                        Circle()
                            .stroke(
                                viewModel.hasDetectedTarget
                                    ? Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.8)
                                    : Color.cyan.opacity(0.6),
                                lineWidth: 3
                            )
                            .frame(width: 72, height: 72)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: viewModel.hasDetectedTarget
                                        ? [Color(red: 0.0, green: 1.0, blue: 0.64), Color.teal]
                                        : [.cyan, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 58, height: 58)
                            .shadow(
                                color: (viewModel.hasDetectedTarget ? Color(red: 0.0, green: 1.0, blue: 0.64) : Color.cyan).opacity(0.5),
                                radius: 10
                            )
                        
                        if viewModel.isScanning {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: viewModel.hasDetectedTarget ? "checkmark" : "viewfinder")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isScanning)
                
                // Photos Library Picker / Clear Button
                if viewModel.hasDetectedTarget {
                    Button(action: {
                        SoundAndHapticManager.shared.triggerHaptic(.light)
                        viewModel.clearResults()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 8)
        }
        .onAppear {
            viewModel.startCamera()
        }
        .onDisappear {
            viewModel.stopCamera()
        }
    }
}
