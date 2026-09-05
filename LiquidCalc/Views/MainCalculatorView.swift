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
    @State private var workspaceSurface: WorkspaceDestination = .calculator
    @State private var showToolsSheet = false
    @State private var showCopilot = false
    @State private var copilotContext: WorkspaceContext?
    @Namespace private var dockTransitionAnimation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Liquid Frosted Background
            LiquidGlassBackground()
            
            VStack(spacing: 8) {
                // Top Header Toolbar with safe area spacing
                topHeaderBar
                    .padding(.top, 4)
                
                workspaceContent
                    .id(workspaceSurface)
                    .frame(maxWidth: 760, maxHeight: .infinity)
                    .frame(maxWidth: .infinity)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(y: 10)), removal: .opacity))

                workspaceDock
            }
            .safeAreaPadding(.top)
            .animation(reduceMotion ? .default : .spring(response: 0.32, dampingFraction: 0.84), value: workspaceSurface)
        }
        .sheet(isPresented: $showHistorySheet) {
            HistorySheetView(
                calculatorViewModel: calculatorViewModel,
                onAskAI: { context in showHistorySheet = false; presentCopilot(context) },
                onSaveToNotes: { context in WorkspaceRepository.shared.saveContext(context) }
            )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheetView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showToolsSheet) { toolsSheet }
        .sheet(isPresented: $showCopilot) {
            GeminiAIView(calculatorViewModel: calculatorViewModel, initialContext: copilotContext)
                .presentationDetents([.large])
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
    
    @ViewBuilder
    private var workspaceContent: some View {
        switch workspaceSurface {
        case .calculator:
            VStack(spacing: 8) {
                // Mode Selector Bar with smooth matched geometry
                ModeSwitcherView(selectedMode: $calculatorViewModel.currentMode)
                    .padding(.horizontal, 14)
                
                LiquidDisplayView(viewModel: calculatorViewModel)
                
                HStack(spacing: 8) {
                    workspaceAction("Explain", icon: "sparkles") { presentCopilot(.calculation(expression: calculatorViewModel.expression, result: calculatorViewModel.displayResult)) }
                    workspaceAction("Save", icon: "square.and.pencil") { WorkspaceRepository.shared.saveContext(.calculation(expression: calculatorViewModel.expression, result: calculatorViewModel.displayResult)); workspaceSurface = .notes }
                    workspaceAction("Signer", icon: "signature") { calculatorViewModel.showLiquidSigner = true }
                    workspaceAction("Tools", icon: "square.grid.2x2") { showToolsSheet = true }
                }
                .padding(.horizontal, 16)
                
                ZStack {
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
                            SmartVisionView(
                                calculatorViewModel: calculatorViewModel,
                                onSendToAI: { presentCopilot($0) },
                                onSaveToNotes: { WorkspaceRepository.shared.saveContext($0); workspaceSurface = .notes }
                            )
                        case .geminiAI:
                            GeminiAIView(calculatorViewModel: calculatorViewModel, initialContext: copilotContext)
                        case .advancedMath:
                            AdvancedMathView()
                        case .graphing:
                            FunctionGrapherView()
                        case .mathDraw:
                            MathDrawCanvasView()
                        }
                    }
                    .id(calculatorViewModel.currentMode)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity).combined(with: .offset(y: 8)),
                        removal: .scale(scale: 0.98).combined(with: .opacity)
                    ))
                }
                .animation(reduceMotion ? .default : .spring(response: 0.34, dampingFraction: 0.78), value: calculatorViewModel.currentMode)
                
                Spacer(minLength: 4)
            }
        case .scan:
            SmartVisionView(
                calculatorViewModel: calculatorViewModel,
                onSendToAI: { presentCopilot($0) },
                onSaveToNotes: { WorkspaceRepository.shared.saveContext($0); workspaceSurface = .notes }
            )
        case .ai:
            GeminiAIView(calculatorViewModel: calculatorViewModel, initialContext: copilotContext)
        case .notes:
            MarkdownNotebookView(isEmbedded: true)
        }
    }

    private func workspaceAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 12, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 42)
        }
        .foregroundStyle(.cyan).background(.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .accessibilityLabel(title)
    }

    private var workspaceDock: some View {
        HStack(spacing: 4) {
            ForEach(WorkspaceDestination.allCases) { surface in
                Button {
                    SoundAndHapticManager.shared.triggerHaptic(.selection)
                    withAnimation(reduceMotion ? .default : .spring(response: 0.32, dampingFraction: 0.74)) {
                        workspaceSurface = surface
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: surface.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .symbolEffect(.bounce, value: workspaceSurface == surface)
                        Text(surface.shortTitle)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(workspaceSurface == surface ? .white : .white.opacity(0.52))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background {
                        if workspaceSurface == surface {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.cyan.opacity(0.35), Color.blue.opacity(0.20)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.cyan.opacity(0.6), lineWidth: 1.2)
                                )
                                .shadow(color: Color.cyan.opacity(0.35), radius: 8)
                                .matchedGeometryEffect(id: "ActiveDockSurfaceIndicator", in: dockTransitionAnimation)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(surface.title)
                .accessibilityAddTraits(workspaceSurface == surface ? .isSelected : [])
            }
            Button { showToolsSheet = true } label: {
                VStack(spacing: 3) { Image(systemName: "square.grid.2x2").font(.system(size: 16, weight: .semibold)); Text("Tools").font(.system(size: 10, weight: .semibold)) }
                    .foregroundStyle(.white.opacity(0.62)).frame(maxWidth: .infinity, minHeight: 52)
            }.buttonStyle(.plain).accessibilityLabel("More tools")
        }
        .padding(6).background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.12), lineWidth: 1))
        .padding(.horizontal, 12).padding(.bottom, 8)
    }

    private var toolsSheet: some View {
        NavigationStack {
            List {
                Section("Compute") {
                    toolRow("Scientific", icon: "function", mode: .scientific)
                    toolRow("Math Lab", icon: "atom", mode: .advancedMath)
                    toolRow("Graphing", icon: "waveform.path.ecg", mode: .graphing)
                    toolRow("Unit Converter", icon: "arrow.triangle.2.circlepath", mode: .converter)
                    toolRow("Programmer", icon: "chevron.left.forwardslash.chevron.right", mode: .programmer)
                    toolRow("Draw Calc", icon: "hand.draw.fill", mode: .mathDraw)
                }
                Section("Advanced") {
                    Button { showToolsSheet = false; calculatorViewModel.showLiquidSigner = true } label: { Label("Signer Studio", systemImage: "signature") }
                }
            }.navigationTitle("Tools").navigationBarTitleDisplayMode(.inline)
        }
    }

    private func toolRow(_ title: String, icon: String, mode: CalculatorMode) -> some View {
        Button {
            withAnimation(reduceMotion ? .default : .spring(response: 0.32, dampingFraction: 0.78)) {
                calculatorViewModel.currentMode = mode
                workspaceSurface = .calculator
            }
            showToolsSheet = false
        } label: { Label(title, systemImage: icon) }
    }

    @ViewBuilder
    private func toolContent(_ mode: CalculatorMode) -> some View {
        switch mode {
        case .scientific: ScientificKeypadView(viewModel: calculatorViewModel)
        case .programmer: ProgrammerKeypadView(viewModel: programmerViewModel)
        case .converter: UnitConverterView(viewModel: converterViewModel)
        case .advancedMath: AdvancedMathView()
        case .graphing: FunctionGrapherView()
        case .mathDraw: MathDrawCanvasView()
        case .vision: SmartVisionView(calculatorViewModel: calculatorViewModel)
        case .geminiAI: GeminiAIView(calculatorViewModel: calculatorViewModel)
        case .standard: StandardKeypadView(viewModel: calculatorViewModel)
        }
    }

    private func presentCopilot(_ context: WorkspaceContext) { copilotContext = context; showCopilot = true }

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
