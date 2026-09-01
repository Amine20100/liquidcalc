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
    
    @State private var isPressed = false
    
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
            action()
        }) {
            ZStack {
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
                        // Top-left specular sheen highlight border
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isPressed ? 0.65 : 0.35),
                                        Color.white.opacity(isPressed ? 0.20 : 0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isPressed ? 1.5 : 1.0
                            )
                    )
                    .shadow(
                        color: isPressed ? Color.cyan.opacity(0.55) : Color.black.opacity(0.25),
                        radius: isPressed ? 12 : 4,
                        x: 0,
                        y: isPressed ? 1 : 4
                    )
                
                // Label Content
                VStack(spacing: 2) {
                    if let secondary = button.secondaryLabel {
                        Text(secondary)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    
                    Text(button.label)
                        .font(.system(size: fontSizeForLabel, weight: .regular, design: .rounded))
                        .foregroundColor(button.accentStyle.foregroundColor)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: isPressed)
        }
        .buttonStyle(KeypadPressStyle(isPressed: $isPressed))
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
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if hasBinding {
                    isPressedBinding = newValue
                }
            }
    }
}
