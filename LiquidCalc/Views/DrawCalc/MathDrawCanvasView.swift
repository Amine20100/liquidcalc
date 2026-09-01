//
//  MathDrawCanvasView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Draw Calc (Math Notes & Finger/Stylus Handwriting Math with Gemini 2.5 Flash AI)
//

import SwiftUI

public struct MathDrawCanvasView: View {
    @State private var viewModel = DrawCalcViewModel()
    @State private var canvasSize: CGSize = .zero
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Frosted Grid Paper Background
                gridBackground(size: geometry.size)
                
                // Drawing Canvas
                Canvas { context, size in
                    for stroke in viewModel.strokes {
                        renderStroke(stroke, context: context)
                    }
                    if let active = viewModel.currentStroke {
                        renderStroke(active, context: context)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            if viewModel.currentStroke == nil {
                                viewModel.startStroke(at: value.location)
                            } else {
                                viewModel.appendPoint(value.location)
                            }
                        }
                        .onEnded { _ in
                            viewModel.finishStroke(canvasSize: geometry.size)
                        }
                )
                
                // Live Solved Motion Overlay (animates result text beside drawn equation)
                if viewModel.isRevealingResult, let result = viewModel.solvedResult, !viewModel.showGeminiCard {
                    solvedMotionBadge(result: result)
                }
                
                // Gemini 2.5 Flash Floating AI Solution Card
                if viewModel.showGeminiCard, let result = viewModel.solvedResult {
                    geminiSolutionCard(result: result)
                }
                
                // Top Live Recognition Pill & Status Bar
                VStack {
                    topStatusPill
                        .padding(.top, 8)
                    
                    Spacer()
                    
                    // Floating Liquid Glass Drawing Tool Palette
                    drawingToolPalette
                        .padding(.bottom, 12)
                }
            }
            .onAppear {
                canvasSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                canvasSize = newSize
            }
        }
    }
    
    // MARK: - Canvas Rendering
    
    private func renderStroke(_ stroke: DrawingStroke, context: GraphicsContext) {
        guard stroke.points.count > 1 else { return }
        
        var path = Path()
        path.move(to: stroke.points[0].point)
        for p in stroke.points.dropFirst() {
            path.addLine(to: p.point)
        }
        
        switch stroke.tool {
        case .glowPen:
            // Dual-layer glow rendering: outer blur aura + core neon laser
            context.stroke(path, with: .color(stroke.color.opacity(0.4)), lineWidth: stroke.lineWidth * 2.8)
            context.stroke(path, with: .color(stroke.color), lineWidth: stroke.lineWidth)
        case .pen:
            context.stroke(path, with: .color(stroke.color), style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round))
        case .highlighter:
            context.stroke(path, with: .color(stroke.color.opacity(0.35)), style: StrokeStyle(lineWidth: stroke.lineWidth * 3.5, lineCap: .square, lineJoin: .bevel))
        case .eraser:
            break
        }
    }
    
    private func gridBackground(size: CGSize) -> some View {
        Canvas { context, sz in
            let step: CGFloat = 28.0
            var path = Path()
            
            var x: CGFloat = 0
            while x < sz.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: sz.height))
                x += step
            }
            
            var y: CGFloat = 0
            while y < sz.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: sz.width, y: y))
                y += step
            }
            
            context.stroke(path, with: .color(Color.white.opacity(0.04)), lineWidth: 0.8)
        }
    }
    
    // MARK: - Animated Solve Motion Badge
    
    @ViewBuilder
    private func solvedMotionBadge(result: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.cyan)
            
            Text(result)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .cyan.opacity(0.6), radius: 10)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(white: 0.15, opacity: 0.85))
                .overlay(Capsule().stroke(Color.cyan.opacity(0.6), lineWidth: 1.5))
                .shadow(color: Color.cyan.opacity(0.4), radius: 12)
        )
        .scaleEffect(viewModel.revealProgress)
        .opacity(Double(viewModel.revealProgress))
        .position(viewModel.lastResultPosition)
    }
    
    // MARK: - Gemini 2.5 Flash Floating AI Solution Card
    
    @ViewBuilder
    private func geminiSolutionCard(result: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.cyan)
                Text("Gemini 2.5 Flash AI Solution")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        viewModel.showGeminiCard = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Text(viewModel.recognizedExpression)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
            
            Text(result)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.cyan)
            
            if !viewModel.geminiSteps.isEmpty {
                Divider().background(Color.white.opacity(0.15))
                ForEach(Array(viewModel.geminiSteps.prefix(3).enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(idx + 1).")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                        Text(step)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            
            if let explanation = viewModel.geminiExplanation, !explanation.isEmpty {
                Text(explanation)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.65))
            }
        }
        .padding(14)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.1, opacity: 0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LinearGradient(colors: [.cyan.opacity(0.7), .purple.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.6), radius: 20)
        )
        .transition(.scale.combined(with: .opacity))
        .padding(.top, 40)
    }
    
    // MARK: - Top Status Pill
    
    private var topStatusPill: some View {
        HStack(spacing: 8) {
            if viewModel.isGeminiAnalyzing {
                ProgressView()
                    .tint(.purple)
                    .scaleEffect(0.8)
                Text("Gemini 2.5 Flash analyzing...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.purple)
            } else if viewModel.isRecognizing {
                ProgressView()
                    .tint(.cyan)
                    .scaleEffect(0.8)
                Text("Recognizing handwriting...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cyan)
            } else if !viewModel.recognizedExpression.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.cyan)
                    .font(.system(size: 12))
                Text(viewModel.recognizedExpression)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "pencil.tip")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 12))
                Text("Draw any math formula, proof, or diagram")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.5))
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
    }
    
    // MARK: - Floating Liquid Glass Tool Palette
    
    private var drawingToolPalette: some View {
        VStack(spacing: 8) {
            // Color Swatches Row
            HStack(spacing: 12) {
                ForEach([Color.cyan, Color.blue, Color.orange, Color.green, Color.purple, Color.white], id: \.self) { color in
                    Button(action: {
                        SoundAndHapticManager.shared.playDigitClick()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            viewModel.selectedColor = color
                        }
                    }) {
                        Circle()
                            .fill(color)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: viewModel.selectedColor == color ? 2.5 : 0)
                            )
                            .shadow(color: color.opacity(0.5), radius: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            
            // Tools & Actions Row
            HStack(spacing: 8) {
                // Pen Tools
                ForEach(DrawingTool.allCases) { tool in
                    Button(action: {
                        SoundAndHapticManager.shared.triggerHaptic(.selection)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            viewModel.selectedTool = tool
                        }
                    }) {
                        Image(systemName: tool.iconName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(viewModel.selectedTool == tool ? .cyan : .white.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(viewModel.selectedTool == tool ? Color.cyan.opacity(0.25) : Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(viewModel.selectedTool == tool ? Color.cyan : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                    .frame(height: 22)
                    .background(Color.white.opacity(0.2))
                
                // Gemini 2.5 Flash AI Solve Action
                Button(action: {
                    viewModel.solveWithGeminiAI(canvasSize: canvasSize)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                        Text("AI")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .frame(height: 36)
                    .background(
                        Capsule().fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .shadow(color: Color.purple.opacity(0.5), radius: 6)
                }
                .buttonStyle(.plain)
                
                // On-device Solve Action Button
                Button(action: {
                    viewModel.performRecognition(canvasSize: canvasSize)
                }) {
                    Text("Solve")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                        .background(Capsule().fill(Color.cyan))
                        .shadow(color: Color.cyan.opacity(0.4), radius: 6)
                }
                .buttonStyle(.plain)
                
                // Undo Action
                Button(action: viewModel.undo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 32, height: 36)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                
                // Clear Canvas Action
                Button(action: viewModel.clearCanvas) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.9))
                        .frame(width: 32, height: 36)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(white: 0.12, opacity: 0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 20, y: 8)
        )
        .padding(.horizontal, 12)
    }
}
