//
//  LaserSweepLineView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Milestone M2: Feature F5 - Animated Scanning Laser Line
//

import SwiftUI

/// A multi-layer holographic laser beam that smoothly traverses the viewfinder while scanning is active.
/// Visual hierarchy:
/// 1. Core bright laser filament (1.5pt ultra-bright white/cyan beam with soft horizontal edge taper).
/// 2. Neon cyan glow beam (6pt cyan line with intense drop shadow).
/// 3. Trailing gradient optical curtain (45pt vertical gradient trail simulating holographic phosphor persistence).
/// 4. Center specular energy flare.
public struct LaserSweepLineView: View {
    public let isScanning: Bool
    
    @State private var sweepPhase: CGFloat = 0.0 // 0.0 (top) to 1.0 (bottom)
    @State private var pulseIntensity: CGFloat = 0.85
    
    public init(isScanning: Bool = true) {
        self.isScanning = isScanning
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let verticalRange = max(height - 40, 60)
            let currentY = 20 + (sweepPhase * verticalRange)
            
            ZStack(alignment: .top) {
                // 1. Trailing Optical Curtain (Holographic Phosphor Trail)
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.08), location: 0.4),
                        .init(color: Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.28), location: 0.85),
                        .init(color: Color(red: 0.3, green: 1.0, blue: 1.0).opacity(0.45), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: max(width - 32, 20), height: 48)
                .mask(
                    // Horizontal taper so the curtain doesn't touch hard edges
                    LinearGradient(
                        colors: [.clear, .white, .white, .white, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .position(x: width / 2, y: currentY - 24)
                
                // 2. Wide Neon Glow Beam
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.6),
                                Color(red: 0.0, green: 1.0, blue: 1.0).opacity(0.9),
                                Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.6),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(width - 24, 20), height: 5)
                    .shadow(color: Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.9), radius: 10, x: 0, y: 0)
                    .shadow(color: Color.cyan.opacity(0.6), radius: 18, x: 0, y: 0)
                    .position(x: width / 2, y: currentY)
                
                // 3. Core Bright Laser Filament (Ultra-bright white center)
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: Color.cyan.opacity(0.5), location: 0.1),
                                .init(color: .white, location: 0.4),
                                .init(color: .white, location: 0.6),
                                .init(color: Color.cyan.opacity(0.5), location: 0.9),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(width - 36, 20), height: 2)
                    .position(x: width / 2, y: currentY)
                
                // 4. Center Specular Flare Burst
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white,
                                Color(red: 0.0, green: 1.0, blue: 1.0).opacity(0.8),
                                Color.cyan.opacity(0.2),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 28
                        )
                    )
                    .frame(width: 56, height: 12)
                    .scaleEffect(pulseIntensity)
                    .position(x: width / 2, y: currentY)
            }
            .opacity(isScanning ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.25), value: isScanning)
        }
        .onAppear {
            startSweepAnimation()
        }
        .onChange(of: isScanning) { _, newValue in
            if newValue {
                startSweepAnimation()
            }
        }
    }
    
    private func startSweepAnimation() {
        guard isScanning else { return }
        sweepPhase = 0.0
        withAnimation(
            .easeInOut(duration: 1.35)
            .repeatForever(autoreverses: true)
        ) {
            sweepPhase = 1.0
        }
        
        withAnimation(
            .easeInOut(duration: 0.6)
            .repeatForever(autoreverses: true)
        ) {
            pulseIntensity = 1.2
        }
    }
}
