//
//  IPADetailSignSheet.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Pre-signing Customization, Cloned ID & Dylib Injection Sheet
//

import SwiftUI
import UniformTypeIdentifiers

public struct IPADetailSignSheet: View {
    @Bindable var signerViewModel: LiquidSignerViewModel
    let app: SignedApp
    
    @State private var customName: String = ""
    @State private var customBundleId: String = ""
    @State private var customVersion: String = ""
    @State private var removeExtensions: Bool = true
    @State private var enableDebugging: Bool = true
    @State private var selectedCert: SigningCertificate?
    @State private var selectedProfile: ProvisioningProfile?
    @State private var activeTweaks: Set<UUID> = []
    @State private var showDylibImporter: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    public init(signerViewModel: LiquidSignerViewModel, app: SignedApp) {
        self.signerViewModel = signerViewModel
        self.app = app
        _customName = State(initialValue: app.name)
        _customBundleId = State(initialValue: app.bundleIdentifier)
        _customVersion = State(initialValue: app.version)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.09)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // App Header Preview Card
                        appHeaderCard
                        
                        // Metadata & App Cloning
                        metadataSection
                        
                        // Certificate & Mobileprovision Section
                        certificateSection
                        
                        // Dylib Tweaks Injection Section
                        dylibSection
                        
                        // Sideloading Compatibility & Options
                        compatibilitySection
                        
                        // Sign IPA Action Button
                        signActionButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Sign Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
            .fileImporter(
                isPresented: $showDylibImporter,
                allowedContentTypes: [UTType(filenameExtension: "dylib") ?? .item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let firstUrl = urls.first {
                        signerViewModel.importDylib(from: firstUrl)
                    }
                case .failure(let error):
                    signerViewModel.appendLog("Dylib selection failed: \(error.localizedDescription)", .error)
                }
            }
            .onAppear {
                if selectedCert == nil {
                    selectedCert = CertificateManager.shared.activeCertificate
                }
                if selectedProfile == nil {
                    selectedProfile = CertificateManager.shared.activeProfile
                }
                activeTweaks = Set(signerViewModel.tweaks.filter { $0.isEnabled }.map { $0.id })
            }
        }
    }
    
    // MARK: - App Header Card
    
    private var appHeaderCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.35), .purple.opacity(0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.cyan.opacity(0.5), lineWidth: 1.2)
                    )
                
                Image(systemName: "app.dashed")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(customName.isEmpty ? app.name : customName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(customBundleId.isEmpty ? app.bundleIdentifier : customBundleId)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.8))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("Size: \(app.formattedSize)")
                    Text("•")
                    Text("Arch: arm64")
                }
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
        )
    }
    
    // MARK: - Metadata Section
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("App Metadata & Cloning", icon: "pencil.and.outline")
                Spacer()
                
                // Quick Clone Button
                Button(action: {
                    SoundAndHapticManager.shared.triggerHaptic(.selection)
                    if !customBundleId.hasSuffix(".cloned") {
                        customBundleId += ".cloned"
                    }
                    if !customName.hasSuffix(" (Clone)") {
                        customName += " (Clone)"
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.square.on.square")
                            .font(.system(size: 10))
                        Text("Clone ID")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            
            VStack(spacing: 10) {
                customInputField(title: "App Display Name", text: $customName, placeholder: app.name)
                customInputField(title: "Bundle Identifier", text: $customBundleId, placeholder: app.bundleIdentifier)
                customInputField(title: "Version", text: $customVersion, placeholder: app.version)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
    
    // MARK: - Certificate & Profile Section
    
    private var certificateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Certificate & Provisioning", icon: "lock.shield.fill")
            
            let certs = CertificateManager.shared.certificates
            VStack(spacing: 8) {
                // Certificate Selector
                Menu {
                    ForEach(certs) { cert in
                        Button(action: {
                            selectedCert = cert
                            SoundAndHapticManager.shared.triggerHaptic(.selection)
                        }) {
                            HStack {
                                Text("\(cert.name) (\(cert.daysRemaining)d left)")
                                if selectedCert?.id == cert.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Signing Certificate")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(selectedCert?.isExpired == true ? Color.red : Color(red: 0.0, green: 1.0, blue: 0.64))
                                    .frame(width: 7, height: 7)
                                Text(selectedCert?.name ?? "Default Ad-Hoc Identity")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11))
                            .foregroundColor(.cyan)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                }
                
                // Profile Selector
                let profiles = CertificateManager.shared.profiles
                Menu {
                    Button(action: {
                        selectedProfile = nil
                        SoundAndHapticManager.shared.triggerHaptic(.selection)
                    }) {
                        HStack {
                            Text("Auto-Generate Universal Wildcard Profile")
                            if selectedProfile == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    ForEach(profiles) { profile in
                        Button(action: {
                            selectedProfile = profile
                            SoundAndHapticManager.shared.triggerHaptic(.selection)
                        }) {
                            HStack {
                                Text("\(profile.name) [\(profile.appIdentifier)]")
                                if selectedProfile?.id == profile.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Provisioning Profile")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                            
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.purple)
                                Text(selectedProfile?.name ?? "Universal Ad-Hoc Wildcard (Auto)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11))
                            .foregroundColor(.cyan)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
    
    // MARK: - Dylib Tweaks Section
    
    private var dylibSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Inject Dylib Tweaks (\(signerViewModel.tweaks.count))", icon: "puzzlepiece.extension.fill")
                Spacer()
                
                Button(action: {
                    showDylibImporter = true
                    SoundAndHapticManager.shared.triggerHaptic(.light)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                        Text("Add Tweak")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.18))
                    .clipShape(Capsule())
                }
            }
            
            if signerViewModel.tweaks.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.system(size: 12))
                    Text("No tweaks imported yet. Tap 'Add Tweak' above to inject .dylib tweaks into Mach-O headers.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.vertical, 4)
            } else {
                ForEach(signerViewModel.tweaks) { tweak in
                    let isSelected = activeTweaks.contains(tweak.id)
                    Button(action: {
                        SoundAndHapticManager.shared.triggerHaptic(.selection)
                        if isSelected {
                            activeTweaks.remove(tweak.id)
                        } else {
                            activeTweaks.insert(tweak.id)
                        }
                    }) {
                        HStack {
                            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                .font(.system(size: 18))
                                .foregroundColor(isSelected ? .cyan : .white.opacity(0.4))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tweak.filename)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text("Load: @executable_path/Frameworks/\(tweak.filename) (\(tweak.formattedSize))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(isSelected ? 0.10 : 0.04)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
    
    // MARK: - Compatibility & Advanced Sideloading
    
    private var compatibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Sideloading Compatibility", icon: "gearshape.2.fill")
            
            VStack(spacing: 8) {
                Toggle(isOn: $removeExtensions) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Strip Unsupported Extensions")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Removes Watch/PlugIns to prevent signing errors on free Apple IDs.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .tint(.cyan)
                
                Divider().background(Color.white.opacity(0.08))
                
                Toggle(isOn: $enableDebugging) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable get-task-allow")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Enables Safari Web Inspector & LLDB debugging.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .tint(.cyan)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
    
    // MARK: - Action Button
    
    private var signActionButton: some View {
        Button(action: {
            dismiss()
            let chosenDylibs = signerViewModel.tweaks.filter { activeTweaks.contains($0.id) }
            let config = SigningConfig(
                customName: customName,
                customBundleId: customBundleId,
                customVersion: customVersion,
                certificate: selectedCert ?? CertificateManager.shared.activeCertificate,
                profile: selectedProfile ?? CertificateManager.shared.activeProfile,
                dylibs: chosenDylibs,
                removeExtensions: removeExtensions
            )
            signerViewModel.startSigning(app: app, config: config)
        }) {
            HStack(spacing: 8) {
                Image(systemName: "signature")
                    .font(.system(size: 16, weight: .bold))
                Text("Sign IPA Now")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
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
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.cyan.opacity(0.5), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .padding(.bottom, 24)
    }
    
    // MARK: - Helpers
    
    private func sectionTitle(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.cyan)
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
        }
    }
    
    private func customInputField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
            
            TextField(placeholder, text: text)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 0.8))
        }
    }
}
