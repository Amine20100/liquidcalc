//
//  SignerStudioView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Liquid Signer Master Signing Studio & Multi-Step Carousel Wizard
//

import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

public struct SignerStudioView: View {
    @Bindable var signerViewModel: LiquidSignerViewModel
    @Bindable var certManager: CertificateManager
    @Bindable var localServer: LocalInstallServer
    
    private enum StepDirection {
        case forward, backward
    }
    
    // Wizard Carousel Milestone State (0: Select IPA, 1: Identity & Tweaks, 2: Review & Sign)
    @State private var currentStep: Int = 0
    @State private var stepDirection: StepDirection = .forward
    
    // Workbench State
    @State private var selectedApp: SignedApp?
    @State private var customName: String = ""
    @State private var customBundleId: String = ""
    @State private var customVersion: String = "1.0"
    @State private var stripExtensions: Bool = true
    @State private var removeWatchApp: Bool = true
    @State private var injectTaskAllow: Bool = false
    @State private var enableFileSharing: Bool = true
    @State private var adhocMode: Bool = false
    @State private var autoInstallAfterSigning: Bool = false
    
    // Collapsible Power-User Accordion
    @State private var showAdvancedOptions: Bool = false
    
    // File Pickers
    @State private var showIpaPicker: Bool = false
    @State private var showDylibPicker: Bool = false
    @State private var showP12Picker: Bool = false
    @State private var showProfilePicker: Bool = false
    
    // P12 import state
    @State private var pendingP12Data: Data? = nil
    @State private var pendingP12Filename: String = ""
    @State private var p12PasswordInput: String = ""
    @State private var showP12PasswordPrompt: Bool = false
    
    // Ecosystem Sheets
    @State private var showMachOInspector: Bool = false
    @State private var showTweakCatalog: Bool = false
    @State private var showCertStore: Bool = false
    @State private var showReadinessDetails: Bool = false
    @State private var cardsAppeared: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private struct ReadinessCheck: Identifiable {
        let id: String
        let title: String
        let detail: String
        let isPassing: Bool
    }
    
    public init(
        signerViewModel: LiquidSignerViewModel,
        certManager: CertificateManager,
        localServer: LocalInstallServer
    ) {
        self.signerViewModel = signerViewModel
        self.certManager = certManager
        self.localServer = localServer
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 1. Studio Header Banner
                studioHeader
                
                // 2. 3-Milestone Wizard Step Indicator Bar
                wizardStepIndicator
                
                // 3. Carousel Step Container (Swipeable & Fluid Spring Transitions)
                stepContainer
                    .gesture(
                        DragGesture(minimumDistance: 25)
                            .onEnded { value in
                                let horizontalAmount = value.translation.width
                                let verticalAmount = value.translation.height
                                guard abs(horizontalAmount) > abs(verticalAmount) * 1.25 else { return }
                                
                                if horizontalAmount < -45 && currentStep < 2 {
                                    if currentStep == 0 && selectedApp == nil {
                                        SoundAndHapticManager.shared.triggerHaptic(.warning)
                                        return
                                    }
                                    stepDirection = .forward
                                    SoundAndHapticManager.shared.triggerHaptic(.selection)
                                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                                        currentStep += 1
                                    }
                                    signerViewModel.wizardStep = currentStep
                                } else if horizontalAmount > 45 && currentStep > 0 {
                                    stepDirection = .backward
                                    SoundAndHapticManager.shared.triggerHaptic(.selection)
                                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                                        currentStep -= 1
                                    }
                                    signerViewModel.wizardStep = currentStep
                                }
                            }
                    )
                
                // 4. Expandable Power-User Advanced Options Accordion
                advancedOptionsAccordion
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
        .onAppear {
            withAnimation(reduceMotion ? .default : .spring(response: 0.42, dampingFraction: 0.78)) {
                cardsAppeared = true
            }
            if let active = signerViewModel.activeSigningApp {
                selectedApp = active
                syncFieldsWithSelectedApp()
            }
            currentStep = signerViewModel.wizardStep
        }
        .onChange(of: signerViewModel.activeSigningApp) { _, newActive in
            selectedApp = newActive
            if let newApp = newActive {
                syncFieldsWithSelectedApp()
            } else {
                customName = ""
                customBundleId = ""
                customVersion = "1.0"
            }
        }
        .onChange(of: signerViewModel.wizardStep) { _, newStep in
            if currentStep != newStep {
                stepDirection = newStep > currentStep ? .forward : .backward
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    currentStep = newStep
                }
            }
        }
        .onChange(of: signerViewModel.apps) { _, newApps in
            if let sel = selectedApp, let updated = newApps.first(where: { $0.id == sel.id }) {
                selectedApp = updated
            }
        }
        .fileImporter(
            isPresented: $showIpaPicker,
            allowedContentTypes: [
                UTType(filenameExtension: "ipa") ?? .data,
                UTType.zip,
                UTType.data,
                UTType.item
            ]
        ) { result in
            switch result {
            case .success(let url):
                if let newApp = signerViewModel.importIPA(from: url) {
                    selectedApp = newApp
                    syncFieldsWithSelectedApp()
                    SoundAndHapticManager.shared.triggerHaptic(.success)
                }
            case .failure(let error):
                signerViewModel.appendLog("IPA import error: \(error.localizedDescription)", .error)
            }
        }
        .fileImporter(
            isPresented: $showDylibPicker,
            allowedContentTypes: [
                UTType(filenameExtension: "dylib") ?? .data,
                UTType.data,
                UTType.item
            ]
        ) { result in
            switch result {
            case .success(let url):
                _ = signerViewModel.importDylib(from: url)
            case .failure(let error):
                signerViewModel.appendLog("Dylib import error: \(error.localizedDescription)", .error)
            }
        }
        .fileImporter(
            isPresented: $showP12Picker,
            allowedContentTypes: [
                UTType(filenameExtension: "p12") ?? .data,
                UTType.data,
                UTType.item
            ]
        ) { result in
            switch result {
            case .success(let url):
                let isAccessing = url.startAccessingSecurityScopedResource()
                defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    pendingP12Data = data
                    pendingP12Filename = url.lastPathComponent
                    p12PasswordInput = ""
                    showP12PasswordPrompt = true
                }
            case .failure(let error):
                signerViewModel.appendLog("P12 import error: \(error.localizedDescription)", .error)
            }
        }
        .fileImporter(
            isPresented: $showProfilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "mobileprovision") ?? .data,
                UTType.data,
                UTType.item
            ]
        ) { result in
            switch result {
            case .success(let url):
                do {
                    let prof = try certManager.importProvisioningProfile(from: url)
                    signerViewModel.appendLog("✓ Imported provisioning profile: \(prof.name)", .success)
                    SoundAndHapticManager.shared.triggerHaptic(.success)
                } catch {
                    signerViewModel.appendLog("Profile import failed: \(error.localizedDescription)", .error)
                    SoundAndHapticManager.shared.triggerHaptic(.error)
                }
            case .failure(let error):
                signerViewModel.appendLog("Profile import error: \(error.localizedDescription)", .error)
            }
        }
        .alert("Enter P12 Password", isPresented: $showP12PasswordPrompt) {
            SecureField("Password (or leave blank)", text: $p12PasswordInput)
            Button("Import") {
                if let data = pendingP12Data {
                    do {
                        let cert = try certManager.importP12Data(
                            data: data,
                            originalFilename: pendingP12Filename,
                            password: p12PasswordInput
                        )
                        signerViewModel.appendLog("✓ Imported certificate: \(cert.name)", .success)
                        SoundAndHapticManager.shared.triggerHaptic(.success)
                    } catch {
                        signerViewModel.appendLog("Failed importing certificate: \(error.localizedDescription)", .error)
                        SoundAndHapticManager.shared.triggerHaptic(.error)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter the decryption password for \(pendingP12Filename).")
        }
        .sheet(isPresented: $showMachOInspector) {
            if let app = selectedApp {
                MachOInspectorView(app: app)
            }
        }
        .sheet(isPresented: $showTweakCatalog) {
            TweakCatalogSheetView(catalogManager: TweakCatalogManager.shared, signerViewModel: signerViewModel)
        }
        .sheet(isPresented: $showCertStore) {
            CertificateStoreView(certManager: certManager)
        }
    }
    
    // MARK: - 1. Studio Header
    
    private var studioHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("ZSIGN STUDIO")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(LinearGradient(colors: [.cyan, .white], startPoint: .leading, endPoint: .trailing))
                }
                Text("Wizard Guided Sideloading • zhlynn/zsign Subsystem")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            
            Button(action: {
                SoundAndHapticManager.shared.triggerHaptic(.medium)
                showIpaPicker = true
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle.fill")
                    Text("Import IPA")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.0, green: 1.0, blue: 0.64), Color.cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
    
    private var stepTransition: AnyTransition {
        stepDirection == .forward
            ? .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                          removal: .move(edge: .leading).combined(with: .opacity))
            : .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                          removal: .move(edge: .trailing).combined(with: .opacity))
    }
    
    // MARK: - 2. Wizard Milestone Step Indicator
    
    private var wizardStepIndicator: some View {
        let steps = [
            (number: 1, title: "Select IPA", icon: "doc.badge.plus"),
            (number: 2, title: "Identity & Tweaks", icon: "lock.shield.fill"),
            (number: 3, title: "Review & Sign", icon: "signature")
        ]
        
        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(0..<steps.count, id: \.self) { idx in
                    let isCompleted = currentStep > idx
                    let isActive = currentStep == idx
                    
                    // Step Circle / Capsule
                    Button(action: {
                        if idx > 0 && selectedApp == nil {
                            SoundAndHapticManager.shared.triggerHaptic(.warning)
                            return
                        }
                        stepDirection = idx > currentStep ? .forward : .backward
                        SoundAndHapticManager.shared.triggerHaptic(.selection)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            currentStep = idx
                        }
                        signerViewModel.wizardStep = idx
                    }) {
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(
                                        isActive
                                            ? Color.cyan
                                            : (isCompleted ? Color(red: 0.0, green: 1.0, blue: 0.64) : Color.white.opacity(0.12))
                                    )
                                    .frame(width: 26, height: 26)
                                
                                if isCompleted {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.black)
                                } else {
                                    Text("\(steps[idx].number)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(isActive ? .black : .white.opacity(0.7))
                                }
                            }
                            
                            Text(steps[idx].title)
                                .font(.system(size: 11, weight: isActive ? .bold : .medium, design: .rounded))
                                .foregroundColor(isActive ? .white : (isCompleted ? Color(red: 0.0, green: 1.0, blue: 0.64) : .white.opacity(0.45)))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Connecting Line
                    if idx < steps.count - 1 {
                        Rectangle()
                            .fill(currentStep > idx ? Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.8) : Color.white.opacity(0.15))
                            .frame(height: 2)
                            .padding(.horizontal, 6)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                    )
            )
        }
    }
    
    // MARK: - 3. Carousel Step Container
    
    private var stepContainer: some View {
        VStack(spacing: 16) {
            switch currentStep {
            case 0:
                stepOneSelectIPA
                    .transition(stepTransition)
            case 1:
                stepTwoIdentityAndTweaks
                    .transition(stepTransition)
            case 2:
                stepThreeReviewAndSign
                    .transition(stepTransition)
            default:
                EmptyView()
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: currentStep)
    }
    
    // MARK: - Step 1: Select IPA
    
    private var stepOneSelectIPA: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Milestone Subheader
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("STEP 1: SELECT & CUSTOMIZE IPA")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    Text("Select a package from your library or import directly from Files")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                }
                Spacer()
            }
            
            // Selected IPA or Dropzone Card
            if let app = selectedApp {
                // Active App Preview Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        // App Icon Preview with Dynamic Monogram
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.cyan.opacity(0.4), Color.purple.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 52, height: 52)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                                )
                            
                            Text(app.name.prefix(2).uppercased())
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.name)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(app.bundleIdentifier)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.cyan.opacity(0.85))
                                .lineLimit(1)
                            
                            HStack(spacing: 6) {
                                Text("v\(app.version)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("•")
                                    .foregroundColor(.white.opacity(0.3))
                                Text(ByteCountFormatter.string(fromByteCount: app.sizeBytes, countStyle: .file))
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("•")
                                    .foregroundColor(.white.opacity(0.3))
                                Text("ARM64 Clean")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                            }
                        }
                        
                        Spacer()
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // Switch / Import App Selector
                    HStack {
                        Menu {
                            ForEach(signerViewModel.apps) { item in
                                Button(item.name) {
                                    selectedApp = item
                                    syncFieldsWithSelectedApp()
                                    SoundAndHapticManager.shared.triggerHaptic(.selection)
                                }
                            }
                            Divider()
                            Button("Import New IPA...") {
                                showIpaPicker = true
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Switch Package (\(signerViewModel.apps.count))")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.cyan.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            SoundAndHapticManager.shared.triggerHaptic(.selection)
                            showMachOInspector = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "cpu")
                                Text("Mach-O Inspector")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        )
                )
                
                // Metadata & Cloning Customization Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("APP CUSTOMIZATION")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                        Spacer()
                        
                        Button(action: {
                            if !customBundleId.hasSuffix(".cloned") {
                                customBundleId += ".cloned"
                                customName += " (Clone)"
                                SoundAndHapticManager.shared.triggerHaptic(.selection)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 9))
                                Text("1-Tap Clone ID")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Display Name")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        TextField("App Name", text: $customName)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bundle Identifier")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        TextField("com.example.app", text: $customBundleId)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version String")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        TextField("1.0", text: $customVersion)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                        )
                )
            } else {
                // Dropzone Card
                Button(action: {
                    SoundAndHapticManager.shared.triggerHaptic(.medium)
                    showIpaPicker = true
                }) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.cyan.opacity(0.18))
                                .frame(width: 64, height: 64)
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.cyan)
                        }
                        
                        Text("Select or Import IPA File")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Tap to browse iCloud Drive or local iPhone storage (.ipa or .zip)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.cyan.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                            )
                    )
                }
                .buttonStyle(.plain)
                
                // Library Quick-Picker if apps exist
                if !signerViewModel.apps.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OR SELECT FROM LIBRARY")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(signerViewModel.apps) { item in
                                    Button(action: {
                                        selectedApp = item
                                        syncFieldsWithSelectedApp()
                                        SoundAndHapticManager.shared.triggerHaptic(.selection)
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "app.badge.checkmark")
                                                .font(.system(size: 11))
                                                .foregroundColor(.cyan)
                                            Text(item.name)
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundColor(.white)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.2), lineWidth: 0.8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
                    )
                }
            }
            
            // Step 1 Navigation Button
            Button(action: {
                stepDirection = .forward
                SoundAndHapticManager.shared.triggerHaptic(.medium)
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    currentStep = 1
                }
                signerViewModel.wizardStep = 1
            }) {
                HStack(spacing: 8) {
                    Text("Next: Identity & Tweaks")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    selectedApp != nil
                        ? LinearGradient(colors: [Color.cyan, Color(red: 0.0, green: 1.0, blue: 0.64)], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(selectedApp == nil)
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Step 2: Identity & Tweaks
    
    private var stepTwoIdentityAndTweaks: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTwoHeader
            stepTwoSigningIdentityCard
            stepTwoDylibTweakCard
            stepTwoNavigationButtons
        }
    }
    
    private var stepTwoHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("STEP 2: SIGNING IDENTITY & DYLIBS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                Text("Select Apple certificate profile and queue tweaks to inject")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer()
        }
    }
    
    private var stepTwoSigningIdentityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SIGNING IDENTITY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                Spacer()
                
                Toggle("Ad-Hoc Mode", isOn: $adhocMode)
                    .font(.system(size: 11, weight: .semibold))
                    .tint(.cyan)
            }
            
            if adhocMode {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.badge.shield.half.filled.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.cyan)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ad-Hoc Signature Active")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text("No certificate or mobileprovision required. Ideal for TrollStore or jailbreak.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.cyan.opacity(0.12)))
            } else if let cert = certManager.activeCertificate {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 26))
                        .foregroundColor(cert.isValid ? Color(red: 0.0, green: 1.0, blue: 0.64) : .red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cert.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("Team: \(cert.teamIdentifier) • Expiry: \(cert.expirationDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                        
                        HStack(spacing: 6) {
                            Text("\(cert.daysRemaining) days left")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(cert.daysRemaining > 30 ? Color(red: 0.0, green: 1.0, blue: 0.64) : .orange)
                            
                            if let profile = certManager.activeProfile {
                                Text("•")
                                    .foregroundColor(.white.opacity(0.3))
                                Text(profile.name)
                                    .font(.system(size: 10))
                                    .foregroundColor(.purple)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("No Certificate Loaded. Import a .p12 below or toggle Ad-Hoc.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.10)))
            }
            
            // Action Buttons for Identity
            HStack(spacing: 8) {
                Menu {
                    ForEach(certManager.certificates) { cert in
                        Button(cert.name) {
                            certManager.activeCertificate = cert
                            SoundAndHapticManager.shared.triggerHaptic(.selection)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Switch Cert")
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cyan.opacity(0.12))
                    .clipShape(Capsule())
                }
                
                Button(action: { showP12Picker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("P12")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                
                Button(action: { showProfilePicker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Profile")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                Button(action: { showCertStore = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "creditcard.fill")
                        Text("Cert Store")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.15))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
    
    private var stepTwoDylibTweakCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                    Text("DYLIB TWEAK INJECTION (\(signerViewModel.tweaks.filter { $0.isEnabled }.count) ACTIVE)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.purple)
                }
                Spacer()
                
                Button(action: { showTweakCatalog = true }) {
                    HStack(spacing: 3) {
                        Image(systemName: "cart.fill")
                        Text("Tweak Store")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.18))
                    .clipShape(Capsule())
                }
                
                Button(action: { showDylibPicker = true }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                        Text("Dylib")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            
            if signerViewModel.tweaks.isEmpty {
                Text("No dylibs loaded. Tap '+ Dylib' or 'Tweak Store' to inject dynamic frameworks.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 6) {
                    ForEach(signerViewModel.tweaks) { tweak in
                        HStack {
                            Image(systemName: "puzzlepiece.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tweak.filename)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(tweak.formattedSize)
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { tweak.isEnabled },
                                set: { _ in signerViewModel.toggleTweak(tweak) }
                            ))
                            .labelsHidden()
                            .tint(.purple)
                            
                            Button(action: { signerViewModel.deleteTweak(tweak) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 0.8)
                )
        )
    }
    
    private var stepTwoNavigationButtons: some View {
        HStack(spacing: 10) {
            Button(action: {
                stepDirection = .backward
                SoundAndHapticManager.shared.triggerHaptic(.light)
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    currentStep = 0
                }
                signerViewModel.wizardStep = 0
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                    Text("Back: IPA")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            
            Button(action: {
                stepDirection = .forward
                SoundAndHapticManager.shared.triggerHaptic(.medium)
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    currentStep = 2
                }
                signerViewModel.wizardStep = 2
            }) {
                HStack(spacing: 6) {
                    Text("Next: Review & Sign")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    LinearGradient(colors: [Color.cyan, Color(red: 0.0, green: 1.0, blue: 0.64)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Step 3: Review & Sign
    
    private var stepThreeReviewAndSign: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Milestone Subheader
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("STEP 3: REVIEW & SIGN APPLICATION")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    Text("Verify preflight parameters and launch the signing pipeline")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                }
                Spacer()
            }
            
            // Preflight Readiness Card
            signingReadinessCard
            
            // Summary Configuration Card
            VStack(alignment: .leading, spacing: 10) {
                Text("DEPLOYMENT SUMMARY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                summaryRow(title: "Target Package", value: selectedApp?.name ?? "None", icon: "app.fill", color: .cyan)
                summaryRow(title: "Bundle Identifier", value: customBundleId.isEmpty ? (selectedApp?.bundleIdentifier ?? "N/A") : customBundleId, icon: "tag.fill", color: .cyan)
                summaryRow(title: "Identity", value: adhocMode ? "Ad-Hoc / TrollStore" : (certManager.activeCertificate?.name ?? "Ad-Hoc Dev"), icon: "lock.shield.fill", color: adhocMode ? .cyan : (certManager.activeCertificate?.isValid == true ? Color(red: 0.0, green: 1.0, blue: 0.64) : .orange))
                summaryRow(title: "Injected Tweaks", value: "\(signerViewModel.tweaks.filter { $0.isEnabled }.count) dylib(s) queued", icon: "puzzlepiece.extension.fill", color: .purple)
                summaryRow(title: "Signing Engine", value: signerViewModel.selectedEngineMode.rawValue, icon: "cpu.fill", color: .cyan)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                    )
            )
            
            // Large 1-Tap Sign App Button
            signActionButton
            
            // Post-Signing Immediate Deployment Card
            if let target = selectedApp, target.status == .signed {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                        Text("SIGNING COMPLETED — READY TO INSTALL")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                    }
                    
                    Button(action: {
                        signerViewModel.installApp(target)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.app.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("1-Tap Install via OTA")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.0, green: 1.0, blue: 0.64), Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.4), radius: 8)
                    }
                    .buttonStyle(.plain)
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            signerViewModel.installWithTrollStore(target)
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "magnifyingglass")
                                Text("TrollStore")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            signerViewModel.shareApp(target)
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share IPA")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.purple)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(Color.purple.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.green.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            // Step 3 Navigation Buttons
            Button(action: {
                stepDirection = .backward
                SoundAndHapticManager.shared.triggerHaptic(.light)
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    currentStep = 1
                }
                signerViewModel.wizardStep = 1
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                    Text("Back to Identity & Tweaks")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func summaryRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - 4. Advanced Options Accordion
    
    private var advancedOptionsAccordion: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Accordion Toggle Header
            Button(action: {
                SoundAndHapticManager.shared.triggerHaptic(.selection)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    showAdvancedOptions.toggle()
                }
            }) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                        Text("POWER-USER OPTIONS & CLI")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    
                    Spacer()
                    
                    Image(systemName: showAdvancedOptions ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            
            if showAdvancedOptions {
                VStack(alignment: .leading, spacing: 14) {
                    Divider().background(Color.white.opacity(0.1))
                    
                    // Engine Mode Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ENGINE EXECUTION MODE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        
                        HStack(spacing: 8) {
                            engineModePill(title: "Native Swift", subtitle: "On-Device", icon: "cpu.fill", mode: .onDevice)
                            engineModePill(title: "Cloud Cluster", subtitle: "Remote Server", icon: "cloud.fill", mode: .cloudServer)
                        }
                    }
                    
                    // Sideloading Compatibility Toggles
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COMPATIBILITY SWITCHES")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Toggle("[-a] Ad-Hoc Mode (TrollStore / No Cert Required)", isOn: $adhocMode)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .tint(.cyan)
                        
                        Toggle("[-E] Strip App Extensions (PlugIns)", isOn: $stripExtensions)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .tint(.cyan)
                        
                        Toggle("[-W] Remove Watch Applications", isOn: $removeWatchApp)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .tint(.cyan)
                        
                        Toggle("[-S] Enable Files App & Document Sharing", isOn: $enableFileSharing)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .tint(.cyan)
                        
                        Toggle("[-d] Inject get-task-allow (Debugging)", isOn: $injectTaskAllow)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .tint(.cyan)
                        
                        Toggle("[✓] Auto-Install via OTA After Signing", isOn: $autoInstallAfterSigning)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .tint(Color(red: 0.0, green: 1.0, blue: 0.64))
                    }
                    
                    // Mach-O Inspector Trigger
                    Button(action: {
                        SoundAndHapticManager.shared.triggerHaptic(.selection)
                        showMachOInspector = true
                    }) {
                        HStack {
                            Image(systemName: "cpu")
                            Text("Launch Mach-O Binary Inspector")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.cyan)
                        .padding(10)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    
                    // Live ZSign CLI Command Inspector
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("ZSIGN CLI INVOCATION")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                            Spacer()
                            
                            Button(action: {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = generatedZSignCommand
                                #endif
                                SoundAndHapticManager.shared.triggerHaptic(.light)
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy")
                                }
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.cyan.opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }
                        
                        Text(generatedZSignCommand)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
    
    private func engineModePill(title: String, subtitle: String, icon: String, mode: SigningEngineMode) -> some View {
        let isSelected = signerViewModel.selectedEngineMode == mode
        
        return Button(action: {
            signerViewModel.selectedEngineMode = mode
            SoundAndHapticManager.shared.triggerHaptic(.selection)
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .black : .cyan)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isSelected ? .black : .white)
                    Text(subtitle)
                        .font(.system(size: 8))
                        .foregroundColor(isSelected ? .black.opacity(0.7) : .white.opacity(0.5))
                }
                Spacer()
            }
            .padding(8)
            .background(isSelected ? Color.cyan : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.cyan : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Readiness & Preflight Checks
    
    private var readinessChecks: [ReadinessCheck] {
        let trimmedName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBundleID = customBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleParts = trimmedBundleID.split(separator: ".")
        let validBundleID = bundleParts.count >= 2 && bundleParts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
        }
        let validCertificate = certManager.activeCertificate?.isValid ?? false
        let validProfile = !(certManager.activeProfile?.isExpired ?? false)

        return [
            ReadinessCheck(
                id: "package",
                title: "Package selected",
                detail: selectedApp?.name ?? "Import an IPA to begin",
                isPassing: selectedApp?.originalIpaUrl != nil
            ),
            ReadinessCheck(
                id: "identity",
                title: adhocMode ? "Ad-hoc mode" : "Signing identity",
                detail: adhocMode ? "No certificate required" : (validCertificate ? "Valid certificate selected" : "Import or select a valid P12"),
                isPassing: adhocMode || validCertificate
            ),
            ReadinessCheck(
                id: "profile",
                title: "Provisioning profile",
                detail: adhocMode ? "Not required for ad-hoc signing" : (validProfile ? "Profile is current" : "Selected profile has expired"),
                isPassing: adhocMode || validProfile
            ),
            ReadinessCheck(
                id: "identifier",
                title: "App identity",
                detail: validBundleID && !trimmedName.isEmpty ? trimmedBundleID : "Enter a valid display name and bundle ID",
                isPassing: validBundleID && !trimmedName.isEmpty
            )
        ]
    }

    private var isReadyToSign: Bool {
        readinessChecks.allSatisfy(\.isPassing)
    }

    private var signingReadinessCard: some View {
        let passedCount = readinessChecks.filter(\.isPassing).count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 3.5)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: CGFloat(passedCount) / CGFloat(max(readinessChecks.count, 1)))
                        .stroke(
                            LinearGradient(
                                colors: isReadyToSign
                                    ? [Color(red: 0.0, green: 1.0, blue: 0.64), Color.cyan]
                                    : [Color.orange, Color.yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: passedCount)
                    
                    Image(systemName: isReadyToSign ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(isReadyToSign ? Color(red: 0.0, green: 1.0, blue: 0.64) : .orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(isReadyToSign ? "Ready to Sign" : "Complete Preflight Checks")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(isReadyToSign ? "All 4 preflight requirements verified." : "\(passedCount) of \(readinessChecks.count) preflight checks complete")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.62))
                }
                Spacer()
                
                Button(showReadinessDetails ? "Less" : "Review") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showReadinessDetails.toggle()
                    }
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isReadyToSign ? Color(red: 0.0, green: 1.0, blue: 0.64) : .orange)
                .buttonStyle(.plain)
            }

            if showReadinessDetails || !isReadyToSign {
                VStack(spacing: 8) {
                    ForEach(readinessChecks) { check in
                        HStack(spacing: 8) {
                            Image(systemName: check.isPassing ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(check.isPassing ? Color(red: 0.0, green: 1.0, blue: 0.64) : .orange)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(check.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(check.detail)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.52))
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill((isReadyToSign ? Color.green : Color.orange).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke((isReadyToSign ? Color.green : Color.orange).opacity(0.28), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Sign Action Button
    
    private var signActionButton: some View {
        Button(action: executeSigning) {
            HStack(spacing: 10) {
                if signerViewModel.isSigning {
                    ZStack {
                        Circle()
                            .stroke(Color.black.opacity(0.25), lineWidth: 3)
                            .frame(width: 20, height: 20)
                        Circle()
                            .trim(from: 0, to: CGFloat(max(signerViewModel.signingProgress, 0.05)))
                            .stroke(Color.black, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 20, height: 20)
                            .rotationEffect(.degrees(-90))
                    }
                    Text("SIGNING (\(Int(signerViewModel.signingProgress * 100))%)...")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                } else {
                    Image(systemName: isReadyToSign ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                        .font(.system(size: 16, weight: .black))
                    Text(isReadyToSign ? (signerViewModel.selectedEngineMode == .cloudServer ? "SIGN WITH ZSIGN CLOUD" : "SIGN APP SECURELY") : "COMPLETE PREFLIGHT TO SIGN")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                }
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: signerViewModel.selectedEngineMode == .cloudServer
                        ? [Color.purple, Color.cyan]
                        : [Color(red: 0.0, green: 1.0, blue: 0.64), Color.cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(
                color: (signerViewModel.selectedEngineMode == .cloudServer ? Color.purple : Color.cyan).opacity(0.4),
                radius: 12,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .disabled(!isReadyToSign || signerViewModel.isSigning)
        .opacity(!isReadyToSign || signerViewModel.isSigning ? 0.5 : 1.0)
    }
    
    // MARK: - Helpers & Logic
    
    private var generatedZSignCommand: String {
        var parts = ["zsign"]
        if adhocMode {
            parts.append("-a")
        } else {
            if let cert = certManager.activeCertificate {
                parts.append("-k \(cert.name.replacingOccurrences(of: " ", with: "_")).p12")
            }
            if let profile = certManager.activeProfile {
                parts.append("-m \(profile.name.replacingOccurrences(of: " ", with: "_")).mobileprovision")
            }
        }
        if !customBundleId.isEmpty {
            parts.append("-b '\(customBundleId)'")
        }
        if !customName.isEmpty {
            parts.append("-n '\(customName)'")
        }
        if !customVersion.isEmpty {
            parts.append("-r '\(customVersion)'")
        }
        for tweak in signerViewModel.tweaks.filter({ $0.isEnabled }) {
            parts.append("-l '\(tweak.filename)'")
        }
        if stripExtensions {
            parts.append("-E")
        }
        if removeWatchApp {
            parts.append("-W")
        }
        if enableFileSharing {
            parts.append("-S")
        }
        let outName = (customName.isEmpty ? "app" : customName.replacingOccurrences(of: " ", with: "_")) + "_signed.ipa"
        parts.append("-o '\(outName)'")
        parts.append(selectedApp?.name ?? "input.ipa")
        return parts.joined(separator: " ")
    }
    
    private func syncFieldsWithSelectedApp() {
        guard let app = selectedApp else { return }
        customName = app.name
        customBundleId = app.bundleIdentifier
        customVersion = app.version
    }
    
    private func executeSigning() {
        guard let app = selectedApp, isReadyToSign else {
            showReadinessDetails = true
            SoundAndHapticManager.shared.triggerHaptic(.warning)
            return
        }
        
        let config = SigningConfig(
            customName: customName.trimmingCharacters(in: .whitespaces),
            customBundleId: customBundleId.trimmingCharacters(in: .whitespaces),
            customVersion: customVersion.trimmingCharacters(in: .whitespaces),
            certificate: adhocMode ? nil : certManager.activeCertificate,
            profile: adhocMode ? nil : certManager.activeProfile,
            dylibs: signerViewModel.tweaks.filter { $0.isEnabled },
            removeExtensions: stripExtensions,
            injectGetTaskAllow: injectTaskAllow,
            enableFileSharing: enableFileSharing,
            installAfterSigned: autoInstallAfterSigning
        )
        
        signerViewModel.signAppWithSelectedEngine(app: app, config: config)
    }
}
