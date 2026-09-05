//
//  LiquidGlassBackground.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  High-Performance Ultra-Low GPU / Zero-Lag Liquid Glass Background
//

import SwiftUI

/// Shared visual vocabulary for the student workspace. Components use semantic
/// roles instead of inventing screen-specific shades and corner radii.
public enum LiquidTheme {
    public static let canvas = Color(red: 0.04, green: 0.05, blue: 0.08)
    public static let surface = Color.white.opacity(0.07)
    public static let elevatedSurface = Color.white.opacity(0.11)
    public static let primary = Color.cyan
    public static let secondary = Color.indigo
    public static let primaryText = Color.white
    public static let secondaryText = Color.white.opacity(0.62)
    public static let border = Color.white.opacity(0.13)
    public static let cornerRadius: CGFloat = 18
    public static let compactRadius: CGFloat = 12
    public static let minimumTouchTarget: CGFloat = 44
}

public struct LiquidSurface<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        content
            .background(LiquidTheme.surface, in: RoundedRectangle(cornerRadius: LiquidTheme.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: LiquidTheme.cornerRadius, style: .continuous).stroke(LiquidTheme.border, lineWidth: 1))
    }
}

public struct LiquidSectionHeader: View {
    public let title: String
    public let detail: String?
    public init(_ title: String, detail: String? = nil) { self.title = title; self.detail = detail }
    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(LiquidTheme.primaryText)
            if let detail { Text(detail).font(.system(size: 11, weight: .medium)).foregroundStyle(LiquidTheme.secondaryText) }
        }
    }
}

public struct LiquidEmptyState: View {
    public let icon: String
    public let title: String
    public let detail: String
    public init(icon: String, title: String, detail: String) { self.icon = icon; self.title = title; self.detail = detail }
    public var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 34, weight: .light)).foregroundStyle(LiquidTheme.primary.opacity(0.8))
            Text(title).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(LiquidTheme.primaryText)
            Text(detail).font(.system(size: 12)).multilineTextAlignment(.center).foregroundStyle(LiquidTheme.secondaryText)
        }
        .padding(24).frame(maxWidth: .infinity)
    }
}

public struct LiquidActionButton: View {
    public enum Tone { case primary, secondary, destructive }
    private let title: String
    private let icon: String
    private let tone: Tone
    private let action: () -> Void
    public init(_ title: String, icon: String, tone: Tone = .primary, action: @escaping () -> Void) { self.title = title; self.icon = icon; self.tone = tone; self.action = action }
    public var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 12, weight: .bold)).frame(maxWidth: .infinity, minHeight: LiquidTheme.minimumTouchTarget)
        }
        .foregroundStyle(tone == .primary ? .black : tone == .destructive ? .red : LiquidTheme.primary)
        .background(background, in: RoundedRectangle(cornerRadius: LiquidTheme.compactRadius, style: .continuous))
        .accessibilityLabel(title)
    }
    private var background: Color { switch tone { case .primary: return LiquidTheme.primary; case .secondary: return LiquidTheme.primary.opacity(0.12); case .destructive: return Color.red.opacity(0.13) } }
}

public struct LiquidGlassBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDrifting = false
    @State private var isBreathing = false
    @State private var reflectionDrift = false

    public init() {}
    
    public var body: some View {
        ZStack {
            // Deep OLED Canvas Base
            LiquidTheme.canvas
                .ignoresSafeArea()
            
            // High-Performance Metal-Accelerated Ambient Glow Mesh
            // Uses pure analytical RadialGradients with soft alpha falloffs (0% GPU blur kernel overhead)
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                
                ZStack {
                    // Accent 1: Electric Cyan Glow (Top-Left)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.26),
                                    Color(red: 0.0, green: 0.50, blue: 0.90).opacity(0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 220
                            )
                        )
                        .frame(width: 440, height: 440)
                        .position(x: w * 0.15, y: h * 0.12)
                        .offset(x: isDrifting ? 22 : -16, y: isDrifting ? 14 : -12)
                        .scaleEffect(isBreathing ? 1.07 : 0.94)
                        .opacity(isBreathing ? 1.0 : 0.85)
                    
                    // Accent 2: Vibrant Indigo / Purple Glow (Center-Right)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.50, green: 0.20, blue: 0.95).opacity(0.24),
                                    Color(red: 0.35, green: 0.10, blue: 0.70).opacity(0.07),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 260
                            )
                        )
                        .frame(width: 520, height: 520)
                        .position(x: w * 0.85, y: h * 0.42)
                        .offset(x: isDrifting ? -24 : 18, y: isDrifting ? -18 : 14)
                        .scaleEffect(isBreathing ? 0.94 : 1.07)
                        .opacity(isBreathing ? 0.85 : 1.0)
                    
                    // Accent 3: Emerald Mint Glow (Bottom-Left)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.0, green: 0.95, blue: 0.60).opacity(0.18),
                                    Color(red: 0.0, green: 0.60, blue: 0.50).opacity(0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .position(x: w * 0.10, y: h * 0.78)
                        .offset(x: isDrifting ? 16 : -14, y: isDrifting ? -20 : 16)
                        .scaleEffect(isBreathing ? 1.06 : 0.93)
                        .opacity(isBreathing ? 1.0 : 0.82)
                    
                    // Accent 4: Subtle Warm Amber Glow (Bottom-Right)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.40, blue: 0.20).opacity(0.15),
                                    Color(red: 0.80, green: 0.25, blue: 0.15).opacity(0.04),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .frame(width: 360, height: 360)
                        .position(x: w * 0.80, y: h * 0.82)
                        .offset(x: isDrifting ? -14 : 18, y: isDrifting ? 16 : -14)
                        .scaleEffect(isBreathing ? 0.95 : 1.08)
                        .opacity(isBreathing ? 0.85 : 1.0)
                }
                .animation(
                    reduceMotion ? .default : .easeInOut(duration: 8.5).repeatForever(autoreverses: true),
                    value: isDrifting
                )
                .animation(
                    reduceMotion ? .default : .easeInOut(duration: 6.8).repeatForever(autoreverses: true),
                    value: isBreathing
                )
            }
            .drawingGroup() // Metal hardware accelerated rasterization
            .ignoresSafeArea()
            
            // Breathing Glass Reflections & Prismatic Caustics Layer
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                
                ZStack {
                    // Specular Reflection Caustic Beam 1 (Primary Cyan/White diagonal sweep)
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color.white.opacity(0.02), location: 0.38),
                            .init(color: Color.cyan.opacity(0.07), location: 0.50),
                            .init(color: Color.white.opacity(0.03), location: 0.62),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: max(w * 1.5, 500), height: 180)
                    .rotationEffect(.degrees(-32))
                    .position(x: w * 0.45, y: h * 0.38)
                    .offset(x: reflectionDrift ? 40 : -35, y: reflectionDrift ? -25 : 25)
                    .opacity(isBreathing ? 0.95 : 0.35)
                    .animation(
                        reduceMotion ? .default : .easeInOut(duration: 6.2).repeatForever(autoreverses: true),
                        value: isBreathing
                    )
                    
                    // Specular Reflection Caustic Beam 2 (Secondary Indigo/Magenta refraction)
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color.white.opacity(0.015), location: 0.42),
                            .init(color: Color(red: 0.6, green: 0.3, blue: 1.0).opacity(0.05), location: 0.50),
                            .init(color: Color.white.opacity(0.02), location: 0.58),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                    .frame(width: max(w * 1.4, 450), height: 210)
                    .rotationEffect(.degrees(26))
                    .position(x: w * 0.55, y: h * 0.65)
                    .offset(x: reflectionDrift ? -35 : 35, y: reflectionDrift ? 30 : -30)
                    .opacity(isBreathing ? 0.40 : 0.85)
                    .animation(
                        reduceMotion ? .default : .easeInOut(duration: 7.8).repeatForever(autoreverses: true),
                        value: isBreathing
                    )
                }
                .animation(
                    reduceMotion ? .default : .easeInOut(duration: 9.5).repeatForever(autoreverses: true),
                    value: reflectionDrift
                )
            }
            .drawingGroup()
            .ignoresSafeArea()
            
            // Specular Frosted Glass Vignette & Tint (Zero real-time blur kernel convolution)
            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.38),
                    Color.black.opacity(0.62)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .onAppear {
            guard !reduceMotion else { return }
            isDrifting = true
            isBreathing = true
            reflectionDrift = true
        }
        .onChange(of: reduceMotion) { _, shouldReduceMotion in
            isDrifting = !shouldReduceMotion
            isBreathing = !shouldReduceMotion
            reflectionDrift = !shouldReduceMotion
        }
    }
}
