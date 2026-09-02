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
    
    @State private var phase: CGFloat = 0.0
    
    public init(isScanning: Bool = true) {
        self.isScanning = isScanning
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let maxRadius = min(width, height) * 0.45
            let center = CGPoint(x: width / 2, y: height / 2)
            
            ZStack {
                if isScanning {
                    // Ring 1
                    Circle()
                        .stroke(Color.cyan.opacity(Double(1.0 - phase) * 0.6), lineWidth: 2)
                        .frame(width: maxRadius * 2 * phase, height: maxRadius * 2 * phase)
                        .position(center)
                    
                    // Ring 2 (delayed)
                    let phase2 = (phase + 0.5).truncatingRemainder(dividingBy: 1.0)
                    Circle()
                        .stroke(Color.cyan.opacity(Double(1.0 - phase2) * 0.5), lineWidth: 1.5)
                        .frame(width: maxRadius * 2 * phase2, height: maxRadius * 2 * phase2)
                        .position(center)
                }
                
                // Central Beacon Core
                Circle()
                    .fill(Color.cyan.opacity(0.8))
                    .frame(width: 8, height: 8)
                    .position(center)
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
        phase = 0.0
        withAnimation(
            .linear(duration: 1.8)
            .repeatForever(autoreverses: false)
        ) {
            phase = 1.0
        }
    }
}
