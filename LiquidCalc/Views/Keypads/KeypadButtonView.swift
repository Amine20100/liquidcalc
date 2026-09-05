//
//  KeypadButtonView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct KeypadButtonView: View {
    public let button: KeypadButton
    public let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var isPressed = false
    @State private var tapPulse = false
    @State private var sheenOffset: CGFloat = -140
    @State private var glowWaveScale: CGFloat = 0.9
    @State private var glowWaveOpacity: Double = 0.0
    
    public init(button: KeypadButton, action: @escaping () -> Void) {
        self.button = button
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            // Sound and Haptic feedback
            switch button.type {
            case .equals:
                SoundAndHapticManager.shared.triggerHaptic(.heavy)
                SoundAndHapticManager.shared.playOperationSound()
            case .operation, .bitwise, .scientific:
                SoundAndHapticManager.shared.triggerHaptic(.medium)
                SoundAndHapticManager.shared.playOperationSound()
            default:
                SoundAndHapticManager.shared.triggerHaptic(.light)
                SoundAndHapticManager.shared.playKeySound()
            }
            if !reduceMotion {
                sheenOffset = -140
                glowWaveScale = 0.9
                glowWaveOpacity = 0.8
                withAnimation(.easeOut(duration: 0.12)) {
                    tapPulse = true
                    glowWaveScale = 1.36
                }
                withAnimation(.easeInOut(duration: 0.36)) {
                    sheenOffset = 140
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    withAnimation(.easeOut(duration: 0.20)) {
                        tapPulse = false
                        glowWaveOpacity = 0.0
                    }
                }
            }
            action()
        }) {
            ZStack {
                // Tactile Glow Pulse Wave (expanding radial aura on tap)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        RadialGradient(
                            colors: [glowColor.opacity(0.85), glowColor.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 2,
                            endRadius: 55
                        ),
                        lineWidth: 2.0
                    )
                    .scaleEffect(glowWaveScale)
                    .opacity(glowWaveOpacity)
                    .allowsHitTesting(false)
                
                // A short afterglow confirms a completed tap, separate from the
                // finger-down state so rapid calculations still feel responsive.
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(glowColor.opacity(tapPulse ? 0.58 : 0), lineWidth: 1.5)
                    .scaleEffect(tapPulse ? 1.13 : 1.0)
                    .opacity(tapPulse ? 1 : 0)
                // Ambient Contact Glow Halo Burst (Evaluated only during active touch)
                if isPressed {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    glowColor.opacity(0.40),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 5,
                                endRadius: 40
                            )
                        )
                        .scaleEffect(1.15)
                        .transition(.opacity)
                }
                
                // Background Glass Fill with Specular Gradient
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: button.accentStyle.backgroundColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        // Specular Sheen Highlight Border
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(isPressed ? 0.80 : 0.28), location: 0.0),
                                        .init(color: glowColor.opacity(isPressed ? 0.50 : 0.08), location: 0.5),
                                        .init(color: Color.white.opacity(isPressed ? 0.20 : 0.04), location: 1.0)
                                    ],
                                    startPoint: isPressed ? .topTrailing : .topLeading,
                                    endPoint: isPressed ? .bottomLeading : .bottomTrailing
                                ),
                                lineWidth: isPressed ? 1.4 : 0.8
                            )
                    )
                    .shadow(
                        color: isPressed ? glowColor.opacity(0.45) : Color.black.opacity(0.18),
                        radius: isPressed ? 8 : 2,
                        x: 0,
                        y: isPressed ? 1 : 2
                    )
                
                // Specular Sheen Glint Sweep Across Frosted Glass
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: Color.white.opacity(0.12), location: 0.38),
                        .init(color: Color.white.opacity(0.60), location: 0.50),
                        .init(color: Color.white.opacity(0.12), location: 0.62),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(24))
                .offset(x: sheenOffset)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .allowsHitTesting(false)
                
                // Label Content with interactive spring pop
                VStack(spacing: 2) {
                    if let secondary = button.secondaryLabel {
                        Text(secondary)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(isPressed ? 0.70 : 0.45))
                    }
                    
                    CalcIconView(
                        label: button.label,
                        type: button.type,
                        foregroundColor: button.accentStyle.foregroundColor,
                        isPressed: isPressed,
                        size: fontSizeForLabel
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .offset(y: isPressed ? 2.5 : 0.0)
            .animation(reduceMotion ? .default : .spring(response: 0.20, dampingFraction: 0.54), value: isPressed)
        }
        .buttonStyle(KeypadPressStyle(isPressed: $isPressed))
    }
    
    private var glowColor: Color {
        switch button.type {
        case .equals:
            return Color.cyan
        case .operation, .bitwise:
            return Color.orange
        case .clear, .delete:
            return Color.red
        case .scientific:
            return Color.indigo
        default:
            return Color.white
        }
    }
    
    private var fontSizeForLabel: CGFloat {
        if button.label.count > 4 { return 15 }
        if button.label.count > 2 { return 18 }
        return 24
    }
}

public struct KeypadPressStyle: ButtonStyle {
    @Binding private var isPressedBinding: Bool
    private let hasBinding: Bool
    
    public init(isPressed: Binding<Bool>) {
        self._isPressedBinding = isPressed
        self.hasBinding = true
    }
    
    public init() {
        self._isPressedBinding = .constant(false)
        self.hasBinding = false
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.54), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if hasBinding {
                    isPressedBinding = newValue
                }
            }
    }
}
