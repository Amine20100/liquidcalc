//
//  SmartVisionView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Milestone M2: Vision Scanner Motion, Visual FX & Advanced Frameworks Integration
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
    private let onSendToAI: ((WorkspaceContext) -> Void)?
    private let onSaveToNotes: ((WorkspaceContext) -> Void)?
    
    public init(
        calculatorViewModel: CalculatorViewModel,
        onSendToAI: ((WorkspaceContext) -> Void)? = nil,
        onSaveToNotes: ((WorkspaceContext) -> Void)? = nil
    ) {
        self.calculatorViewModel = calculatorViewModel
        self.onSendToAI = onSendToAI
        self.onSaveToNotes = onSaveToNotes
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Mode Selectors Header
            HStack(spacing: 8) {
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
                            .padding(.horizontal, 10)
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
                
                // Scan Mode Picker (Guided, Live, VisionKit)
                Picker("Scan mode", selection: $viewModel.scanMode) {
                    ForEach(VisionScanMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
                .accessibilityLabel("Scanning mode")
            }
            .padding(.horizontal, 12)

            // Guidance Banner & Framework Status
            HStack(spacing: 6) {
                Text(guidanceText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                
                if let contour = viewModel.contourResult, contour.isLikelyHandwritten {
                    Text("✍️ Handwritten")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.yellow.opacity(0.18)))
                }
            }
            .padding(.horizontal, 24)
            
            // Viewfinder Container
            ZStack {
                // Camera Feed: VisionKit DataScanner or Custom AVFoundation Engine
                if viewModel.scanMode == .visionKit && viewModel.isVisionKitSupported {
                    VisionKitDataScannerView(
                        isScanning: $viewModel.isScanning,
                        onTextRecognized: { texts in
                            viewModel.handleVisionKitRecognized(texts: texts)
                        },
                        onItemTapped: { itemText in
                            viewModel.handleVisionKitItemTapped(text: itemText)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    CameraPreviewView(captureService: viewModel.cameraService) { point, bounds in
                        viewModel.handleTapToFocus(pointInView: point, viewBounds: bounds)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                
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
                
                // Real-Time Document Perspective Boundary Overlay
                if let quad = viewModel.detectedQuad {
                    GeometryReader { geo in
                        Path { path in
                            let w = geo.size.width
                            let h = geo.size.height
                            path.move(to: CGPoint(x: quad.topLeft.x * w, y: (1.0 - quad.topLeft.y) * h))
                            path.addLine(to: CGPoint(x: quad.topRight.x * w, y: (1.0 - quad.topRight.y) * h))
                            path.addLine(to: CGPoint(x: quad.bottomRight.x * w, y: (1.0 - quad.bottomRight.y) * h))
                            path.addLine(to: CGPoint(x: quad.bottomLeft.x * w, y: (1.0 - quad.bottomLeft.y) * h))
                            path.closeSubpath()
                        }
                        .stroke(Color.green.opacity(0.75), style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                
                // Animated Tap-to-Focus Reticle Indicator
                if viewModel.showTapFocusReticle, let tapPt = viewModel.tapFocusLocation {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: 56, height: 56)
                        .position(tapPt)
                        .shadow(color: Color.yellow.opacity(0.8), radius: 6)
                        .transition(.scale(scale: 1.25).combined(with: .opacity))
                }
                
                // Expanding Sonar/Radar Wave Pulse Rings
                if viewModel.isScanning {
                    SonarWaveRingsView(isScanning: viewModel.isScanning)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
                
                // State-Driven Pulsing & Locking Reticle Overlay
                ReticleOverlayView(
                    isScanning: viewModel.isScanning,
                    hasTarget: viewModel.hasDetectedTarget,
                    targetBoundingBox: viewModel.targetBoundingBox
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                
                // Animated Scanning Laser Sweep Line
                if viewModel.isScanning {
                    LaserSweepLineView(isScanning: viewModel.isScanning)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                
                // Solved Result Reveal Card Overlay (Equation Mode)
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

            // Framework Enhancements Control Bar (Deskew, Enhance, AE Lock, Live Text)
            HStack(spacing: 12) {
                // Auto-Deskew CoreImage Toggle
                Button(action: {
                    SoundAndHapticManager.shared.triggerHaptic(.light)
                    viewModel.isDeskewEnabled.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "crop")
                            .font(.system(size: 11))
                        Text("Deskew")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(viewModel.isDeskewEnabled ? Color.cyan.opacity(0.25) : Color.white.opacity(0.08))
                    .foregroundStyle(viewModel.isDeskewEnabled ? Color.cyan : Color.white.opacity(0.6))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                // Auto-Enhance Filter Toggle
                Button(action: {
                    SoundAndHapticManager.shared.triggerHaptic(.light)
                    viewModel.isEnhanceEnabled.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11))
                        Text("Enhance")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(viewModel.isEnhanceEnabled ? Color.cyan.opacity(0.25) : Color.white.opacity(0.08))
                    .foregroundStyle(viewModel.isEnhanceEnabled ? Color.cyan : Color.white.opacity(0.6))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                // Auto-Exposure Lock
                Button(action: {
                    viewModel.toggleExposureLock()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isExposureLocked ? "lock.fill" : "lock.open")
                            .font(.system(size: 11))
                        Text("AE Lock")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(viewModel.isExposureLocked ? Color.yellow.opacity(0.25) : Color.white.opacity(0.08))
                    .foregroundStyle(viewModel.isExposureLocked ? Color.yellow : Color.white.opacity(0.6))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                // Live Text Inspector (for loaded photos)
                if viewModel.loadedPhotoForAnalysis != nil {
                    Button(action: {
                        SoundAndHapticManager.shared.triggerHaptic(.selection)
                        viewModel.showLiveTextAnalysisSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "text.viewfinder")
                                .font(.system(size: 11))
                            Text("Live Text")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.25))
                        .foregroundStyle(Color.green)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            if viewModel.hasDetectedTarget {
                scanReviewCard
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
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
        .task(id: viewModel.scanMode) {
            guard viewModel.scanMode == .live else { return }
            while !Task.isCancelled && viewModel.scanMode == .live {
                viewModel.scanCurrentFrame()
                try? await Task.sleep(nanoseconds: 1_600_000_000)
            }
        }
        .onDisappear {
            viewModel.stopCamera()
        }
        #if canImport(UIKit)
        .sheet(isPresented: $viewModel.showLiveTextAnalysisSheet) {
            if let img = viewModel.loadedPhotoForAnalysis {
                NavigationStack {
                    LiveTextImageAnalysisView(image: img) { selectedMath in
                        viewModel.detectedExpression = selectedMath
                        viewModel.solveDetectedExpression()
                        viewModel.showLiveTextAnalysisSheet = false
                    }
                    .navigationTitle("Live Text Math Inspector")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                viewModel.showLiveTextAnalysisSheet = false
                            }
                        }
                    }
                }
            }
        }
        #endif
    }

    private var guidanceText: String {
        switch viewModel.scanMode {
        case .guided:
            return "Tap camera feed to focus. Pinch to zoom."
        case .live:
            return "Live Apple Vision tracking active. Point at equation."
        case .visionKit:
            return "VisionKit live scanner active. Tap on recognized text."
        }
    }

    private var scanReviewCard: some View {
        LiquidSurface {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Label("Review capture", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.green)
                    Spacer()
                    Text("\(Int(viewModel.recognitionConfidence * 100))% confidence")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
                
                if viewModel.selectedSubMode == .equation {
                    TextField("Recognized expression", text: $viewModel.detectedExpression)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 10))
                    
                    if let result = viewModel.solvedResult {
                        HStack {
                            Text("Answer:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                            Text(result)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.64))
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    if !viewModel.detectedSteps.isEmpty {
                        DisclosureGroup("Derivation Steps (\(viewModel.detectedSteps.count))") {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(viewModel.detectedSteps.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("\(index + 1).")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.cyan)
                                        Text(step)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.85))
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.cyan)
                    }
                    
                    HStack(spacing: 8) {
                        reviewAction("Calculate", icon: "equal") {
                            calculatorViewModel.expression = viewModel.detectedExpression
                            calculatorViewModel.evaluateFinal()
                        }
                        reviewAction("Ask AI", icon: "sparkles") {
                            onSendToAI?(.scan(expression: viewModel.detectedExpression, result: viewModel.solvedResult))
                        }
                        reviewAction("Save", icon: "square.and.pencil") {
                            onSaveToNotes?(.scan(expression: viewModel.detectedExpression, result: viewModel.solvedResult))
                        }
                    }
                } else {
                    Text("\(viewModel.receiptItems.count) receipt items ready to review and split.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .padding(12)
        }
    }

    private func reviewAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 38)
        }
        .foregroundStyle(.cyan)
        .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}
