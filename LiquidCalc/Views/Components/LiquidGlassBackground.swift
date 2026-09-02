//
//  LiquidGlassBackground.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct LiquidGlassBackground: View {
    @State private var phaseA = false
    @State private var phaseB = false
    @State private var phaseC = false
    @State private var shimmerPhase = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Deep OLED Canvas Base
            Color(red: 0.04, green: 0.05, blue: 0.08)
                .ignoresSafeArea()
            
            // Living Fluid Color Mesh
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                
                ZStack {
                    // Blob 1: Electric Cyan (Top-left orbit)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.0, green: 0.90, blue: 1.0).opacity(0.38),
                                    Color.cyan.opacity(0.12),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 240
                            )
                        )
                        .frame(width: 380, height: 380)
                        .scaleEffect(phaseA ? 1.15 : 0.88)
                        .offset(
                            x: phaseA ? -40 : 50,
                            y: phaseB ? -100 : -20
                        )
                        .blur(radius: 48)
                    
                    // Blob 2: Vibrant Indigo / Purple (Center-right orbit)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.55, green: 0.25, blue: 1.0).opacity(0.35),
                                    Color.purple.opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 15,
                                endRadius: 290
                            )
                        )
                        .frame(width: 440, height: 440)
                        .scaleEffect(phaseB ? 0.90 : 1.18)
                        .offset(
                            x: phaseB ? w * 0.35 : w * 0.15,
                            y: phaseA ? h * 0.25 : h * 0.45
                        )
                        .blur(radius: 56)
                    
                    // Blob 3: Emerald Mint Glow (Bottom-left orbit)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.25),
                                    Color.teal.opacity(0.10),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 210
                            )
                        )
                        .frame(width: 320, height: 320)
                        .scaleEffect(phaseC ? 1.20 : 0.85)
                        .offset(
                            x: phaseC ? -20 : 60,
                            y: phaseC ? h * 0.55 : h * 0.72
                        )
                        .blur(radius: 44)
                    
                    // Blob 4: Warm Deep Amber / Rose (Bottom-right accent)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.42, blue: 0.25).opacity(0.22),
                                    Color.orange.opacity(0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 220
                            )
                        )
                        .frame(width: 300, height: 300)
                        .scaleEffect(phaseA ? 0.88 : 1.12)
                        .offset(
                            x: phaseB ? w * 0.25 : w * 0.40,
                            y: phaseC ? h * 0.75 : h * 0.60
                        )
                        .blur(radius: 50)
                }
            }
            .ignoresSafeArea()
            
            // Specular Shimmer Diagonal Light Beam
            LinearGradient(
                colors: [
                    Color.white.opacity(shimmerPhase ? 0.03 : 0.005),
                    Color.cyan.opacity(shimmerPhase ? 0.05 : 0.01),
                    Color.clear
                ],
                startPoint: shimmerPhase ? .topLeading : .bottomLeading,
                endPoint: shimmerPhase ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 9.0).repeatForever(autoreverses: true), value: shimmerPhase)
            
            // Ultra-thin Frosted Material Overlay
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.62))
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 7.0).repeatForever(autoreverses: true)) {
                phaseA = true
            }
            withAnimation(.easeInOut(duration: 10.5).repeatForever(autoreverses: true)) {
                phaseB = true
            }
            withAnimation(.easeInOut(duration: 8.2).repeatForever(autoreverses: true)) {
                phaseC = true
            }
            withAnimation(.easeInOut(duration: 9.0).repeatForever(autoreverses: true)) {
                shimmerPhase = true
            }
        }
    }
}
