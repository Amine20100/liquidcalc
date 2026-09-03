//
//  LiquidGlassBackground.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  High-Performance Ultra-Low GPU / Zero-Lag Liquid Glass Background
//

import SwiftUI

public struct LiquidGlassBackground: View {
    public init() {}
    
    public var body: some View {
        ZStack {
            // Deep OLED Canvas Base
            Color(red: 0.04, green: 0.05, blue: 0.08)
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
                }
            }
            .drawingGroup() // Metal hardware accelerated rasterization
            .ignoresSafeArea()
            
            // Specular Frosted Glass Vignette & Tint (Zero real-time blur kernel convolution)
            LinearGradient(
                colors: [
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.40),
                    Color.black.opacity(0.65)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}
