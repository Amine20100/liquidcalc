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

public struct LiquidDisplayView: View {
    @Bindable var viewModel: CalculatorViewModel
    @State private var shakeAmount: CGFloat = 0
    @State private var showCopiedHUD = false
    @State private var cursorBlink = false
    
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
                    
                    // Living Cyan Expression Cursor Dot
                    if !viewModel.expression.isEmpty {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 4, height: 4)
                            .opacity(cursorBlink ? 0.9 : 0.2)
                            .scaleEffect(cursorBlink ? 1.2 : 0.8)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: cursorBlink)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Primary Result Display with Gesture Interaction & iOS 18 Numeric Transition
            HStack {
                Spacer()
                Text(viewModel.displayResult)
                    .font(.system(size: resultFontSize, weight: .regular, design: .rounded))
                    .foregroundColor(viewModel.hasError ? .red : .white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.22, dampingFraction: 0.78), value: viewModel.displayResult)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .modifier(ShakeEffect(shakes: shakeAmount))
            }
            .padding(.horizontal, 16)
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
    
    private var resultFontSize: CGFloat {
        let count = viewModel.displayResult.count
        if count > 12 { return 36 }
        if count > 8 { return 46 }
        return 58
    }
}
