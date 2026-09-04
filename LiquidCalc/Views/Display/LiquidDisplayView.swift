//
//  LiquidDisplayView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct ShakeEffect: GeometryEffect {
    public var amount: CGFloat = 14
    public var shakesPerUnit: CGFloat = 4
    public var animatableData: CGFloat
    
    public init(shakes: CGFloat, amount: CGFloat = 14, shakesPerUnit: CGFloat = 4) {
        self.animatableData = shakes
        self.amount = amount
        self.shakesPerUnit = shakesPerUnit
    }
    
    public func effectValue(size: CGSize) -> ProjectionTransform {
        // Exponentially decaying physical harmonic oscillation
        let decay = exp(-3.5 * animatableData)
        let oscillation = sin(animatableData * .pi * 2 * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(
            translationX: amount * decay * oscillation,
            y: 0
        ))
    }
}

public struct DisplaySparkle: Identifiable, Sendable {
    public let id = UUID()
    public var x: CGFloat
    public var y: CGFloat
    public var scale: CGFloat
    public var opacity: Double
    public var rotation: Double
    public var color: Color
    public var size: CGFloat
}

public struct LiquidDisplayView: View {
    @Bindable var viewModel: CalculatorViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakeAmount: CGFloat = 0
    @State private var showCopiedHUD = false
    @State private var cursorBlink = false
    @State private var resultPulse = false
    @State private var sparkles: [DisplaySparkle] = []
    @State private var rippleScale: CGFloat = 0.85
    @State private var rippleOpacity: Double = 0.0
    
    public init(viewModel: CalculatorViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            // Status Badges Header (Memory, Angle Mode, Error, Copied HUD)
            HStack(spacing: 8) {
                if viewModel.hasMemory {
                    Text("M")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.3))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.orange.opacity(0.5), lineWidth: 0.5))
                        .transition(.scale.combined(with: .opacity))
                }
                
                Text(viewModel.angleUnit.rawValue.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white.opacity(0.7))
                    .clipShape(Capsule())
                
                Spacer()
                
                if showCopiedHUD {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .symbolEffect(.bounce, value: showCopiedHUD)
                        Text("Copied to Clipboard")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.green.opacity(0.15)))
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                } else if let errorMsg = viewModel.errorMessage {
                    Text(errorMsg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red.opacity(0.9))
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            
            // Expression Scroll View with subtle breathing cursor
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    Spacer()
                    Text(viewModel.expression.isEmpty ? " " : viewModel.expression)
                        .font(.system(size: 22, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                    
                    // Clean Cyan Expression Cursor Dot
                    if !viewModel.expression.isEmpty {
                        Circle()
                            .fill(Color.cyan.opacity(0.85))
                            .frame(width: 4, height: 4)
                            .scaleEffect(cursorBlink ? 1.0 : 0.45)
                            .opacity(cursorBlink ? 1.0 : 0.35)
                            .animation(
                                reduceMotion ? .default : .easeInOut(duration: 0.78).repeatForever(autoreverses: true),
                                value: cursorBlink
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Primary Result Display with Gesture Interaction & iOS 18 Numeric Transition
            ZStack {
                // Smooth Fluid Ripple Wave Effect upon evaluation / equals tap
                if rippleOpacity > 0.01 {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.85), Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.5), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.2
                        )
                        .scaleEffect(rippleScale)
                        .opacity(rippleOpacity)
                        .blur(radius: 0.8)
                        .allowsHitTesting(false)
                }
                
                HStack {
                    Spacer()
                    ZStack(alignment: .trailing) {
                        Text(viewModel.displayResult)
                            .font(.system(size: resultFontSize, weight: .regular, design: .rounded))
                            .foregroundColor(viewModel.hasError ? .red : .white)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: viewModel.displayResult)
                            .scaleEffect(resultPulse && !reduceMotion ? 1.025 : 1.0)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .modifier(ShakeEffect(shakes: shakeAmount))
                        
                        // Floating Particle Sparkles upon evaluation / equals tap
                        ForEach(sparkles) { particle in
                            Image(systemName: "sparkle")
                                .font(.system(size: particle.size, weight: .bold))
                                .foregroundColor(particle.color)
                                .scaleEffect(particle.scale)
                                .rotationEffect(.degrees(particle.rotation))
                                .opacity(particle.opacity)
                                .offset(x: particle.x, y: particle.y)
                                .shadow(color: particle.color.opacity(0.8), radius: 5)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 70)
            // Gesture: Swipe to delete last character
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { value in
                        if abs(value.translation.width) > 30 {
                            SoundAndHapticManager.shared.triggerHaptic(.light)
                            SoundAndHapticManager.shared.playKeySound()
                            withAnimation(.spring(response: 0.18, dampingFraction: 0.75)) {
                                viewModel.deleteBackward()
                            }
                        }
                    }
            )
            // Gesture: Long press to copy result
            .onLongPressGesture {
                #if os(iOS)
                UIPasteboard.general.string = viewModel.displayResult
                #endif
                SoundAndHapticManager.shared.triggerHaptic(.medium)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showCopiedHUD = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showCopiedHUD = false
                    }
                }
            }
            
            // Live Speculative Preview with Elastic Pill Animation
            HStack {
                Spacer()
                if let preview = viewModel.livePreview, preview != viewModel.displayResult {
                    HStack(spacing: 5) {
                        Text("=")
                            .foregroundColor(.cyan.opacity(0.65))
                            .font(.system(size: 15, weight: .bold))
                        Text(preview)
                            .foregroundColor(.cyan)
                            .contentTransition(.numericText())
                    }
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.cyan.opacity(0.14))
                            .overlay(
                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.cyan.opacity(0.45), Color.blue.opacity(0.20)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: Color.cyan.opacity(0.25), radius: 6)
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: preview)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 26)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(white: 0.12, opacity: 0.38))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.20), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.1
                        )
                )
        )
        .padding(.horizontal, 12)
        .onAppear {
            cursorBlink = true
        }
        .onChange(of: viewModel.displayResult) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.10)) {
                resultPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.62)) {
                    resultPulse = false
                }
            }
        }
        .onChange(of: viewModel.evaluationTriggerCount) { _, _ in
            triggerEvaluationFX()
        }
        .onChange(of: viewModel.shouldShakeDisplay) { _, newValue in
            if newValue {
                SoundAndHapticManager.shared.triggerHaptic(.error)
                withAnimation(.linear(duration: 0.45)) {
                    shakeAmount = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        shakeAmount = 0
                    }
                }
            }
        }
    }
    
    private func triggerEvaluationFX() {
        guard !reduceMotion else { return }
        
        // 1. Smooth Ripple Animation across Display
        rippleScale = 0.85
        rippleOpacity = 0.80
        withAnimation(.easeOut(duration: 0.65)) {
            rippleScale = 1.18
            rippleOpacity = 0.0
        }
        
        // 2. Floating Particle Sparkles Burst
        let colors: [Color] = [.cyan, .yellow, .white, Color(red: 0.0, green: 1.0, blue: 0.64)]
        var initialSparkles: [DisplaySparkle] = []
        for _ in 0..<14 {
            let angle = Double.random(in: 0...2 * .pi)
            let distance = CGFloat.random(in: 8...25)
            let color = colors.randomElement() ?? .cyan
            let size = CGFloat.random(in: 10...18)
            initialSparkles.append(
                DisplaySparkle(
                    x: cos(angle) * distance - 20,
                    y: sin(angle) * distance,
                    scale: 0.2,
                    opacity: 1.0,
                    rotation: Double.random(in: -30...30),
                    color: color,
                    size: size
                )
            )
        }
        sparkles = initialSparkles
        
        withAnimation(.spring(response: 0.48, dampingFraction: 0.64)) {
            for i in sparkles.indices {
                let angle = Double.random(in: 0...2 * .pi)
                let distance = CGFloat.random(in: 35...95)
                sparkles[i].x = cos(angle) * distance - 20
                sparkles[i].y = sin(angle) * distance
                sparkles[i].scale = CGFloat.random(in: 0.9...1.3)
                sparkles[i].rotation += Double.random(in: 60...180)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.easeOut(duration: 0.38)) {
                for i in sparkles.indices {
                    sparkles[i].opacity = 0.0
                    sparkles[i].scale = 0.1
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            sparkles.removeAll()
        }
    }
    
    private var resultFontSize: CGFloat {
        let count = viewModel.displayResult.count
        if count > 12 { return 36 }
        if count > 8 { return 46 }
        return 58
    }
}
