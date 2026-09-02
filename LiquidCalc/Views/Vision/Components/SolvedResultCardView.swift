//
//  SolvedResultCardView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Milestone M2: Feature F7 - Solved Result Reveal Card
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// A glowing, spring-animated reveal card displaying OCR-detected math expressions and their evaluated results.
/// Features:
/// - iOS 18 Spring transition with scale, opacity, and vertical offset.
/// - Multi-stop glowing neon accent border (Cyan / Mint / Emerald Green gradient).
/// - Radiant outer glow shadow upon equation detection.
/// - Animated pulsating emerald beacon indicator dot.
/// - Monospace typography with emerald result gradient.
/// - Interactive "Open in Calc" and "Copy" actions with haptic triggers.
public struct SolvedResultCardView: View {
    public let expression: String
    public let result: String?
    public let steps: [String]?
    public let explanation: String?
    public let onOpenInCalc: () -> Void
    public let onCopy: (() -> Void)?
    
    @State private var isCopied: Bool = false
    @State private var beaconPulsing: Bool = false
    @State private var cardScalePop: CGFloat = 0.96
    @State private var borderGlowPhase: CGFloat = 0.0
    
    public init(
        expression: String,
        result: String? = nil,
        steps: [String]? = nil,
        explanation: String? = nil,
        onOpenInCalc: @escaping () -> Void,
        onCopy: (() -> Void)? = nil
    ) {
        self.expression = expression
        self.result = result
        self.steps = steps
        self.explanation = explanation
        self.onOpenInCalc = onOpenInCalc
        self.onCopy = onCopy
    }
    
    // Neon palette
    private let neonCyan = Color(red: 0.0, green: 0.92, blue: 1.0)
    private let neonMint = Color(red: 0.0, green: 1.0, blue: 0.64)
    private let neonGreen = Color(red: 0.2, green: 0.95, blue: 0.45)
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header Bar: "DETECTED" badge with pulsating beacon & action buttons
            HStack(spacing: 8) {
                // Pulsating Detection Beacon
                HStack(spacing: 5) {
                    ZStack {
                        Circle()
                            .fill(neonMint.opacity(0.35))
                            .frame(width: 14, height: 14)
                            .scaleEffect(beaconPulsing ? 1.4 : 0.8)
                            .opacity(beaconPulsing ? 0.2 : 0.8)
                        
                        Circle()
                            .fill(neonMint)
                            .frame(width: 7, height: 7)
                            .shadow(color: neonMint, radius: 4)
                    }
                    
                    Text("DETECTED")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(neonMint)
                        .tracking(1.2)
                }
                
                Spacer()
                
                // Copy Action Button
                Button(action: handleCopy) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                        Text(isCopied ? "Copied" : "Copy")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isCopied ? neonMint : .white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(isCopied ? 0.15 : 0.08))
                    )
                }
                .buttonStyle(.plain)
                
                // "Open in Calc" Interactive Pill Button
                Button(action: onOpenInCalc) {
                    HStack(spacing: 4) {
                        Text("Open in Calc")
                            .font(.system(size: 11, weight: .bold))
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [neonMint, neonCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: neonMint.opacity(0.4), radius: 6)
                }
                .buttonStyle(.plain)
            }
            
            // Expression String
            HStack {
                Text(expression)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer()
            }
            .padding(.top, 2)
            
            // Solved Result Display with Emerald/Mint Gradient
            if let result = result {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Spacer()
                    Text("=")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(neonMint.opacity(0.8))
                    
                    Text(result)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [neonMint, neonGreen, Color.white],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: neonMint.opacity(0.4), radius: 8)
                }
                .scaleEffect(cardScalePop)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            
            // Steps and Explanation (if available)
            if let explanation = explanation, !explanation.isEmpty {
                Divider().background(Color.white.opacity(0.2)).padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    if let steps = steps, !steps.isEmpty {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 6) {
                                Text("\(index + 1).")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(neonCyan.opacity(0.8))
                                Text(step)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.yellow.opacity(0.9))
                            .padding(.top, 2)
                        Text(explanation)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        // Card Background: Frosted Glass + Ambient Glow
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(white: 0.08, opacity: 0.65))
                
                // Specular Sheen Gradient on top edge
                VStack {
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 28)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        )
        // Multi-Stop Glowing Accent Border
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: neonCyan.opacity(0.9), location: 0.0),
                            .init(color: neonMint.opacity(0.95), location: 0.5),
                            .init(color: neonGreen.opacity(0.85), location: 0.8),
                            .init(color: neonCyan.opacity(0.9), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.8
                )
        )
        // Radiant Outer Glow Shadow
        .shadow(color: neonMint.opacity(0.55), radius: 14, x: 0, y: 4)
        .shadow(color: neonCyan.opacity(0.35), radius: 24, x: 0, y: 2)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.70)) {
                cardScalePop = 1.0
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                beaconPulsing = true
            }
        }
    }
    
    private func handleCopy() {
        SoundAndHapticManager.shared.triggerHaptic(.light)
        let copyText = result ?? expression
        
        #if canImport(UIKit)
        UIPasteboard.general.string = copyText
        #endif
        
        if let onCopy = onCopy {
            onCopy()
        }
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            isCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
}
