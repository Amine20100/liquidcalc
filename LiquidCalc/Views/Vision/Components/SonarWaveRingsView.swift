//
//  SonarWaveRingsView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Milestone M2: Feature F2 - Animated Expanding Sonar & Radar Wave Rings
//

import SwiftUI

/// Animated expanding concentric radar/sonar wave rings with pulsating opacity
/// and neon teal/cyan rings when scanning is active.
///
/// Visual hierarchy:
/// 1. Staggered concentric pulse rings expanding outward from the viewfinder center.
/// 2. Dynamic opacity fade-out as rings expand outward to simulate sound/radar wave dissipation.
/// 3. Multi-layered neon teal/cyan glow drop shadows.
/// 4. Central sonar beacon core with pulsating radial energy.
/// 5. Smooth fade transition when scanning is toggled.
public struct SonarWaveRingsView: View {
    public let isScanning: Bool
    public let ringCount: Int
    
    // Neon Teal / Cyan Color Palette
    private let primaryTeal = Color(red: 0.0, green: 0.95, blue: 0.85)
    private let neonCyan = Color(red: 0.0, green: 0.85, blue: 1.0)
    private let deepCyan = Color(red: 0.0, green: 0.55, blue: 0.8)
    
    // Central Beacon Pulse State
    @State private var beaconPulse: CGFloat = 0.85
    @State private var ambientGlow: CGFloat = 0.6
    
    public init(isScanning: Bool = true, ringCount: Int = 3) {
        self.isScanning = isScanning
        self.ringCount = max(1, ringCount)
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let maxRadius = max(min(width, height) * 0.75, 40)
            let centerX = width / 2
            let centerY = height / 2
            
            ZStack {
                // 1. Staggered Concentric Sonar Wave Rings
                if isScanning {
                    ForEach(0..<ringCount, id: \.self) { index in
                        SonarPulseRing(
                            index: index,
                            ringCount: ringCount,
                            maxRadius: maxRadius,
                            primaryTeal: primaryTeal,
                            neonCyan: neonCyan,
                            deepCyan: deepCyan,
                            isScanning: isScanning
                        )
                        .position(x: centerX, y: centerY)
                    }
                }
                
                // 2. Center Sonar Beacon / Core Radar Emitter
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white,
                                primaryTeal.opacity(0.85),
                                neonCyan.opacity(0.35),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 20
                        )
                    )
                    .frame(width: 40, height: 40)
                    .scaleEffect(isScanning ? beaconPulse : 0.65)
                    .opacity(isScanning ? 0.95 : 0.3)
                    .position(x: centerX, y: centerY)
                
                // 3. Ambient Beacon Core Dot
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .shadow(color: primaryTeal, radius: 5)
                    .position(x: centerX, y: centerY)
                    .opacity(isScanning ? 1.0 : 0.4)
            }
            .opacity(isScanning ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.3), value: isScanning)
        }
        .onAppear {
            startBeaconAnimation()
        }
        .onChange(of: isScanning) { _, newValue in
            if newValue {
                startBeaconAnimation()
            }
        }
    }
    
    private func startBeaconAnimation() {
        guard isScanning else { return }
        withAnimation(
            .easeInOut(duration: 0.75)
            .repeatForever(autoreverses: true)
        ) {
            beaconPulse = 1.25
            ambientGlow = 1.0
        }
    }
}

// MARK: - Individual Animated Sonar Pulse Ring

private struct SonarPulseRing: View {
    let index: Int
    let ringCount: Int
    let maxRadius: CGFloat
    let primaryTeal: Color
    let neonCyan: Color
    let deepCyan: Color
    let isScanning: Bool
    
    @State private var phase: CGFloat = 0.0
    
    var body: some View {
        let currentScale = 0.12 + (phase * 0.88)
        let ringOpacity = Double(max(0.0, 1.0 - phase)) * 0.85
        
        Circle()
            .stroke(
                LinearGradient(
                    colors: [
                        primaryTeal.opacity(ringOpacity),
                        neonCyan.opacity(ringOpacity * 0.85),
                        deepCyan.opacity(ringOpacity * 0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(
                    lineWidth: max(1.0, 2.5 * (1.0 - phase * 0.5)),
                    lineCap: .round
                )
            )
            .frame(width: maxRadius * 2, height: maxRadius * 2)
            .scaleEffect(isScanning ? currentScale : 0.12)
            .opacity(isScanning ? ringOpacity : 0.0)
            .shadow(color: primaryTeal.opacity(ringOpacity * 0.7), radius: 8)
            .shadow(color: neonCyan.opacity(ringOpacity * 0.45), radius: 16)
            .onAppear {
                startAnimation()
            }
            .onChange(of: isScanning) { _, newValue in
                if newValue {
                    startAnimation()
                }
            }
    }
    
    private func startAnimation() {
        guard isScanning else { return }
        phase = 0.0
        let delay = Double(index) * (2.2 / Double(max(1, ringCount)))
        withAnimation(
            .linear(duration: 2.2)
            .repeatForever(autoreverses: false)
            .delay(delay)
        ) {
            phase = 1.0
        }
    }
}
