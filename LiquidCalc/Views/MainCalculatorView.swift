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
    @State private var showHistorySheet = false
    @State private var showSettingsSheet = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Liquid Frosted Background
            LiquidGlassBackground()
            
            VStack(spacing: 12) {
                // Top Header Toolbar
                topHeaderBar
                
                // Mode Switcher Capsule Bar (Standard, Scientific, Programmer, Converter, Vision)
                ModeSwitcherView(selectedMode: $calculatorViewModel.currentMode)
                    .padding(.horizontal, 8)
                
                // Standard Display Area (Shown in Standard & Scientific modes)
                if calculatorViewModel.currentMode == .standard || calculatorViewModel.currentMode == .scientific {
                    LiquidDisplayView(viewModel: calculatorViewModel)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .opacity
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
                    case .advancedMath:
                        AdvancedMathView()
                    case .graphing:
                        FunctionGrapherView()
                    case .mathDraw:
                        MathDrawCanvasView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity
                ))
                
                Spacer(minLength: 8)
            }
            .padding(.top, 4)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: calculatorViewModel.currentMode)
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
    }
    
    private var topHeaderBar: some View {
        HStack {
            // App Branding
            HStack(spacing: 6) {
                Image(systemName: "drop.degreesign.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("LiquidCalc")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Rad/Deg Switcher (Standard & Scientific only)
            if calculatorViewModel.currentMode == .standard || calculatorViewModel.currentMode == .scientific {
                Button(action: {
                    SoundAndHapticManager.shared.triggerHaptic(.selection)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        calculatorViewModel.angleUnit = (calculatorViewModel.angleUnit == .radians) ? .degrees : .radians
                    }
                }) {
                    Text(calculatorViewModel.angleUnit.rawValue.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white.opacity(0.85))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
            
            // Calculation Tape Button
            Button(action: {
                SoundAndHapticManager.shared.triggerHaptic(.light)
                showHistorySheet = true
            }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
            
            // Preferences / Settings Button
            Button(action: {
                SoundAndHapticManager.shared.triggerHaptic(.light)
                showSettingsSheet = true
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
