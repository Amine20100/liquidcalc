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
                HStack(spacing: 4) {
                    ForEach(CalculatorMode.allCases) { mode in
                        Button(action: {
                            SoundAndHapticManager.shared.triggerHaptic(.selection)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedMode = mode
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: mode.iconName)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(mode.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(selectedMode == mode ? .white : .white.opacity(0.6))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background {
                                if selectedMode == mode {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.cyan.opacity(0.4), Color.blue.opacity(0.5)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.1)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                        .shadow(color: Color.cyan.opacity(0.45), radius: 8, x: 0, y: 2)
                                        .matchedGeometryEffect(id: "ActiveModePill", in: modeAnimation)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .id(mode)
                    }
                }
                .padding(4)
            }
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
            )
            .onChange(of: selectedMode) { _, newMode in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    proxy.scrollTo(newMode, anchor: .center)
                }
            }
        }
    }
}
