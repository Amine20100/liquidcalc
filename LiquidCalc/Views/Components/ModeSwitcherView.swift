//
//  ModeSwitcherView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct ModeSwitcherView: View {
    @Binding var selectedMode: CalculatorMode
    @Namespace private var modeAnimation
    
    public init(selectedMode: Binding<CalculatorMode>) {
        self._selectedMode = selectedMode
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(CalculatorMode.allCases) { mode in
                        ModePillButton(
                            mode: mode,
                            isSelected: selectedMode == mode,
                            modeAnimation: modeAnimation,
                            action: {
                                SoundAndHapticManager.shared.triggerHaptic(.selection)
                                withAnimation(.spring(response: 0.30, dampingFraction: 0.70)) {
                                    selectedMode = mode
                                }
                            }
                        )
                        .id(mode)
                    }
                }
                .padding(5)
            }
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.9
                            )
                    )
            )
            .onChange(of: selectedMode) { _, newMode in
                withAnimation(.spring(response: 0.30, dampingFraction: 0.70)) {
                    proxy.scrollTo(newMode, anchor: .center)
                }
            }
        }
    }
}

private struct ModePillButton: View {
    let mode: CalculatorMode
    let isSelected: Bool
    let modeAnimation: Namespace.ID
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                    .symbolEffect(.bounce, value: isSelected)
                
                Text(mode.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.55))
            .padding(.vertical, 8)
            .padding(.horizontal, 13)
            .background {
                if isSelected {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(0.45),
                                    Color.blue.opacity(0.55),
                                    Color.indigo.opacity(0.40)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color.white.opacity(0.70), location: 0.0),
                                            .init(color: Color.cyan.opacity(0.50), location: 0.5),
                                            .init(color: Color.white.opacity(0.15), location: 1.0)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )
                        .shadow(color: Color.cyan.opacity(0.55), radius: 10, x: 0, y: 2)
                        .shadow(color: Color.blue.opacity(0.35), radius: 18, x: 0, y: 4)
                        .matchedGeometryEffect(id: "ActiveModePill", in: modeAnimation)
                }
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.60), value: isPressed)
        }
        .buttonStyle(ModeItemPressStyle(isPressed: $isPressed))
    }
}

private struct ModeItemPressStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                isPressed = pressed
            }
    }
}
