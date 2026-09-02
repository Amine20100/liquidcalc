//
//  SigningProgressOverlay.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Liquid Signer Live Progress & 1-Tap Installation Overlay
//

import SwiftUI

public struct SigningProgressOverlay: View {
    @Bindable var signerViewModel: LiquidSignerViewModel
    let onDismiss: () -> Void
    
    @State private var ringRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    public init(signerViewModel: LiquidSignerViewModel, onDismiss: @escaping () -> Void) {
        self.signerViewModel = signerViewModel
        self.onDismiss = onDismiss
    }
    
    private var isDone: Bool {
        signerViewModel.signingProgress >= 1.0 && !signerViewModel.isSigning
    }
    
    public var body: some View {
        ZStack {
            // Dark Frosted Glass Backdrop
            Color.black.opacity(0.82)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Circular Progress Ring / Celebration Icon
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 8)
                        .frame(width: 140, height: 140)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(min(1.0, max(0.05, signerViewModel.signingProgress))))
                        .stroke(
                            LinearGradient(
                                colors: isDone
                                    ? [Color(red: 0.0, green: 1.0, blue: 0.64), Color.cyan]
                                    : [Color.cyan, Color.purple, Color.indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: signerViewModel.signingProgress)
                    
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                            .scaleEffect(pulseScale)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        VStack(spacing: 2) {
                            Text("\(Int(signerViewModel.signingProgress * 100))%")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Image(systemName: "signature")
                                .font(.system(size: 14))
                                .foregroundColor(.cyan.opacity(0.8))
                        }
                    }
                }
                .shadow(color: (isDone ? Color(red: 0.0, green: 1.0, blue: 0.64) : Color.cyan).opacity(0.4), radius: 18)
                
                // Status Texts
                VStack(spacing: 8) {
                    Text(isDone ? "Signing Completed!" : "Signing IPA Binary...")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(signerViewModel.signingStage)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    if let app = signerViewModel.activeSigningApp {
                        Text(app.name)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                // Completed Action Buttons (Install / Share)
                if isDone, let app = signerViewModel.activeSigningApp {
                    VStack(spacing: 12) {
                        // 1-Tap Direct On-Device Install
                        Button(action: {
                            signerViewModel.installApp(app)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.app.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Install on this iPhone")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.0, green: 1.0, blue: 0.64),
                                        Color(red: 0.0, green: 0.90, blue: 1.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.45), radius: 12, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        
                        // Share / Export Signed IPA
                        Button(action: {
                            signerViewModel.shareApp(app)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Export to Files / AirDrop")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.12)))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                        
                        // Dismiss Done Button
                        Button(action: onDismiss) {
                            Text("Done")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.top, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(white: 0.10, opacity: 0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.6), Color.purple.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                pulseScale = 1.0
            }
        }
    }
}
