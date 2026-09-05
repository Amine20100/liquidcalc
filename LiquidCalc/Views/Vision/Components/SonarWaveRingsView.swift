//
//  SonarWaveRingsView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Hardware-Accelerated Sonar Radar Rings (Zero Lag)
//

import SwiftUI

public struct SonarWaveRingsView: View {
    public let isScanning: Bool
    public let ringCount: Int
    
    @State private var wavePhase: CGFloat = 0.0
    @State private var radarRotation: Double = 0.0
    
    public init(isScanning: Bool = true, ringCount: Int = 3) {
        self.isScanning = isScanning
        self.ringCount = max(1, ringCount)
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let maxRadius = min(width, height) * 0.46
            let center = CGPoint(x: width / 2, y: height / 2)
            
            ZStack {
                if isScanning {
                    // 1. 360-Degree Rotating Holographic Radar Sweep Beam
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [
                                    Color.cyan.opacity(0.28),
                                    Color.cyan.opacity(0.10),
                                    Color.clear,
                                    Color.clear
                                ],
                                center: .center
                            )
                        )
                        .frame(width: maxRadius * 2, height: maxRadius * 2)
                        .position(center)
                        .rotationEffect(.degrees(radarRotation))
                    
                    // 2. Concentric Expanding Sonar Wave Rings
                    ForEach(0..<ringCount, id: \.self) { idx in
                        let offset = CGFloat(idx) / CGFloat(ringCount)
                        let ringPhase = (wavePhase + offset).truncatingRemainder(dividingBy: 1.0)
                        let ringDiameter = maxRadius * 2 * ringPhase
                        let ringAlpha = Double(1.0 - ringPhase) * 0.70
                        
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.cyan.opacity(ringAlpha),
                                        Color(red: 0.0, green: 1.0, blue: 0.64).opacity(ringAlpha * 0.8),
                                        Color.cyan.opacity(ringAlpha * 0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: max(1.2, 2.8 * (1.0 - ringPhase))
                            )
                            .frame(width: max(ringDiameter, 4), height: max(ringDiameter, 4))
                            .position(center)
                            .shadow(color: Color.cyan.opacity(ringAlpha * 0.5), radius: 4)
                        
                        // Particle Radar Blips along the wave front
                        let blipAngle1 = Double(idx * 72) * .pi / 180.0
                        let blipAngle2 = Double(idx * 72 + 135) * .pi / 180.0
                        let r = (ringDiameter / 2)
                        
                        Circle()
                            .fill(Color.white.opacity(ringAlpha))
                            .frame(width: 3.5, height: 3.5)
                            .position(x: center.x + cos(blipAngle1) * r, y: center.y + sin(blipAngle1) * r)
                            .shadow(color: Color.cyan, radius: 4)
                        
                        Circle()
                            .fill(Color.cyan.opacity(ringAlpha))
                            .frame(width: 3.0, height: 3.0)
                            .position(x: center.x + cos(blipAngle2) * r, y: center.y + sin(blipAngle2) * r)
                    }
                }
                
                // 3. Central Beacon Core
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .position(center)
                
                Circle()
                    .stroke(Color.cyan.opacity(0.85), lineWidth: 1.5)
                    .frame(width: 14, height: 14)
                    .position(center)
                    .scaleEffect(isScanning ? 1.25 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isScanning)
            }
            .drawingGroup() // Metal GPU rendering
            .opacity(isScanning ? 1.0 : 0.0)
        }
        .onAppear {
            if isScanning {
                startAnimation()
            }
        }
        .onChange(of: isScanning) { _, newValue in
            if newValue {
                startAnimation()
            }
        }
    }
    
    private func startAnimation() {
        wavePhase = 0.0
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            wavePhase = 1.0
        }
        
        radarRotation = 0.0
        withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
            radarRotation = 360.0
        }
    }
}
