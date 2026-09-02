//
//  VaultUnlockAnimationView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Cyberpunk Secret Vault Unlock Portal Transition Animation
//

import SwiftUI

public struct VaultUnlockAnimationView: View {
    @State private var outerRingRotation: Double = 0
    @State private var innerRingRotation: Double = 0
    @State private var shockwaveScale: CGFloat = 0.2
    @State private var shockwaveOpacity: Double = 0.9
    @State private var contentScale: CGFloat = 0.6
    @State private var contentOpacity: Double = 0.0
    @State private var scanlineOffset: CGFloat = -120
    @State private var glitchText: String = "DECRYPTING..."
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Dark Frosted Backdrop
            Color(red: 0.03, green: 0.04, blue: 0.06).opacity(0.92)
                .ignoresSafeArea()
            
            // Expanding Neon Shockwave Ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.0, green: 1.0, blue: 0.64),
                            Color.cyan,
                            Color.purple.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 6
                )
                .frame(width: 320, height: 320)
                .scaleEffect(shockwaveScale)
                .opacity(shockwaveOpacity)
                .blur(radius: shockwaveScale > 2.0 ? 12 : 2)
            
            // Cybernetic Vault Iris Reticle
            VStack(spacing: 20) {
                ZStack {
                    // Outer Rotating Segmented Track
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [Color.cyan, Color.clear, Color(red: 0.0, green: 1.0, blue: 0.64), Color.clear],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [18, 10])
                        )
                        .frame(width: 170, height: 170)
                        .rotationEffect(.degrees(outerRingRotation))
                    
                    // Middle Counter-Rotating Gear Ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [Color.purple, Color.clear, Color.cyan, Color.clear],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [10, 8])
                        )
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(-innerRingRotation))
                    
                    // Center Unlocked Shield Icon
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.35), Color.clear],
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 55
                                )
                            )
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "lock.open.trianglebadge.exclamationmark.fill")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.0, green: 1.0, blue: 0.64), Color.cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.8), radius: 14)
                    }
                    
                    // Laser Sweep Beam
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.cyan.opacity(0.7), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 160, height: 4)
                        .offset(y: scanlineOffset)
                }
                
                // Holographic Terminal Access Text
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 0.0, green: 1.0, blue: 0.64))
                            .frame(width: 7, height: 7)
                        
                        Text("ACCESS GRANTED // 1337")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                            .tracking(2)
                    }
                    
                    Text(glitchText)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.9))
                        .tracking(1.5)
                }
            }
            .scaleEffect(contentScale)
            .opacity(contentOpacity)
        }
        .onAppear {
            // Kick off animations
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                contentScale = 1.0
                contentOpacity = 1.0
            }
            
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                outerRingRotation = 360
            }
            
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                innerRingRotation = 360
            }
            
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                scanlineOffset = 80
            }
            
            withAnimation(.easeOut(duration: 0.8)) {
                shockwaveScale = 4.5
                shockwaveOpacity = 0.0
            }
            
            // Text change timing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                glitchText = "OPENING LIQUID SIGNER VAULT..."
            }
        }
    }
}
