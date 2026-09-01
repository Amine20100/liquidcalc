//
//  MathDrawCanvasView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Interactive Finger & Apple Pencil Math Drawing Canvas with Animated Solve Motion FX
//

import SwiftUI

public struct MathDrawCanvasView: View {
    @State private var viewModel = DrawCalcViewModel()
    @State private var canvasSize: CGSize = .zero
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background dark frosted slate
                Color(red: 0.06, green: 0.07, blue: 0.10)
                    .ignoresSafeArea()
                
                // Subtle graph grid lines on canvas
                gridBackground(size: geometry.size)
                
                // Drawing Canvas
                Canvas { context, size in
                    // Render completed strokes
                    for stroke in viewModel.strokes {
                        renderStroke(stroke, context: context)
                    }
                    // Render currently active dragging stroke
                    if let active = viewModel.currentStroke {
                        renderStroke(active, context: context)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
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
                if viewModel.isRevealingResult, let result = viewModel.solvedResult {
                    solvedMotionBadge(result: result)
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
                .fill(Color.black.opacity(0.75))
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .cyan.opacity(0.4), radius: 14)
        )
        .scaleEffect(viewModel.revealProgress)
        .position(viewModel.lastResultPosition)
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Top Status Pill
    
    private var topStatusPill: some View {
        HStack(spacing: 8) {
            if viewModel.isRecognizing {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.cyan)
                Text("Recognizing Handwriting...")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.cyan)
            } else if !viewModel.recognizedExpression.isEmpty {
                Image(systemName: "pencil.and.scribble")
                    .foregroundColor(.cyan)
                    .font(.system(size: 12))
                
                Text(viewModel.recognizedExpression)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                if let res = viewModel.solvedResult {
                    Text("= \(res)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
            } else {
                Image(systemName: "hand.draw.fill")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 12))
                Text("Draw with fingers or Apple Pencil (e.g. 15 * 4 + 8 =)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.black.opacity(0.6)))
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
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
            HStack(spacing: 10) {
                // Pen Tools
                ForEach(DrawingTool.allCases) { tool in
                    Button(action: {
                        SoundAndHapticManager.shared.triggerHaptic(.selection)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            viewModel.selectedTool = tool
                        }
                    }) {
                        Image(systemName: tool.iconName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(viewModel.selectedTool == tool ? .cyan : .white.opacity(0.7))
                            .frame(width: 38, height: 38)
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
                    .frame(height: 24)
                    .background(Color.white.opacity(0.2))
                
                // Solve Now Action Button
                Button(action: {
                    viewModel.performRecognition(canvasSize: canvasSize)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Solve")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Capsule().fill(Color.cyan))
                    .shadow(color: Color.cyan.opacity(0.4), radius: 6)
                }
                .buttonStyle(.plain)
                
                // Undo Action
                Button(action: viewModel.undo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 36, height: 38)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                
                // Clear Canvas Action
                Button(action: viewModel.clearCanvas) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.9))
                        .frame(width: 36, height: 38)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(white: 0.12, opacity: 0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 20, y: 8)
        )
        .padding(.horizontal, 16)
    }
}
