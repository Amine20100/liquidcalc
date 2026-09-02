//
//  MainCalculatorView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct MainCalculatorView: View {
    @State private var calculatorViewModel = CalculatorViewModel()
    @State private var programmerViewModel = ProgrammerViewModel()
    @State private var converterViewModel = ConverterViewModel()
    @Bindable private var updateManager = AppUpdateManager.shared
    @State private var showHistorySheet = false
    @State private var showSettingsSheet = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Liquid Frosted Background
            LiquidGlassBackground()
            
            VStack(spacing: 10) {
                // Top Header Toolbar with safe area spacing
                topHeaderBar
                    .padding(.top, 4)
                
                // Mode Switcher Capsule Bar
                ModeSwitcherView(selectedMode: $calculatorViewModel.currentMode)
                    .padding(.horizontal, 8)
                
                // Standard Display Area (Shown in Standard & Scientific modes)
                if calculatorViewModel.currentMode == .standard || calculatorViewModel.currentMode == .scientific {
                    LiquidDisplayView(viewModel: calculatorViewModel)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.94, anchor: .top).combined(with: .opacity).combined(with: .offset(y: -8)),
                            removal: .scale(scale: 0.96, anchor: .top).combined(with: .opacity)
                        ))
                }
                
                Spacer(minLength: 4)
                
                // Dynamic Mode Keypad / Workstation
                Group {
                    switch calculatorViewModel.currentMode {
                    case .standard:
                        StandardKeypadView(viewModel: calculatorViewModel)
                    case .scientific:
                        ScientificKeypadView(viewModel: calculatorViewModel)
                    case .programmer:
                        ProgrammerKeypadView(viewModel: programmerViewModel)
                    case .converter:
                        UnitConverterView(viewModel: converterViewModel)
                    case .vision:
                        SmartVisionView(calculatorViewModel: calculatorViewModel)
                    case .geminiAI:
                        GeminiAIView(calculatorViewModel: calculatorViewModel)
                    case .advancedMath:
                        AdvancedMathView()
                    case .graphing:
                        FunctionGrapherView()
                    case .mathDraw:
                        MathDrawCanvasView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity).combined(with: .offset(y: 14)),
                    removal: .scale(scale: 0.97).combined(with: .opacity)
                ))
                
                Spacer(minLength: 8)
            }
            .safeAreaPadding(.top)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: calculatorViewModel.currentMode)
        }
        .sheet(isPresented: $showHistorySheet) {
            HistorySheetView(calculatorViewModel: calculatorViewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheetView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $updateManager.showUpdateSheet) {
            if let release = updateManager.latestRelease {
                UpdateAvailableView(release: release, updateManager: updateManager)
            }
        }
        .fullScreenCover(isPresented: $calculatorViewModel.showLiquidSigner) {
            LiquidSignerView(calculatorViewModel: calculatorViewModel)
        }
        .overlay {
            if calculatorViewModel.isUnlockingSigner {
                VaultUnlockAnimationView()
                    .transition(.opacity)
                    .zIndex(99)
            }
        }
        .overlay(alignment: .top) {
            if updateManager.hasPendingUpdateBanner, let release = updateManager.latestRelease {
                UpdateNotificationBannerView(release: release, updateManager: updateManager)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(50)
            }
        }
        .task {
            if updateManager.autoCheckOnLaunch {
                // Background check with slight delay so initial render is instantaneous
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                await updateManager.checkForUpdates(manual: false)
            }
        }
    }
    
    private var topHeaderBar: some View {
        HStack(spacing: 8) {
            // App Branding
            HStack(spacing: 5) {
                Image(systemName: "drop.degreesign.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("LiquidCalc")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // Direct Update Available Alert Banner
            if updateManager.updateAvailable, let release = updateManager.latestRelease {
                Button(action: {
                    SoundAndHapticManager.shared.triggerHaptic(.medium)
                    updateManager.showUpdateSheet = true
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.cyan)
                        Text(release.tagName)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.cyan.opacity(0.25))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: Color.cyan.opacity(0.4), radius: 6)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
            
            // Rad/Deg Switcher (Standard & Scientific only)
            if calculatorViewModel.currentMode == .standard || calculatorViewModel.currentMode == .scientific {
                Button(action: {
                    SoundAndHapticManager.shared.triggerHaptic(.selection)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        calculatorViewModel.angleUnit = (calculatorViewModel.angleUnit == .radians) ? .degrees : .radians
                    }
                }) {
                    Text(calculatorViewModel.angleUnit.rawValue.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12))
                        .foregroundColor(.white.opacity(0.90))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.8))
                }
                .buttonStyle(HeaderActionPressStyle())
            }
            
            // Calculation History Button
            Button(action: {
                SoundAndHapticManager.shared.triggerHaptic(.light)
                showHistorySheet = true
            }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
            }
            .buttonStyle(HeaderActionPressStyle())
            
            // Preferences / Settings Button
            Button(action: {
                SoundAndHapticManager.shared.triggerHaptic(.light)
                showSettingsSheet = true
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
            }
            .buttonStyle(HeaderActionPressStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
}

private struct HeaderActionPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.58), value: configuration.isPressed)
    }
}
