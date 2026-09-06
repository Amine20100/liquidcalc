//
//  LiquidSignerView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Liquid Signer Hidden Vault Master View — 4-Tab Sideloading Manager
//

import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

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
    @State private var pendingP12Data: Data? = nil
    @State private var pendingP12Filename: String = ""
    @State private var p12PasswordInput = ""
    
    // Ecosystem Sheets
    @State private var showMachOInspector = false
    @State private var selectedAppForInspector: SignedApp? = nil
    @State private var showTweakCatalog = false
    @State private var showCertStoreSheet = false
    @State private var certRevocationMessage: String? = nil
    
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
                
                // 4-Tab Navigation Pill Bar (Apps, Signer, Certificates, Tools)
                vaultTabBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                
                // Active Tab Content View (Zero gesture collision with SignerStudioView swipe carousel)
                ZStack {
                    appsTab
                        .opacity(signerViewModel.selectedTab == .apps ? 1 : 0)
                        .allowsHitTesting(signerViewModel.selectedTab == .apps)
                    
                    SignerStudioView(
                        signerViewModel: signerViewModel,
                        certManager: certManager,
                        localServer: localServer
                    )
                    .opacity(signerViewModel.selectedTab == .signer ? 1 : 0)
                    .allowsHitTesting(signerViewModel.selectedTab == .signer)
                    
                    certificatesTab
                        .opacity(signerViewModel.selectedTab == .certificates ? 1 : 0)
                        .allowsHitTesting(signerViewModel.selectedTab == .certificates)
                    
                    toolsTab
                        .opacity(signerViewModel.selectedTab == .tools ? 1 : 0)
                        .allowsHitTesting(signerViewModel.selectedTab == .tools)
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: signerViewModel.selectedTab)
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
            allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data, .zip, .data, .item]
        ) { result in
            if case .success(let url) = result {
                signerViewModel.importIPA(from: url)
            }
        }
        .fileImporter(
            isPresented: $showP12Importer,
            allowedContentTypes: [UTType(filenameExtension: "p12") ?? .data, .data, .item]
        ) { result in
            if case .success(let url) = result {
                let isAccessing = url.startAccessingSecurityScopedResource()
                defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    pendingP12Data = data
                    pendingP12Filename = url.lastPathComponent
                    pendingP12Url = url
                    p12PasswordInput = ""
                    showPasswordPrompt = true
                }
            }
        }
        .fileImporter(
            isPresented: $showProfileImporter,
            allowedContentTypes: [UTType(filenameExtension: "mobileprovision") ?? .data, .data, .item]
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
            allowedContentTypes: [UTType(filenameExtension: "dylib") ?? .data, .data, .item]
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
        // Ecosystem Sheets
        .sheet(isPresented: $showMachOInspector) {
            if let app = selectedAppForInspector ?? signerViewModel.apps.first {
                MachOInspectorView(app: app)
            }
        }
        .sheet(isPresented: $showTweakCatalog) {
            TweakCatalogSheetView(catalogManager: TweakCatalogManager.shared, signerViewModel: signerViewModel)
        }
        .sheet(isPresented: $showCertStoreSheet) {
            CertificateStoreView(certManager: certManager)
        }
        #if canImport(UIKit)
        .sheet(isPresented: $signerViewModel.showShareSheet) {
            if let url = signerViewModel.shareUrl {
                ShareSheet(activityItems: [url])
            }
        }
        #endif
        // P12 Password Input Alert
        .alert("Enter P12 Password", isPresented: $showPasswordPrompt) {
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
                } else if let url = pendingP12Url {
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
            Text("ZSign local OTA micro-server is dispatching '\(signerViewModel.installedAppName)'. Follow the on-screen iOS prompt to install.")
        }
    }
    
    // MARK: - Top Vault Header
    
    private var topVaultHeader: some View {
        HStack(spacing: 8) {
            // ZSign Branding
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.2))
                        .frame(width: 26, height: 26)
                    
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("LIQUID SIGNER")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text("zhlynn/zsign Sideload Manager")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.cyan.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Server Live Status Badge
            HStack(spacing: 4) {
                Circle()
                    .fill(localServer.isRunning ? Color(red: 0.0, green: 1.0, blue: 0.64) : Color.orange)
                    .frame(width: 6, height: 6)
                Text(localServer.isRunning ? "OTA :8080" : "Standby")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(localServer.isRunning ? Color(red: 0.0, green: 1.0, blue: 0.64) : .orange)
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
    
    // MARK: - 4-Tab Navigation Bar
    
    private var vaultTabBar: some View {
        HStack(spacing: 6) {
            ForEach(SignerTab.allCases) { tab in
                let isSelected = signerViewModel.selectedTab == tab
                
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
                            .font(.system(size: 12, weight: isSelected ? .bold : .semibold, design: .rounded))
                    }
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(
                                isSelected
                                    ? LinearGradient(colors: [Color.cyan.opacity(0.40), Color.blue.opacity(0.35)], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.white.opacity(0.04), Color.white.opacity(0.04)], startPoint: .leading, endPoint: .trailing)
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected ? Color.cyan.opacity(0.65) : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.black.opacity(0.4)))
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.8))
    }
    
    // MARK: - Tab 1: Apps Tab (Installed & Signed Apps Library)
    
    private var appsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Action Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sideloaded Apps")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("\(signerViewModel.apps.count) package(s) registered")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    // Prominent "+ Sign New App" Action Button
                    Button(action: {
                        signerViewModel.startNewSigning()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "plus.circle.fill")
                            Text("Sign New App")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
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
                        .shadow(color: Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.3), radius: 6)
                    }
                    .buttonStyle(.plain)
                    
                    // Import IPA Button
                    Button(action: {
                        SoundAndHapticManager.shared.triggerHaptic(.light)
                        showIpaImporter = true
                    }) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.cyan)
                            .padding(8)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                
                // Apps Cards List or Empty State
                if signerViewModel.apps.isEmpty {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.cyan.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "arrow.down.app.dashed")
                                .font(.system(size: 32))
                                .foregroundColor(.cyan)
                        }
                        .padding(.top, 40)
                        
                        Text("No Sideloaded Apps Yet")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Import any .ipa or .zip archive to sign, inject dylib tweaks, and install wirelessly on this iPhone.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                        
                        Button(action: {
                            signerViewModel.startNewSigning()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.shield.fill")
                                Text("Open Signer Studio")
                            }
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
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
                        .padding(.top, 8)
                    }
                } else {
                    VStack(spacing: 12) {
                        ForEach(signerViewModel.apps) { app in
                            appLibraryCard(app: app)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 28)
        }
    }
    
    private func appLibraryCard(app: SignedApp) -> some View {
        VStack(spacing: 12) {
            // App Information Row
            HStack(spacing: 12) {
                // App Icon Preview with Dynamic Monogram
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.4), Color.purple.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
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
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.85))
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text("v\(app.version)")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.55))
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text(app.formattedSize)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.55))
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text(app.formattedSigningDate)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                
                Spacer()
                
                // Expiration / Status Pill
                VStack(alignment: .trailing, spacing: 4) {
                    if app.status == .signed {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(app.formattedExpiration.contains("Expired") ? Color.red : Color(red: 0.0, green: 1.0, blue: 0.64))
                                .frame(width: 6, height: 6)
                            Text(app.formattedExpiration)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(app.formattedExpiration.contains("Expired") ? .red : Color(red: 0.0, green: 1.0, blue: 0.64))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill((app.formattedExpiration.contains("Expired") ? Color.red : Color.green).opacity(0.15))
                        )
                    } else {
                        Text(app.status.rawValue)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.cyan.opacity(0.18)))
                    }
                }
            }
            
            // Injected Tweaks Tags
            if !app.injectedDylibs.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "puzzlepiece.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.purple)
                    Text("Tweaks: \(app.injectedDylibs.joined(separator: ", "))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.purple.opacity(0.9))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 2)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Action Buttons Section
            if app.status == .signed {
                // Row 1: Primary Wireless Installation Actions
                HStack(spacing: 8) {
                    Button(action: {
                        signerViewModel.installApp(app)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.app.fill")
                            Text("Install via OTA")
                        }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.0, green: 1.0, blue: 0.64), Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.3), radius: 6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        signerViewModel.installWithTrollStore(app)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .bold))
                            Text("TrollStore")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 10)
                        .frame(height: 38)
                        .background(Color.cyan.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.3), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
                
                // Row 2: Secondary Actions (Re-sign, Share IPA, Delete)
                HStack(spacing: 8) {
                    Button(action: {
                        signerViewModel.selectAppForSigning(app)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "signature")
                            Text("Re-sign")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Color.cyan.opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.cyan.opacity(0.3), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        signerViewModel.shareApp(app)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share IPA")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Color.purple.opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.purple.opacity(0.3), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        signerViewModel.deleteApp(app)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 36, height: 34)
                            .background(Color.red.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Unsigned / Ready to sign: Sign App + Share IPA + Delete
                HStack(spacing: 8) {
                    Button(action: {
                        signerViewModel.selectAppForSigning(app)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "signature")
                            Text("Sign App")
                        }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.0, green: 1.0, blue: 0.64), Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.3), radius: 6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        signerViewModel.shareApp(app)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share IPA")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)
                        .frame(height: 38)
                        .padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.purple.opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.3), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        signerViewModel.deleteApp(app)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 36, height: 38)
                            .background(Color.red.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            app.status == .signed ? Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.35) : Color.white.opacity(0.12),
                            lineWidth: 0.8
                        )
                )
        )
    }
    
    // MARK: - Tab 3: Certificates Tab (Apple Wallet-Style Holographic Passes)
    
    private var certificatesTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header & 1-Tap Import Action Bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Certificates & Passes")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Apple Developer P12 identities & provisioning")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Button(action: {
                            SoundAndHapticManager.shared.triggerHaptic(.light)
                            showP12Importer = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text(".p12")
                            }
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.0, green: 1.0, blue: 0.64))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            SoundAndHapticManager.shared.triggerHaptic(.light)
                            showProfileImporter = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Profile")
                            }
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.18))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        Menu {
                            Button("Open Certificate Store Sheet...") {
                                showCertStoreSheet = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.cyan)
                                .padding(6)
                                .background(Color.cyan.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                
                if let msg = certRevocationMessage {
                    Text(msg)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 16)
                }
                
                // Apple Wallet-Style Passes Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("ACTIVE IDENTITIES (\(certManager.certificates.count))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 16)
                    
                    ForEach(certManager.certificates) { cert in
                        walletPassCard(cert: cert)
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
            .padding(.bottom, 28)
        }
    }
    
    // Apple Wallet Holographic Pass Card
    private func walletPassCard(cert: SigningCertificate) -> some View {
        let isActive = certManager.activeCertificate?.id == cert.id
        
        return VStack(alignment: .leading, spacing: 12) {
            // Pass Top Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                    Text("APPLE DEVELOPER PASS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                }
                
                Spacer()
                
                if isActive {
                    Text("ACTIVE IDENTITY")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.0, green: 1.0, blue: 0.64))
                        .clipShape(Capsule())
                }
            }
            
            // Pass Center Identity
            VStack(alignment: .leading, spacing: 3) {
                Text(cert.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(cert.commonName)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                
                Text("TEAM ID: \(cert.teamIdentifier)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.9))
            }
            .padding(.top, 4)
            
            Divider().background(Color.white.opacity(0.12))
            
            // Pass Footer
            HStack {
                // Expiration Pill
                HStack(spacing: 5) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 10))
                    Text(cert.isExpired ? "EXPIRED" : "\(cert.daysRemaining) days remaining")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundColor(cert.isExpired ? .red : (cert.daysRemaining > 30 ? Color(red: 0.0, green: 1.0, blue: 0.64) : .orange))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                
                // Revocation Status
                Text(cert.isRevoked ? "REVOKED" : "VALID")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(cert.isRevoked ? .red : Color(red: 0.0, green: 1.0, blue: 0.64))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background((cert.isRevoked ? Color.red : Color.green).opacity(0.15))
                    .clipShape(Capsule())
                
                Spacer()
                
                // Check Revocation Button
                Button(action: {
                    Task {
                        let isRevoked = await certManager.checkRevocationStatus(for: cert)
                        await MainActor.run {
                            certRevocationMessage = isRevoked ? "⚠️ '\(cert.name)' has been revoked" : "✓ '\(cert.name)' is valid"
                            SoundAndHapticManager.shared.triggerHaptic(isRevoked ? .error : .success)
                        }
                    }
                }) {
                    Text("Check")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                // Set Active Action (if not already active)
                if !isActive {
                    Button(action: {
                        CertificateManager.shared.activeCertificate = cert
                        SoundAndHapticManager.shared.triggerHaptic(.selection)
                    }) {
                        Text("Use")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.0, green: 1.0, blue: 0.64))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.10, blue: 0.16),
                            Color(red: 0.06, green: 0.07, blue: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Holographic Iridescent Shimmer Border
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: isActive
                                    ? [Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.8), Color.cyan.opacity(0.7)]
                                    : [Color.white.opacity(0.15), Color.purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isActive ? 1.5 : 0.8
                        )
                )
                .shadow(color: (isActive ? Color.cyan : Color.black).opacity(0.25), radius: 10)
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
    
    // MARK: - Tab 4: Tools & Settings Tab (Catalog, Inspector, Terminal, Vault PIN)
    
    private var toolsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tools & Security")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Dylibs catalog, Mach-O inspector, terminal & vault security")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                
                // Section 1: Tweaks & Dylibs Catalog
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "puzzlepiece.extension.fill")
                                .foregroundColor(.purple)
                            Text("TWEAKS & DYLIBS CATALOG (\(signerViewModel.tweaks.count))")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.purple)
                        }
                        Spacer()
                        
                        Button(action: { showTweakCatalog = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "cart.fill")
                                Text("Tweak Store")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.18))
                            .clipShape(Capsule())
                        }
                        
                        Button(action: { showDylibImporter = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Import Dylib")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.14))
                            .clipShape(Capsule())
                        }
                    }
                    
                    if signerViewModel.tweaks.isEmpty {
                        Text("No dylib tweaks installed yet. Import custom .dylib binaries to inject modifications.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        VStack(spacing: 6) {
                            ForEach(signerViewModel.tweaks) { tweak in
                                HStack {
                                    Image(systemName: "puzzlepiece.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.purple)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(tweak.filename)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.white)
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
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                        )
                )
                .padding(.horizontal, 16)
                
                // Section 2: Mach-O Binary Inspector Launcher
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "cpu.fill")
                            .foregroundColor(.cyan)
                        Text("MACH-O BINARY INSPECTOR")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                        Spacer()
                    }
                    
                    Text("Deep inspection of ARM64 slices, FairPlay DRM encryption status, load commands, linked dynamic libraries, and entitlements.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    
                    HStack {
                        if !signerViewModel.apps.isEmpty {
                            Menu {
                                ForEach(signerViewModel.apps) { app in
                                    Button(app.name) {
                                        selectedAppForInspector = app
                                        showMachOInspector = true
                                    }
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Text("Select Target App")
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 9))
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.cyan.opacity(0.15))
                                .clipShape(Capsule())
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            selectedAppForInspector = signerViewModel.apps.first
                            showMachOInspector = true
                        }) {
                            HStack(spacing: 4) {
                                Text("Launch Inspector")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.cyan)
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
                .padding(.horizontal, 16)
                
                // Section 3: Live Terminal Execution Log Stream
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            Text("LIVE TERMINAL EXECUTION STREAM")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        Spacer()
                        
                        Button(action: {
                            signerViewModel.copyAllLogsToClipboard()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.cyan.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        
                        Button(action: {
                            signerViewModel.clearLogs()
                        }) {
                            Text("Clear")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Capsule())
                        }
                    }
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(signerViewModel.logs) { log in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text(timeFormatter.string(from: log.timestamp))
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.35))
                                        Text(log.text)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(colorForLogLevel(log.level))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .id(log.id)
                                }
                            }
                            .padding(10)
                        }
                        .frame(height: 140)
                        .background(Color.black.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.green.opacity(0.25), lineWidth: 1)
                        )
                        .onChange(of: signerViewModel.logs.count) { _, _ in
                            if let last = signerViewModel.logs.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
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
                .padding(.horizontal, 16)
                
                // Section 4: Stealth Calculator PIN & Biometric Vault Security
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                        Text("STEALTH PIN & BIOMETRIC VAULT SECURITY")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    
                    // Secret PIN
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current Secret PIN: \(calculatorViewModel.secretPIN)=")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            TextField("New PIN (e.g. 7777)", text: $newPinInput)
                                .font(.system(size: 13, design: .monospaced))
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
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.cyan)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        if showPinSuccessToast {
                            Text("✓ Secret PIN updated! Type it followed by '=' on the calculator.")
                                .font(.system(size: 11))
                                .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // Biometric Face ID / Touch ID Security
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Image(systemName: "faceid")
                                        .font(.system(size: 14))
                                        .foregroundColor(calculatorViewModel.isBiometricAuthEnabled ? Color(red: 0.0, green: 1.0, blue: 0.64) : .white.opacity(0.6))
                                    Text("Face ID / Touch ID Vault Security")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                Text("Require biometric verification when accessing Liquid Signer")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { calculatorViewModel.isBiometricAuthEnabled },
                                set: { enabled in
                                    calculatorViewModel.isBiometricAuthEnabled = enabled
                                    SoundAndHapticManager.shared.triggerHaptic(enabled ? .success : .light)
                                }
                            ))
                            .labelsHidden()
                            .tint(Color(red: 0.0, green: 1.0, blue: 0.64))
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
                .padding(.horizontal, 16)
                
                // Section 5: Signer Servers & Distribution Suite
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "server.rack")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                        Text("SIGNER SERVERS & DISTRIBUTION")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    
                    // Local OTA Server
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(localServer.isRunning ? Color(red: 0.0, green: 1.0, blue: 0.64) : Color.gray)
                                        .frame(width: 8, height: 8)
                                    Text("Local OTA Server")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                Text("Micro HTTP server for 1-tap wireless installation")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { localServer.isRunning },
                                set: { running in
                                    if running {
                                        localServer.start()
                                        SoundAndHapticManager.shared.triggerHaptic(.success)
                                    } else {
                                        localServer.stop()
                                        SoundAndHapticManager.shared.triggerHaptic(.light)
                                    }
                                }
                            ))
                            .labelsHidden()
                            .tint(Color(red: 0.0, green: 1.0, blue: 0.64))
                        }
                        
                        if localServer.isRunning {
                            HStack(spacing: 12) {
                                Label("IP: \(localServer.localIPAddress):8080", systemImage: "network")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.cyan)
                                
                                Label("Clients: \(localServer.activeClients)", systemImage: "person.2.fill")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Label(ByteCountFormatter.string(fromByteCount: localServer.totalBytesServed, countStyle: .file), systemImage: "arrow.up.arrow.down")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
                    
                    // Cloud Signer Server
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Circle().fill(Color.purple).frame(width: 8, height: 8)
                                    Text("Liquid Cloud Signer Gateway")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                Text("Remote cloud signing and Apple manifest generation")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                            
                            Link(destination: URL(string: "https://liquidcalc-backend.vercel.app")!) {
                                HStack(spacing: 4) {
                                    Text("Online")
                                        .font(.system(size: 10, weight: .bold))
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 8))
                                }
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.18))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
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
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 28)
        }
    }
    
    // MARK: - Helpers & Background
    
    private var ambientNeonBackground: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.16), Color.cyan.opacity(0.03), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 240
                    )
                )
                .frame(width: 480, height: 480)
                .offset(x: -80, y: -160)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.16), Color.purple.opacity(0.03), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 260
                    )
                )
                .frame(width: 520, height: 520)
                .offset(x: 100, y: 180)
        }
        .drawingGroup()
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
