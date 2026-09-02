//
//  LiquidSignerView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Liquid Signer Hidden Vault Master View
//

import SwiftUI
import UniformTypeIdentifiers

public struct LiquidSignerView: View {
    @Bindable var calculatorViewModel: CalculatorViewModel
    @State private var signerViewModel = LiquidSignerViewModel()
    @Bindable private var certManager = CertificateManager.shared
    @Bindable private var localServer = LocalInstallServer.shared
    
    // File Importers
    @State private var showIpaImporter = false
    @State private var showP12Importer = false
    @State private var showProfileImporter = false
    @State private var showDylibImporter = false
    
    // P12 Password Prompt Sheet
    @State private var showPasswordPrompt = false
    @State private var pendingP12Url: URL? = nil
    @State private var p12PasswordInput = ""
    
    // Settings PIN Sheet
    @State private var newPinInput = ""
    @State private var showPinSuccessToast = false
    @State private var hasRevealedVault = false
    
    public init(calculatorViewModel: CalculatorViewModel) {
        self.calculatorViewModel = calculatorViewModel
    }
    
    public var body: some View {
        ZStack {
            // Cyberpunk Dark Canvas Base
            Color(red: 0.04, green: 0.05, blue: 0.08)
                .ignoresSafeArea()
            
            // Living Ambient Neon Blobs
            ambientNeonBackground
            
            VStack(spacing: 0) {
                // Top Stealth Header Bar
                topVaultHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                
                // Cyberpunk Navigation Pill Bar
                vaultTabBar
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                
                // Active Tab Content
                TabView(selection: $signerViewModel.selectedTab) {
                    appsTab
                        .tag(SignerTab.apps)
                    
                    certificatesTab
                        .tag(SignerTab.certificates)
                    
                    tweaksTab
                        .tag(SignerTab.tweaks)
                    
                    terminalTab
                        .tag(SignerTab.terminal)
                    
                    settingsTab
                        .tag(SignerTab.settings)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .scaleEffect(hasRevealedVault ? 1.0 : 0.90)
            .opacity(hasRevealedVault ? 1.0 : 0.0)
            .animation(.spring(response: 0.40, dampingFraction: 0.76), value: hasRevealedVault)
            .onAppear {
                hasRevealedVault = true
            }
            
            // Signing Progress / Completion Glass Overlay
            if signerViewModel.isSigning || (signerViewModel.signingProgress >= 1.0 && signerViewModel.activeSigningApp != nil) {
                SigningProgressOverlay(signerViewModel: signerViewModel) {
                    withAnimation {
                        signerViewModel.signingProgress = 0.0
                        signerViewModel.activeSigningApp = nil
                    }
                }
                .transition(.opacity)
            }
        }
        // File Pickers
        .fileImporter(
            isPresented: $showIpaImporter,
            allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data, .zip, .data]
        ) { result in
            if case .success(let url) = result {
                signerViewModel.importIPA(from: url)
            }
        }
        .fileImporter(
            isPresented: $showP12Importer,
            allowedContentTypes: [UTType(filenameExtension: "p12") ?? .data, .data]
        ) { result in
            if case .success(let url) = result {
                pendingP12Url = url
                p12PasswordInput = ""
                showPasswordPrompt = true
            }
        }
        .fileImporter(
            isPresented: $showProfileImporter,
            allowedContentTypes: [UTType(filenameExtension: "mobileprovision") ?? .data, .data]
        ) { result in
            if case .success(let url) = result {
                do {
                    _ = try certManager.importProvisioningProfile(from: url)
                    signerViewModel.appendLog("✓ Imported provisioning profile: \(url.lastPathComponent)", .success)
                    SoundAndHapticManager.shared.triggerHaptic(.success)
                } catch {
                    signerViewModel.appendLog("Error importing profile: \(error.localizedDescription)", .error)
                    SoundAndHapticManager.shared.triggerHaptic(.error)
                }
            }
        }
        .fileImporter(
            isPresented: $showDylibImporter,
            allowedContentTypes: [UTType(filenameExtension: "dylib") ?? .data, .data]
        ) { result in
            if case .success(let url) = result {
                signerViewModel.importDylib(from: url)
            }
        }
        // Pre-sign Customization Sheet
        .sheet(item: $signerViewModel.selectedAppForConfig) { app in
            IPADetailSignSheet(signerViewModel: signerViewModel, app: app)
                .presentationDetents([.large])
        }
        // P12 Password Input Alert
        .alert("Enter P12 Password", isPresented: $showPasswordPrompt) {
            SecureField("Password (or leave blank)", text: $p12PasswordInput)
            Button("Import") {
                if let url = pendingP12Url {
                    do {
                        _ = try certManager.importP12(from: url, password: p12PasswordInput)
                        signerViewModel.appendLog("✓ Imported certificate: \(url.lastPathComponent)", .success)
                        SoundAndHapticManager.shared.triggerHaptic(.success)
                    } catch {
                        signerViewModel.appendLog("Failed importing certificate: \(error.localizedDescription)", .error)
                        SoundAndHapticManager.shared.triggerHaptic(.error)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter the decryption password for this PKCS#12 (.p12) identity.")
        }
        // 1-Tap Install Triggered Notification Alert
        .alert("Installation Started", isPresented: $signerViewModel.showInstallAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Liquid Signer local OTA server is dispatching '\(signerViewModel.installedAppName)'. Follow the on-screen iOS prompt to install.")
        }
    }
    
    // MARK: - Top Vault Header
    
    private var topVaultHeader: some View {
        HStack(spacing: 8) {
            // Stealth Branding
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("LIQUID SIGNER")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text("On-Device iOS Sideloading")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.cyan.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Server Live Status Badge
            HStack(spacing: 4) {
                Circle()
                    .fill(localServer.isRunning ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(localServer.isRunning ? "OTA :8080" : "Standby")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(localServer.isRunning ? .green : .orange)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
            
            // Stealth Exit / Lock Button
            Button(action: {
                SoundAndHapticManager.shared.triggerHaptic(.medium)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    calculatorViewModel.showLiquidSigner = false
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                    Text("Lock & Exit")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [Color.cyan, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color.cyan.opacity(0.4), radius: 6)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Tab Bar
    
    private var vaultTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(SignerTab.allCases) { tab in
                    Button(action: {
                        SoundAndHapticManager.shared.triggerHaptic(.selection)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            signerViewModel.selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(signerViewModel.selectedTab == tab ? .white : .white.opacity(0.5))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(
                                    signerViewModel.selectedTab == tab
                                        ? Color.cyan.opacity(0.35)
                                        : Color.white.opacity(0.05)
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    signerViewModel.selectedTab == tab
                                        ? Color.cyan.opacity(0.6)
                                        : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
        .background(Capsule().fill(Color.black.opacity(0.3)))
    }
    
    // MARK: - Tab 1: Apps & Signing
    
    private var appsTab: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Import Action Banner
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("IPA Apps Library")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("\(signerViewModel.apps.count) package(s) available")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    
                    Button(action: {
                        SoundAndHapticManager.shared.triggerHaptic(.light)
                        showIpaImporter = true
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
                .padding(.horizontal, 16)
                .padding(.top, 4)
                
                // Apps List
                if signerViewModel.apps.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.top, 30)
                        Text("No IPAs Imported Yet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Import any .ipa file from iCloud Drive or On My iPhone to sign and install.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    ForEach(signerViewModel.apps) { app in
                        appCard(app: app)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
    }
    
    private func appCard(app: SignedApp) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // App Icon Placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.4), Color.purple.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    Image(systemName: "app.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(app.bundleIdentifier)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.85))
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text("v\(app.version)")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text(app.formattedSize)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                        
                        if !app.injectedDylibs.isEmpty {
                            Text("• \(app.injectedDylibs.count) tweak(s)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.purple.opacity(0.9))
                        }
                    }
                }
                
                Spacer()
                
                // Status Badge
                Text(app.status.rawValue)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(app.status == .signed ? Color(red: 0.0, green: 1.0, blue: 0.64) : .cyan)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill((app.status == .signed ? Color.green : Color.cyan).opacity(0.18))
                    )
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Action Buttons Row
            HStack(spacing: 8) {
                // Sign / Re-sign Button
                Button(action: {
                    SoundAndHapticManager.shared.triggerHaptic(.medium)
                    signerViewModel.selectedAppForConfig = app
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "signature")
                        Text(app.status == .signed ? "Re-sign" : "Sign IPA")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cyan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.cyan.opacity(0.15)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                
                // 1-Tap Direct Install
                if app.status == .signed {
                    Button(action: {
                        signerViewModel.installApp(app)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.app.fill")
                            Text("Install")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color(red: 0.0, green: 1.0, blue: 0.64))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                
                // Share / Export
                Button(action: {
                    signerViewModel.shareApp(app)
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 34, height: 30)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                // Delete
                Button(action: {
                    signerViewModel.deleteApp(app)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: 34, height: 30)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                )
        )
    }
    
    // MARK: - Tab 2: Certificates & Profiles
    
    private var certificatesTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header & Import Actions
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Certificates & Profiles")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Apple P12 identities & provisioning")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    
                    Menu {
                        Button("Import .p12 Certificate") {
                            showP12Importer = true
                        }
                        Button("Import .mobileprovision") {
                            showProfileImporter = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Cert")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.cyan)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                
                // Certificates Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("P12 CERTIFICATES (\(certManager.certificates.count))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 16)
                    
                    ForEach(certManager.certificates) { cert in
                        certificateCard(cert: cert)
                    }
                    .padding(.horizontal, 16)
                }
                
                // Provisioning Profiles Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("PROVISIONING PROFILES (\(certManager.profiles.count))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 16)
                    
                    ForEach(certManager.profiles) { profile in
                        profileCard(profile: profile)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
    }
    
    private func certificateCard(cert: SigningCertificate) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 24))
                .foregroundColor(cert.isExpired ? .red : Color(red: 0.0, green: 1.0, blue: 0.64))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(cert.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(cert.commonName)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                
                Text(cert.isExpired ? "EXPIRED" : "\(cert.daysRemaining) days remaining")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(cert.isExpired ? .red : .cyan)
            }
            
            Spacer()
            
            if certManager.activeCertificate?.id == cert.id {
                Text("ACTIVE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.0, green: 1.0, blue: 0.64))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(certManager.activeCertificate?.id == cert.id ? Color.cyan.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    private func profileCard(profile: ProvisioningProfile) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.badge.checkmark")
                .font(.system(size: 22))
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("App ID: \(profile.appIdentifier)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.purple.opacity(0.85))
                    .lineLimit(1)
            }
            
            Spacer()
            
            if profile.isWildcard {
                Text("WILDCARD")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
    
    // MARK: - Tab 3: Dylib Tweaks
    
    private var tweaksTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dylib Tweak Injector")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Inject dynamic frameworks into Mach-O binaries")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    
                    Button(action: {
                        SoundAndHapticManager.shared.triggerHaptic(.light)
                        showDylibImporter = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Import Dylib")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.purple)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                
                if signerViewModel.tweaks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.top, 30)
                        Text("No Tweaks Added")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Import .dylib files to bundle modifications directly into your apps during signing.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    ForEach(signerViewModel.tweaks) { tweak in
                        HStack {
                            Image(systemName: "puzzlepiece.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.purple)
                            
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
                            
                            Toggle("", isOn: Binding(
                                get: { tweak.isEnabled },
                                set: { _ in signerViewModel.toggleTweak(tweak) }
                            ))
                            .labelsHidden()
                            .tint(.purple)
                            
                            Button(action: {
                                signerViewModel.deleteTweak(tweak)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                                )
                        )
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Tab 4: Live Terminal Console
    
    private var terminalTab: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text("LIVE SIGNING LOGS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
                Spacer()
                
                Button("Clear") {
                    signerViewModel.clearLogs()
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(signerViewModel.logs) { log in
                            HStack(alignment: .top, spacing: 6) {
                                Text(timeFormatter.string(from: log.timestamp))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.35))
                                
                                Text(log.text)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(colorForLogLevel(log.level))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .id(log.id)
                        }
                    }
                    .padding(14)
                }
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .onChange(of: signerViewModel.logs.count) { _, _ in
                    if let last = signerViewModel.logs.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - Tab 5: Settings & Secret PIN
    
    private var settingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // PIN Changer Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("SECRET TRIGGER PIN")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    Text("Current PIN: \(calculatorViewModel.secretPIN)=")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        TextField("New PIN (e.g. 7777)", text: $newPinInput)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.white)
                            .keyboardType(.numberPad)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                        
                        Button("Update") {
                            if !newPinInput.isEmpty {
                                calculatorViewModel.secretPIN = newPinInput
                                SoundAndHapticManager.shared.triggerHaptic(.success)
                                newPinInput = ""
                                showPinSuccessToast = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showPinSuccessToast = false
                                }
                            }
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    if showPinSuccessToast {
                        Text("✓ Secret PIN updated! Use it followed by '=' on the calculator.")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
                )
                
                // Local OTA Server Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("LOCAL OTA INSTALL SERVER")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Micro HTTP Server")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Binds to 127.0.0.1:8080 for itms-services installation")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { localServer.isRunning },
                            set: { running in
                                if running { localServer.start() } else { localServer.stop() }
                            }
                        ))
                        .labelsHidden()
                        .tint(.green)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Helpers & Background
    
    private var ambientNeonBackground: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.cyan.opacity(0.2), Color.clear], center: .center, startRadius: 10, endRadius: 260))
                .frame(width: 360, height: 360)
                .offset(x: -80, y: -160)
                .blur(radius: 50)
            
            Circle()
                .fill(RadialGradient(colors: [Color.purple.opacity(0.2), Color.clear], center: .center, startRadius: 10, endRadius: 280))
                .frame(width: 400, height: 400)
                .offset(x: 100, y: 180)
                .blur(radius: 60)
        }
        .ignoresSafeArea()
    }
    
    private func colorForLogLevel(_ level: SignerLogMessage.LogLevel) -> Color {
        switch level {
        case .info: return .cyan.opacity(0.9)
        case .success: return Color(red: 0.0, green: 1.0, blue: 0.64)
        case .warning: return .orange
        case .error: return .red
        case .terminal: return .green
        }
    }
    
    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df
    }
}
