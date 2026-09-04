//
//  SigningProgressOverlay.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Liquid Signer Live Progress, Real-Time Terminal & Multi-Channel Installation Hub
//

import SwiftUI

public struct SigningProgressOverlay: View {
    @Bindable var signerViewModel: LiquidSignerViewModel
    let onDismiss: () -> Void
    
    @State private var ringRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var showTerminalLogs: Bool = false
    @State private var celebrationRingScale: CGFloat = 0.8
    @State private var celebrationRingOpacity: Double = 0.8
    @State private var tipOrbScale: CGFloat = 1.0
    
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
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Circular Progress Ring / Celebration Icon
                progressRingSection
                
                // Status Texts
                VStack(spacing: 6) {
                    Text(isDone ? "Signing Completed!" : "Signing IPA Binary...")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(signerViewModel.signingStage)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    if let app = signerViewModel.activeSigningApp {
                        Text(app.name)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                // Real-Time Terminal Log Drawer (Collapsible)
                terminalLogDrawer
                
                // Completed Action Buttons (Install / Share)
                if isDone, let app = signerViewModel.activeSigningApp {
                    completedActionsSection(app: app)
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(white: 0.10, opacity: 0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: isDone
                                        ? [Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.8), Color.cyan.opacity(0.6)]
                                        : [Color.cyan.opacity(0.6), Color.purple.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .padding(.horizontal, 20)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                pulseScale = 1.0
            }
        }
        .onChange(of: isDone) { _, done in
            if done {
                SoundAndHapticManager.shared.triggerHaptic(.success)
                SoundAndHapticManager.shared.playSuccessSound()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.52)) {
                    pulseScale = 1.18
                }
                celebrationRingScale = 0.9
                celebrationRingOpacity = 0.85
                withAnimation(.easeOut(duration: 0.75)) {
                    celebrationRingScale = 1.75
                    celebrationRingOpacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        pulseScale = 1.0
                    }
                }
            }
        }
    }
    
    // MARK: - Progress Ring Section
    
    private var progressRingSection: some View {
        let progress = CGFloat(min(1.0, max(0.05, signerViewModel.signingProgress)))
        let tipAngle = (progress * 360.0) - 90.0
        let tipRad = tipAngle * .pi / 180.0
        let tipX = 60.0 * cos(tipRad)
        let tipY = 60.0 * sin(tipRad)
        
        return ZStack {
            // Ambient celebration ring
            if isDone {
                Circle()
                    .stroke(Color(red: 0.0, green: 1.0, blue: 0.64).opacity(celebrationRingOpacity), lineWidth: 3)
                    .frame(width: 120, height: 120)
                    .scaleEffect(celebrationRingScale)
            }
            
            // Background track
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 8)
                .frame(width: 120, height: 120)
            
            // Dynamic Progress Stroke
            Circle()
                .trim(from: 0, to: progress)
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
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: signerViewModel.signingProgress)
            
            // Leading Edge Glowing Particle Tip Orb
            if !isDone {
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .shadow(color: Color.cyan, radius: 6)
                    .offset(x: tipX, y: tipY)
                    .scaleEffect(tipOrbScale)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: signerViewModel.signingProgress)
            }
            
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                    .scaleEffect(pulseScale)
                    .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: 2) {
                    Text("\(Int(signerViewModel.signingProgress * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    
                    Image(systemName: "signature")
                        .font(.system(size: 13))
                        .foregroundColor(.cyan.opacity(0.8))
                }
            }
        }
        .shadow(color: (isDone ? Color(red: 0.0, green: 1.0, blue: 0.64) : Color.cyan).opacity(0.4), radius: 18)
    }
    
    // MARK: - Terminal Log Drawer
    
    private var terminalLogDrawer: some View {
        VStack(spacing: 6) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    showTerminalLogs.toggle()
                }
                SoundAndHapticManager.shared.triggerHaptic(.light)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.cyan)
                    Text(showTerminalLogs ? "Hide Terminal Output" : "Show Signing Terminal")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.cyan)
                    Spacer()
                    Image(systemName: showTerminalLogs ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            if showTerminalLogs {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(signerViewModel.logs.suffix(15)) { log in
                                Text(log.text)
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundColor(colorForLogLevel(log.level))
                                    .lineLimit(2)
                                    .id(log.id)
                            }
                        }
                        .padding(8)
                    }
                    .frame(height: 100)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.3), lineWidth: 0.8))
                    .onAppear {
                        if let lastLog = signerViewModel.logs.last {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Completed Actions Section
    
    private func completedActionsSection(app: SignedApp) -> some View {
        VStack(spacing: 10) {
            // Option 1: 1-Tap Wireless OTA Install
            Button(action: {
                signerViewModel.installApp(app)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.app.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("1-Tap Install on this iPhone (OTA)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
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
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.4), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            
            HStack(spacing: 8) {
                // Option 2: TrollStore Install
                Button(action: {
                    signerViewModel.installWithTrollStore(app)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.cyan)
                        Text("TrollStore")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.10)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.3), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                
                // Option 3: Share / AirDrop
                Button(action: {
                    signerViewModel.shareApp(app)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12))
                            .foregroundColor(.purple)
                        Text("Share IPA")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.10)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.3), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
            
            // Dismiss Done Button
            Button(action: onDismiss) {
                Text("Return to Vault")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func colorForLogLevel(_ level: SignerLogMessage.LogLevel) -> Color {
        switch level {
        case .info: return .white.opacity(0.7)
        case .success: return Color(red: 0.0, green: 1.0, blue: 0.64)
        case .warning: return .orange
        case .error: return .red
        case .terminal: return .cyan
        }
    }
}
