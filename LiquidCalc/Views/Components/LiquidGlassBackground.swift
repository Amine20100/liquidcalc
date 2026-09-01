//
//  LiquidGlassBackground.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct LiquidGlassBackground: View {
    @State private var animateBlobs = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Base dark canvas
            Color(red: 0.05, green: 0.06, blue: 0.09)
                .ignoresSafeArea()
            
            // Fluid glowing background blobs
            GeometryReader { proxy in
                ZStack {
                    // Blob 1: Deep Cyan / Teal
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.cyan.opacity(0.35), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 260
                            )
                        )
                        .frame(width: 380, height: 380)
                        .offset(x: animateBlobs ? -60 : 40, y: animateBlobs ? -120 : -40)
                        .blur(radius: 50)
                    
                    // Blob 2: Vibrant Indigo / Violet
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 300
                            )
                        )
                        .frame(width: 440, height: 440)
                        .offset(x: animateBlobs ? proxy.size.width * 0.4 : proxy.size.width * 0.2,
                                y: animateBlobs ? proxy.size.height * 0.3 : proxy.size.height * 0.5)
                        .blur(radius: 60)
                    
                    // Blob 3: Subtle Warm Amber
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.orange.opacity(0.2), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 200
                            )
                        )
                        .frame(width: 280, height: 280)
                        .offset(x: animateBlobs ? 30 : -40,
                                y: animateBlobs ? proxy.size.height * 0.7 : proxy.size.height * 0.6)
                        .blur(radius: 45)
                }
            }
            .ignoresSafeArea()
            
            // Ultra-thin Frosted Material Overlay
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.6))
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                animateBlobs = true
            }
        }
    }
}
