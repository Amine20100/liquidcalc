//
//  ReticleOverlayView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Milestone M2: Feature F6 - Animated Pulsing & Locking Reticle
//

import SwiftUI

/// State-driven corner brackets reticle overlay for the Smart Vision viewfinder.
///
/// States:
/// - **Idle State**: Subtle ambient breathing animation (scale, opacity, and soft cyan glow).
/// - **Scanning State**: Rapid inward pulsing / focus cycle with energized bright cyan stroke.
/// - **Lock-On State**: Spring snap to detected equation/receipt text bounding frame with neon green/cyan (#00FFA3) color shift, corner accent dots, and radiant glow.
public struct ReticleOverlayView: View {
    public let isScanning: Bool
    public let hasTarget: Bool
    public let targetBoundingBox: CGRect?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // Animation States
    @State private var idleBreathingPhase: CGFloat = 0.0
    @State private var scanPulsePhase: CGFloat = 0.0
    @State private var lockOnPulsePhase: CGFloat = 0.0
    
    public init(
        isScanning: Bool = false,
        hasTarget: Bool = false,
        targetBoundingBox: CGRect? = nil
    ) {
        self.isScanning = isScanning
        self.hasTarget = hasTarget
        self.targetBoundingBox = targetBoundingBox
    }
    
    public init(isScanning: Bool, isLocked: Bool) {
        self.isScanning = isScanning
        self.hasTarget = isLocked
        self.targetBoundingBox = nil
    }
    
    // MARK: - Color Palette
    private var primaryColor: Color {
        if hasTarget {
            // Neon Green / Cyan Lock-On Shift (#00FFA3)
            return Color(red: 0.0, green: 1.0, blue: 0.64)
        } else if isScanning {
            // Energized Electric Cyan
            return Color(red: 0.0, green: 0.95, blue: 1.0)
        } else {
            // Ambient Cyan
            return Color(red: 0.0, green: 0.82, blue: 0.95)
        }
    }
    
    private var glowRadius: CGFloat {
        if hasTarget {
            return 12.0 + (lockOnPulsePhase * 4.0)
        } else if isScanning {
            return 8.0 + (scanPulsePhase * 6.0)
        } else {
            return 4.0 + (idleBreathingPhase * 4.0)
        }
    }
    
    private var currentOpacity: Double {
        if hasTarget {
            return 1.0
        } else if isScanning {
            return 0.88 + Double(scanPulsePhase * 0.12)
        } else {
            return 0.75 + Double(idleBreathingPhase * 0.20)
        }
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let fullWidth = geometry.size.width
            let fullHeight = geometry.size.height
            
            // Calculate active framing rect
            let targetRect = calculateTargetRect(containerWidth: fullWidth, containerHeight: fullHeight)
            
            ZStack {
                // Four Corner Brackets
                ReticleCornerShape(
                    rect: targetRect,
                    cornerLength: hasTarget ? 24 : 20,
                    inset: currentCornerInset
                )
                .stroke(
                    primaryColor,
                    style: StrokeStyle(lineWidth: hasTarget ? 3.5 : 3.0, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: primaryColor.opacity(hasTarget ? 0.85 : 0.6), radius: glowRadius)
                .opacity(currentOpacity)
                
                // Lock-On Corner Accent Dots & Crosshairs (Only shown when locked)
                if hasTarget {
                    LockOnAccentsView(rect: targetRect, inset: currentCornerInset, color: primaryColor)
                        .scaleEffect(1.0 + (lockOnPulsePhase * 0.05))
                        .opacity(0.9)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
                
                // Central Optical Crosshair (Subtle in scanning / idle mode)
                if !hasTarget {
                    CenterCrosshairView(isScanning: isScanning, pulsePhase: scanPulsePhase, color: primaryColor)
                        .position(x: fullWidth / 2, y: fullHeight / 2)
                        .opacity(isScanning ? 0.7 : 0.3)
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.60), value: hasTarget)
            .animation(.easeInOut(duration: 0.3), value: isScanning)
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: isScanning) { _, _ in
            startAnimations()
        }
        .onChange(of: reduceMotion) { _, shouldReduce in
            if shouldReduce {
                idleBreathingPhase = 0.5
                scanPulsePhase = 0.0
                lockOnPulsePhase = 0.5
            } else {
                startAnimations()
            }
        }
        .onChange(of: hasTarget) { _, isLocked in
            if isLocked {
                if !reduceMotion {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.60)) {
                        lockOnPulsePhase = 1.0
                    }
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        lockOnPulsePhase = 0.4
                    }
                } else {
                    lockOnPulsePhase = 0.5
                }
            }
        }
    }
    
    private var currentCornerInset: CGFloat {
        if hasTarget {
            return 12.0
        } else if isScanning {
            // Rapid inward contract
            return 22.0 + (scanPulsePhase * 4.0)
        } else {
            // Subtle ambient breathing expansion
            return 18.0 - (idleBreathingPhase * 2.0)
        }
    }
    
    private func calculateTargetRect(containerWidth: CGFloat, containerHeight: CGFloat) -> CGRect {
        if let box = targetBoundingBox, hasTarget {
            // Apple Vision coordinates: (0,0) is bottom-left, normalized 0..1
            let x = max(box.origin.x * containerWidth - 10, 8)
            let y = max((1.0 - box.origin.y - box.height) * containerHeight - 10, 8)
            let w = min(box.width * containerWidth + 20, containerWidth - 16)
            let h = min(box.height * containerHeight + 20, containerHeight - 16)
            return CGRect(x: x, y: y, width: max(w, 80), height: max(h, 50))
        } else {
            return CGRect(x: 0, y: 0, width: containerWidth, height: containerHeight)
        }
    }
    
    private func startAnimations() {
        guard !reduceMotion else {
            idleBreathingPhase = 0.5
            scanPulsePhase = 0.0
            return
        }
        
        // Idle Ambient Breathing
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            idleBreathingPhase = 1.0
        }
        
        // Active Scanning Pulse
        if isScanning {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                scanPulsePhase = 1.0
            }
        } else {
            scanPulsePhase = 0.0
        }
    }
}

// MARK: - Reticle Corner Shape

private struct ReticleCornerShape: Shape {
    let rect: CGRect
    let cornerLength: CGFloat
    let inset: CGFloat
    
    func path(in rectBounds: CGRect) -> Path {
        var path = Path()
        
        let minX = rect.minX + inset
        let minY = rect.minY + inset
        let maxX = rect.maxX - inset
        let maxY = rect.maxY - inset
        let len = min(cornerLength, min(rect.width, rect.height) / 3)
        
        // Top-Left Corner
        path.move(to: CGPoint(x: minX, y: minY + len))
        path.addLine(to: CGPoint(x: minX, y: minY))
        path.addLine(to: CGPoint(x: minX + len, y: minY))
        
        // Top-Right Corner
        path.move(to: CGPoint(x: maxX - len, y: minY))
        path.addLine(to: CGPoint(x: maxX, y: minY))
        path.addLine(to: CGPoint(x: maxX, y: minY + len))
        
        // Bottom-Right Corner
        path.move(to: CGPoint(x: maxX, y: maxY - len))
        path.addLine(to: CGPoint(x: maxX, y: maxY))
        path.addLine(to: CGPoint(x: maxX - len, y: maxY))
        
        // Bottom-Left Corner
        path.move(to: CGPoint(x: minX + len, y: maxY))
        path.addLine(to: CGPoint(x: minX, y: maxY))
        path.addLine(to: CGPoint(x: minX, y: maxY - len))
        
        return path
    }
}

// MARK: - Lock-On Accents (Target Locked Details)

private struct LockOnAccentsView: View {
    let rect: CGRect
    let inset: CGFloat
    let color: Color
    
    var body: some View {
        let minX = rect.minX + inset
        let minY = rect.minY + inset
        let maxX = rect.maxX - inset
        let maxY = rect.maxY - inset
        
        ZStack {
            // 4 Corner Accent Dots
            Circle().fill(color).frame(width: 5, height: 5).position(x: minX + 2, y: minY + 2)
            Circle().fill(color).frame(width: 5, height: 5).position(x: maxX - 2, y: minY + 2)
            Circle().fill(color).frame(width: 5, height: 5).position(x: maxX - 2, y: maxY - 2)
            Circle().fill(color).frame(width: 5, height: 5).position(x: minX + 2, y: maxY - 2)
            
            // Edge Center Markers
            Capsule().fill(color.opacity(0.8)).frame(width: 14, height: 2).position(x: (minX + maxX) / 2, y: minY)
            Capsule().fill(color.opacity(0.8)).frame(width: 14, height: 2).position(x: (minX + maxX) / 2, y: maxY)
            Capsule().fill(color.opacity(0.8)).frame(width: 2, height: 14).position(x: minX, y: (minY + maxY) / 2)
            Capsule().fill(color.opacity(0.8)).frame(width: 2, height: 14).position(x: maxX, y: (minY + maxY) / 2)
        }
        .shadow(color: color.opacity(0.9), radius: 6)
    }
}

// MARK: - Center Crosshair

private struct CenterCrosshairView: View {
    let isScanning: Bool
    let pulsePhase: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            // Small crosshair ticks
            Rectangle()
                .fill(color.opacity(0.6))
                .frame(width: 16, height: 1.5)
            
            Rectangle()
                .fill(color.opacity(0.6))
                .frame(width: 1.5, height: 16)
            
            // Outer subtle circle
            Circle()
                .stroke(color.opacity(0.35), lineWidth: 1)
                .frame(width: 28, height: 28)
                .scaleEffect(isScanning ? 1.0 + (pulsePhase * 0.15) : 1.0)
        }
    }
}
