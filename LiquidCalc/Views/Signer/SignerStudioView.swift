//
//  SignerStudioView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Liquid Signer Master Signing Studio & Workbench
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
    
    @State private var showIpaPicker: Bool = false
    @State private var showDylibPicker: Bool = false
    @State private var showP12Picker: Bool = false
    @State private var showProfilePicker: Bool = false
    @State private var showSuccessToast: Bool = false
    
    // P12 import state
    @State private var pendingP12Data: Data? = nil
    @State private var pendingP12Filename: String = ""
    @State private var p12PasswordInput: String = ""
    @State private var showP12PasswordPrompt: Bool = false
    
    // v2.6.0 Ecosystem Sheets
    @State private var showMachOInspector: Bool = false
    @State private var showTweakCatalog: Bool = false
    @State private var showCertStore: Bool = false
    @State private var showReadinessDetails: Bool = false
    @State private var cardsAppeared: Bool = false

    /// A signing session should feel safe before it feels powerful. These checks make
    /// the primary action deterministic instead of leaving users to discover failures
    /// after a long signing run.
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
                studioHeader
                    .offset(y: cardsAppeared ? 0 : 16)
                    .opacity(cardsAppeared ? 1 : 0)

                signingReadinessCard
                    .offset(y: cardsAppeared ? 0 : 20)
                    .opacity(cardsAppeared ? 1 : 0)
                
                engineSelectorCard
                    .offset(y: cardsAppeared ? 0 : 24)
                    .opacity(cardsAppeared ? 1 : 0)
                
                sourceAppCard
                    .offset(y: cardsAppeared ? 0 : 28)
                    .opacity(cardsAppeared ? 1 : 0)
                
                customizationCard
                    .offset(y: cardsAppeared ? 0 : 32)
                    .opacity(cardsAppeared ? 1 : 0)
                
                certificateSelectionCard
                    .offset(y: cardsAppeared ? 0 : 36)
                    .opacity(cardsAppeared ? 1 : 0)
                
                dylibInjectionCard
                    .offset(y: cardsAppeared ? 0 : 40)
                    .opacity(cardsAppeared ? 1 : 0)
                
                compatibilityCard
                    .offset(y: cardsAppeared ? 0 : 44)
                    .opacity(cardsAppeared ? 1 : 0)
                
                zsignCommandCard
                    .offset(y: cardsAppeared ? 0 : 48)
                    .opacity(cardsAppeared ? 1 : 0)
                
                signActionButton
                    .offset(y: cardsAppeared ? 0 : 52)
                    .opacity(cardsAppeared ? 1 : 0)
                
                if let lastSigned = signerViewModel.apps.first(where: { $0.status == .signed }) {
                    recentSignedCard(lastSigned)
                        .offset(y: cardsAppeared ? 0 : 56)
                        .opacity(cardsAppeared ? 1 : 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 32)
            .animation(.spring(response: 0.42, dampingFraction: 0.78), value: cardsAppeared)
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                cardsAppeared = true
            }
            if selectedApp == nil {
                selectedApp = signerViewModel.apps.first
                syncFieldsWithSelectedApp()
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
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(LinearGradient(colors: [.cyan, .white], startPoint: .leading, endPoint: .trailing))
                }
                Text("Fast Cross-Platform iOS Code Signer • zhlynn/zsign")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            
            // Fast Import Button
            Button(action: { showIpaPicker = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Import IPA")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(red: 0.0, green: 1.0, blue: 0.64))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Signing Readiness

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
                        .scaleEffect(isReadyToSign ? 1.08 : 1.0)
                        .animation(.spring(response: 0.30, dampingFraction: 0.60), value: isReadyToSign)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(isReadyToSign ? "Ready to sign" : "Complete your signing setup")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(isReadyToSign ? "Your package, identity, and app metadata passed preflight." : "\(passedCount) of \(readinessChecks.count) preflight checks complete")
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
                .foregroundColor(isReadyToSign ? .green : .orange)
                .buttonStyle(.plain)
                .accessibilityLabel("Review signing readiness")
            }

            if showReadinessDetails || !isReadyToSign {
                VStack(spacing: 8) {
                    ForEach(readinessChecks) { check in
                        HStack(spacing: 8) {
                            Image(systemName: check.isPassing ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(check.isPassing ? .green : .orange)
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
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - 2. Engine Selector Card
    
    private var engineSelectorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ZSIGN ENGINE MODE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
            HStack(spacing: 8) {
                engineButton(
                    title: "ZSign Native Swift",
                    subtitle: "Zero network • Pure zsign crypto",
                    icon: "cpu.fill",
                    mode: .onDevice
                )
                
                engineButton(
                    title: "ZSign Cloud Cluster",
                    subtitle: "Remote zsign server • Instant OTA",
                    icon: "cloud.fill",
                    mode: .cloudServer
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        )
    }
    
    private func engineButton(title: String, subtitle: String, icon: String, mode: SigningEngineMode) -> some View {
        let isSelected = signerViewModel.selectedEngineMode == mode
        
        return Button(action: {
            signerViewModel.selectedEngineMode = mode
            SoundAndHapticManager.shared.triggerHaptic(.selection)
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.cyan)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .padding(10)
            .background(isSelected ? Color.cyan.opacity(0.18) : Color.white.opacity(0.03))
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.cyan : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 3. Source App Card
    
    private var sourceAppCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TARGET APPLICATION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                Spacer()
                HStack(spacing: 8) {
                    Button(action: {
                        SoundAndHapticManager.shared.triggerHaptic(.medium)
                        showIpaPicker = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Import IPA")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.cyan)
                        .clipShape(Capsule())
                    }
                    
                    Menu {
                        ForEach(signerViewModel.apps) { app in
                            Button(app.name) {
                                selectedApp = app
                                syncFieldsWithSelectedApp()
                            }
                        }
                        Divider()
                        Button("Import New IPA...") {
                            showIpaPicker = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Switch App")
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.cyan)
                    }
                }
            }
            
            if let app = selectedApp {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(colors: [.purple.opacity(0.6), .blue.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 48, height: 48)
                        Image(systemName: "app.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text(app.bundleIdentifier)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                        
                        HStack(spacing: 8) {
                            Text("v\(app.version)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.cyan)
                            Text(ByteCountFormatter.string(fromByteCount: app.sizeBytes, countStyle: .file))
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.4))
                            
                            Text("ARM64 Clean")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                            
                            Button(action: {
                                SoundAndHapticManager.shared.triggerHaptic(.selection)
                                showMachOInspector = true
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "cpu")
                                    Text("Mach-O")
                                }
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.cyan.opacity(0.2))
                                .foregroundColor(.cyan)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
            } else {
                Button(action: { showIpaPicker = true }) {
                    HStack {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Select or Import IPA File")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.cyan)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.cyan.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        )
    }
    
    // MARK: - 4. Customization Card
    
    private var customizationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("METADATA & APP CLONING")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
            // App Name Field
            VStack(alignment: .leading, spacing: 4) {
                Text("Display Name")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                TextField("App Display Name", text: $customName)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
            }
            
            // Bundle ID & 1-Tap Clone
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Bundle Identifier")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
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
                            Text("Clone ID")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.cyan.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
                TextField("com.example.app", text: $customBundleId)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
            }
            
            // Version
            VStack(alignment: .leading, spacing: 4) {
                Text("Version String")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                TextField("1.0", text: $customVersion)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        )
    }
    
    // MARK: - 5. Certificate Selection Card
    
    private var certificateSelectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SIGNING IDENTITY & PROVISION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                Spacer()
                HStack(spacing: 6) {
                    Button(action: {
                        SoundAndHapticManager.shared.triggerHaptic(.selection)
                        showP12Picker = true
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                            Text("P12")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.cyan)
                        .clipShape(Capsule())
                    }
                    
                    Button(action: {
                        SoundAndHapticManager.shared.triggerHaptic(.selection)
                        showProfilePicker = true
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                            Text("Profile")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.cyan)
                        .clipShape(Capsule())
                    }
                    
                    Button(action: {
                        SoundAndHapticManager.shared.triggerHaptic(.selection)
                        showCertStore = true
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Cert Store")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
            
            if let cert = certManager.activeCertificate {
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cert.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text("Team: \(cert.teamIdentifier) • Expiration: \(cert.expirationDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    
                    Text("\(cert.daysRemaining)d")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(cert.daysRemaining > 30 ? .green : .orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Ad-Hoc / Built-In Development Identity")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("Universal")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.cyan)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        )
    }
    
    // MARK: - 6. Dylib Injection Card
    
    private var dylibInjectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("MACH-O DYLIB INJECTION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                Spacer()
                
                Button(action: {
                    SoundAndHapticManager.shared.triggerHaptic(.selection)
                    showTweakCatalog = true
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "puzzlepiece.extension.fill")
                        Text("Tweak Store")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.15))
                    .clipShape(Capsule())
                }
                
                Button(action: { showDylibPicker = true }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                        Text("Custom")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            
            if signerViewModel.tweaks.isEmpty {
                Text("No dylib tweaks queued. Tap '+ Add Tweak' to inject dynamic libraries.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.vertical, 4)
            } else {
                ForEach($signerViewModel.tweaks) { $tweak in
                    HStack {
                        Image(systemName: "puzzlepiece.extension.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.purple)
                        Text(tweak.filename)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        Toggle("", isOn: $tweak.isEnabled)
                            .labelsHidden()
                            .tint(.purple)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        )
    }
    
    // MARK: - 7. Compatibility Card (zsign CLI flags)
    
    private var compatibilityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ZSIGN COMPATIBILITY & HARNESSING")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
            Toggle("[-E] Strip App Extensions (PlugIns/Extensions)", isOn: $stripExtensions)
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
            
            Toggle("[-a] Ad-Hoc Signature Mode (TrollStore / Jailbreak)", isOn: $adhocMode)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .tint(.cyan)
            
            Toggle("[✓] Auto-Install via Wireless OTA After Signing", isOn: $autoInstallAfterSigning)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .tint(.green)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        )
    }
    
    // MARK: - 8. Live ZSign CLI Command Inspector
    
    private var zsignCommandCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                    Text("ZSIGN CLI INVOCATION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                }
                
                Spacer()
                
                Button(action: {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = generatedZSignCommand
                    #endif
                    SoundAndHapticManager.shared.triggerHaptic(.light)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Command")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            
            Text(generatedZSignCommand)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        )
    }
    
    private var generatedZSignCommand: String {
        var parts = ["zsign"]
        if adhocMode {
            parts.append("-a")
        } else {
            if let cert = certManager.activeCertificate {
                parts.append("-k \(cert.name.replacingOccurrences(of: " ", with: "_")).p12")
                // Never surface a certificate password in UI or clipboard output.
                // The signer reads the identity from its protected import store.
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
    
    // MARK: - 9. Sign Action Button
    
    private var signActionButton: some View {
        Button(action: executeSigning) {
            HStack(spacing: 8) {
                Image(systemName: isReadyToSign ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                    .font(.system(size: 16, weight: .black))
                Text(isReadyToSign ? (signerViewModel.selectedEngineMode == .cloudServer ? "SIGN WITH ZSIGN CLOUD" : "SIGN SECURELY ON DEVICE") : "COMPLETE PREFLIGHT TO SIGN")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
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
        .accessibilityHint(isReadyToSign ? "Starts the protected signing workflow" : "Resolve the preflight checks before signing")
    }
    
    // MARK: - 9. Recent Signed App Card
    
    private func recentSignedCard(_ app: SignedApp) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Text("READY FOR DEPLOYMENT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                Spacer()
                Text("1-Tap Install Available")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text(app.bundleIdentifier)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                
                // Wireless Install
                Button(action: {
                    signerViewModel.installApp(app)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.app.fill")
                        Text("Install")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.0, green: 1.0, blue: 0.64))
                    .clipShape(Capsule())
                }
                
                // TrollStore
                Button(action: {
                    signerViewModel.installWithTrollStore(app)
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.cyan)
                        .padding(7)
                        .background(Color.cyan.opacity(0.15))
                        .clipShape(Circle())
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.green.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.green.opacity(0.25), lineWidth: 0.8))
        )
    }
    
    // MARK: - Logic
    
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
