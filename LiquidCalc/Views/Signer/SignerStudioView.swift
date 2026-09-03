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
    @State private var injectTaskAllow: Bool = false
    @State private var enableFileSharing: Bool = true
    
    @State private var showIpaPicker: Bool = false
    @State private var showDylibPicker: Bool = false
    @State private var showSuccessToast: Bool = false
    
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
                
                engineSelectorCard
                
                sourceAppCard
                
                customizationCard
                
                certificateSelectionCard
                
                dylibInjectionCard
                
                compatibilityCard
                
                signActionButton
                
                if let lastSigned = signerViewModel.apps.first(where: { $0.status == .signed }) {
                    recentSignedCard(lastSigned)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
        .onAppear {
            if selectedApp == nil {
                selectedApp = signerViewModel.apps.first
                syncFieldsWithSelectedApp()
            }
        }
        .fileImporter(
            isPresented: $showIpaPicker,
            allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data, .zip, .data]
        ) { result in
            if case .success(let url) = result {
                signerViewModel.importIPA(from: url)
                if let newest = signerViewModel.apps.first {
                    selectedApp = newest
                    syncFieldsWithSelectedApp()
                }
            }
        }
        .fileImporter(
            isPresented: $showDylibPicker,
            allowedContentTypes: [UTType(filenameExtension: "dylib") ?? .data, .data]
        ) { result in
            if case .success(let url) = result {
                signerViewModel.importDylib(from: url)
            }
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
                    Text("SIGNER STUDIO")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(LinearGradient(colors: [.cyan, .white], startPoint: .leading, endPoint: .trailing))
                }
                Text("Enterprise On-Device & Cloud Sideloading Workbench")
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
    
    // MARK: - 2. Engine Selector Card
    
    private var engineSelectorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SIGNING ENGINE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
            HStack(spacing: 8) {
                engineButton(
                    title: "On-Device Swift",
                    subtitle: "Zero network • Pure Swift crypto",
                    icon: "cpu.fill",
                    mode: .onDevice
                )
                
                engineButton(
                    title: "Cloud Signer Server",
                    subtitle: "Remote cluster • Instant OTA",
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
            Text("SIGNING IDENTITY & PROVISION")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
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
                Button(action: { showDylibPicker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Tweak")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan)
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
    
    // MARK: - 7. Compatibility Card
    
    private var compatibilityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COMPATIBILITY & HARDENING")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
            Toggle("Strip Unsupported Extensions (PlugIns/Watch)", isOn: $stripExtensions)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .tint(.cyan)
            
            Toggle("Inject get-task-allow (Safari / LLDB Debugging)", isOn: $injectTaskAllow)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .tint(.cyan)
            
            Toggle("Enable iTunes & Finder File Sharing", isOn: $enableFileSharing)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .tint(.cyan)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        )
    }
    
    // MARK: - 8. Sign Action Button
    
    private var signActionButton: some View {
        Button(action: executeSigning) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .black))
                Text(signerViewModel.selectedEngineMode == .cloudServer ? "SIGN WITH CLOUD SERVER" : "SIGN APPLICATION NOW")
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
        .disabled(selectedApp == nil || signerViewModel.isSigning)
        .opacity(selectedApp == nil || signerViewModel.isSigning ? 0.5 : 1.0)
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
        guard let app = selectedApp else { return }
        
        let config = SigningConfig(
            customName: customName.trimmingCharacters(in: .whitespaces),
            customBundleId: customBundleId.trimmingCharacters(in: .whitespaces),
            customVersion: customVersion.trimmingCharacters(in: .whitespaces),
            certificate: certManager.activeCertificate,
            profile: certManager.activeProfile,
            dylibs: signerViewModel.tweaks.filter { $0.isEnabled },
            removeExtensions: stripExtensions
        )
        
        signerViewModel.signAppWithSelectedEngine(app: app, config: config)
    }
}
