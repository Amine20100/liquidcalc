//
//  LaserSweepLineView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Hardware-Accelerated Fluid Laser Sweep Line (Zero Lag)
//

import SwiftUI

public struct LaserSweepLineView: View {
    public let isScanning: Bool
    
    @State private var sweepPhase: CGFloat = 0.0 // 0.0 (top) to 1.0 (bottom)
    
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
                // 1. Trailing Optical Curtain (Holographic phosphor gradient)
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: Color.cyan.opacity(0.12), location: 0.5),
                        .init(color: Color.cyan.opacity(0.35), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: max(width - 24, 20), height: 36)
                .position(x: width / 2, y: currentY - 18)
                
                // 2. Neon Glow Beam (Hardware-rendered gradient beam)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.cyan.opacity(0.7),
                                Color.white,
                                Color.cyan.opacity(0.7),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(width - 20, 20), height: 3)
                    .position(x: width / 2, y: currentY)
                
                // 3. Center Specular Flare Burst
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .position(x: width / 2, y: currentY)
            }
            .drawingGroup() // 100% Metal GPU accelerated
            .opacity(isScanning ? 1.0 : 0.0)
        }
        .onAppear {
            if isScanning {
                startSweep()
            }
        }
        .onChange(of: isScanning) { _, newValue in
            if newValue {
                startSweep()
            }
        }
    }
    
    private func startSweep() {
        sweepPhase = 0.0
        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            sweepPhase = 1.0
        }
    }
}
