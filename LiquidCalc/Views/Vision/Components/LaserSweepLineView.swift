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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var sweepPhase: CGFloat = 0.0 // 0.0 (top) to 1.0 (bottom)
    @State private var sparkPhase: CGFloat = 0.0
    
    public init(isScanning: Bool = true) {
        self.isScanning = isScanning
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let verticalRange = max(height - 40, 60)
            let currentY = 20 + ((reduceMotion ? 0.5 : sweepPhase) * verticalRange)
            
            ZStack(alignment: .top) {
                // 1. Holographic Phosphor Chromatic Curtain
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: Color(red: 0.4, green: 0.1, blue: 0.9).opacity(0.08), location: 0.4),
                        .init(color: Color.cyan.opacity(0.18), location: 0.75),
                        .init(color: Color(red: 0.0, green: 1.0, blue: 0.8).opacity(0.38), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: max(width - 24, 20), height: 42)
                .position(x: width / 2, y: currentY - 21)
                
                // 2. High-Intensity Laser Beam
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.cyan.opacity(0.6),
                                Color(red: 0.0, green: 1.0, blue: 0.7),
                                Color.white,
                                Color(red: 0.0, green: 1.0, blue: 0.7),
                                Color.cyan.opacity(0.6),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(width - 16, 20), height: 3.5)
                    .position(x: width / 2, y: currentY)
                    .shadow(color: Color.cyan.opacity(0.8), radius: 6)
                
                // 3. Center Specular Flare Burst
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .position(x: width / 2, y: currentY)
                    .shadow(color: .white, radius: 4)
                
                // 4. Shimmering Holographic Spark Particles along Laser Sweep
                if isScanning && !reduceMotion {
                    ForEach(0..<5, id: \.self) { idx in
                        let frac = (CGFloat(idx) * 0.22 + sparkPhase).truncatingRemainder(dividingBy: 1.0)
                        let sparkX = 24 + frac * max(width - 48, 10)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 2.5, height: 2.5)
                            .position(x: sparkX, y: currentY + (idx % 2 == 0 ? -1.5 : 1.5))
                            .opacity(Double(sin(frac * .pi)))
                            .shadow(color: Color.cyan, radius: 3)
                    }
                }
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
        .onChange(of: reduceMotion) { _, shouldReduce in
            if shouldReduce {
                sweepPhase = 0.5
                sparkPhase = 0.0
            } else if isScanning {
                startSweep()
            }
        }
    }
    
    private func startSweep() {
        guard !reduceMotion else {
            sweepPhase = 0.5
            sparkPhase = 0.0
            return
        }
        
        sweepPhase = 0.0
        withAnimation(
            .easeInOut(duration: 1.3)
            .repeatForever(autoreverses: true)
        ) {
            sweepPhase = 1.0
        }
        
        sparkPhase = 0.0
        withAnimation(
            .linear(duration: 2.2)
            .repeatForever(autoreverses: false)
        ) {
            sparkPhase = 1.0
        }
    }
}
