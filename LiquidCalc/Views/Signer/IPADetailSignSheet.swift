//
//  IPADetailSignSheet.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Pre-signing Customization & Dylib Injection Sheet
//

import SwiftUI

public struct IPADetailSignSheet: View {
    @Bindable var signerViewModel: LiquidSignerViewModel
    let app: SignedApp
    
    @State private var customName: String = ""
    @State private var customBundleId: String = ""
    @State private var customVersion: String = ""
    @State private var selectedCert: SigningCertificate?
    @State private var selectedProfile: ProvisioningProfile?
    @State private var activeTweaks: Set<UUID> = []
    
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
                        // App Header Preview
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
                                
                                Text("Size: \(app.formattedSize)")
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
                        
                        // Metadata Customization Section
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("App Metadata & Cloned ID", icon: "pencil.and.outline")
                            
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
                        
                        // Certificate & Profile Selector
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Certificate & Provisioning", icon: "lock.shield.fill")
                            
                            let certs = CertificateManager.shared.certificates
                            if certs.isEmpty {
                                Text("No P12 certificates imported. Using default self-signed ad-hoc identity.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange.opacity(0.85))
                            } else {
                                Menu {
                                    ForEach(certs) { cert in
                                        Button(action: {
                                            selectedCert = cert
                                            SoundAndHapticManager.shared.triggerHaptic(.selection)
                                        }) {
                                            HStack {
                                                Text(cert.name)
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
                                            Text(selectedCert?.name ?? certs.first?.name ?? "Select Certificate")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 12))
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
                        
                        // Dylib Tweak Injection Section
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Inject Dylib Tweaks (\(signerViewModel.tweaks.count))", icon: "puzzlepiece.extension.fill")
                            
                            if signerViewModel.tweaks.isEmpty {
                                Text("No .dylib tweaks in library. You can import tweaks from the Tweaks tab.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
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
                                                Text(tweak.formattedSize)
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.white.opacity(0.5))
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
                        
                        // Sign IPA Action Button
                        Button(action: {
                            dismiss()
                            let chosenDylibs = signerViewModel.tweaks.filter { activeTweaks.contains($0.id) }
                            let config = SigningConfig(
                                customName: customName,
                                customBundleId: customBundleId,
                                customVersion: customVersion,
                                certificate: selectedCert ?? CertificateManager.shared.activeCertificate,
                                profile: selectedProfile ?? CertificateManager.shared.activeProfile,
                                dylibs: chosenDylibs
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
                        .padding(.top, 6)
                        .padding(.bottom, 20)
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
            .onAppear {
                if selectedCert == nil {
                    selectedCert = CertificateManager.shared.activeCertificate
                }
                if selectedProfile == nil {
                    selectedProfile = CertificateManager.shared.activeProfile
                }
                // Pre-select tweaks
                activeTweaks = Set(signerViewModel.tweaks.filter { $0.isEnabled }.map { $0.id })
            }
        }
    }
    
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
