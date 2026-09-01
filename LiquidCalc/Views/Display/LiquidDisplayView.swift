//
//  LiquidDisplayView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct ShakeEffect: GeometryEffect {
    public var amount: CGFloat = 10
    public var shakesPerUnit: CGFloat = 3
    public var animatableData: CGFloat
    
    public init(shakes: CGFloat, amount: CGFloat = 10, shakesPerUnit: CGFloat = 3) {
        self.animatableData = shakes
        self.amount = amount
        self.shakesPerUnit = shakesPerUnit
    }
    
    public func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: amount * sin(animatableData * .pi * 2 * shakesPerUnit),
            y: 0
        ))
    }
}

public struct LiquidDisplayView: View {
    @Bindable var viewModel: CalculatorViewModel
    @State private var shakeAmount: CGFloat = 0
    @State private var showCopiedHUD = false
    
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
                        Text("Copied to Clipboard")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.green)
                    .transition(.opacity)
                } else if let errorMsg = viewModel.errorMessage {
                    Text(errorMsg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red.opacity(0.9))
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            
            // Expression Scroll View
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Spacer()
                    Text(viewModel.expression.isEmpty ? " " : viewModel.expression)
                        .font(.system(size: 22, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            
            // Primary Result Display with Gesture Interaction
            HStack {
                Spacer()
                Text(viewModel.displayResult)
                    .font(.system(size: resultFontSize, weight: .regular, design: .rounded))
                    .foregroundColor(viewModel.hasError ? .red : .white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: viewModel.displayResult)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .modifier(ShakeEffect(shakes: shakeAmount))
            }
            .padding(.horizontal, 16)
            .frame(height: 70)
            // Gesture: Swipe to delete last character (Apple iOS Calculator signature gesture)
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { value in
                        if abs(value.translation.width) > 30 {
                            SoundAndHapticManager.shared.triggerHaptic(.light)
                            SoundAndHapticManager.shared.playKeySound()
                            viewModel.deleteBackward()
                        }
                    }
            )
            // Gesture: Long press to copy result
            .onLongPressGesture {
                #if os(iOS)
                UIPasteboard.general.string = viewModel.displayResult
                #endif
                SoundAndHapticManager.shared.triggerHaptic(.medium)
                withAnimation {
                    showCopiedHUD = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        showCopiedHUD = false
                    }
                }
            }
            
            // Live Speculative Preview
            HStack {
                Spacer()
                if let preview = viewModel.livePreview, preview != viewModel.displayResult {
                    HStack(spacing: 4) {
                        Text("=")
                            .foregroundColor(.cyan.opacity(0.6))
                        Text(preview)
                            .foregroundColor(.cyan)
                    }
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.cyan.opacity(0.12))
                            .overlay(Capsule().stroke(Color.cyan.opacity(0.3), lineWidth: 0.8))
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 24)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(white: 0.12, opacity: 0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 12)
        .onChange(of: viewModel.shouldShakeDisplay) { _, newValue in
            if newValue {
                SoundAndHapticManager.shared.triggerHaptic(.error)
                withAnimation(.linear(duration: 0.4)) {
                    shakeAmount = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
