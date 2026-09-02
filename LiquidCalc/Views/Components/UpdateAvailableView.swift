//
//  UpdateAvailableView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Next-Gen Liquid Glass In-App Updater: Live Download Progress, 1-Tap Wireless OTA,
//  Liquid Signer Re-signing Handoff, and TrollStore Integration.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct UpdateAvailableView: View {
    public let release: GitHubRelease
    @Bindable public var updateManager: AppUpdateManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    @State private var selectedTab: Int = 0
    @State private var showShareSheet: Bool = false
    @State private var showSentToSignerToast: Bool = false
    
    public init(release: GitHubRelease, updateManager: AppUpdateManager = .shared) {
        self.release = release
        self.updateManager = updateManager
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Frosted cyberpunk dark background
                Color(red: 0.05, green: 0.06, blue: 0.09)
                    .ignoresSafeArea()
                
                // Ambient colorful glow orbs
                ambientOrbs
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 18) {
                            // Hero Version Header
                            heroSection
                            
                            // Segmented Navigation Pill
                            segmentedPicker
                            
                            // Content depending on selected tab
                            if selectedTab == 0 {
                                changelogTab
                            } else if selectedTab == 1 {
                                installOptionsTab
                            } else {
                                packageDetailsTab
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                    }
                    
                    // Bottom Sticky Action Bar
                    bottomActionBar
                }
            }
            .navigationTitle("LiquidCalc Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        SoundAndHapticManager.shared.triggerHaptic(.light)
                        updateManager.dismissUpdateSheet()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let fileUrl = updateManager.downloadedFileURL {
                    ShareSheet(activityItems: [fileUrl])
                }
            }
            .overlay(alignment: .top) {
                if showSentToSignerToast {
                    sentToSignerToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }
    
    // MARK: - Ambient Background Orbs
    
    private var ambientOrbs: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(Color.purple.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: 120, y: 150)
            
            Circle()
                .fill(Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: -80, y: 300)
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.cyan.opacity(0.35), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 90, height: 90)
                
                Image(systemName: "sparkles.square.filled.on.square")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.cyan, Color(red: 0.0, green: 1.0, blue: 0.64)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.cyan.opacity(0.6), radius: 12)
            }
            
            Text("Update Available")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Side-by-Side Version Evolution Pill
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Text("Current:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("v\(updateManager.currentVersionString)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.cyan)
                
                HStack(spacing: 4) {
                    Text("New:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.black.opacity(0.8))
                    Text(release.tagName)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: [Color.cyan, Color(red: 0.0, green: 1.0, blue: 0.64)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color.cyan.opacity(0.4), radius: 6)
            }
            
            if let date = release.publishedDate {
                Text("Released on \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Segmented Picker
    
    private var segmentedPicker: some View {
        HStack(spacing: 6) {
            tabButton(title: "Changelog", icon: "doc.text.fill", index: 0)
            tabButton(title: "Installation", icon: "arrow.down.app.fill", index: 1)
            tabButton(title: "Package Info", icon: "info.circle.fill", index: 2)
        }
        .padding(4)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
        )
    }
    
    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button(action: {
            SoundAndHapticManager.shared.triggerHaptic(.light)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                selectedTab = index
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(selectedTab == index ? .black : .white.opacity(0.7))
            .background(
                Group {
                    if selectedTab == index {
                        LinearGradient(
                            colors: [Color.cyan, Color(red: 0.0, green: 1.0, blue: 0.64)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.cyan.opacity(0.3), radius: 4)
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Tab 1: Changelog
    
    private var changelogTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Highlights Section
            VStack(alignment: .leading, spacing: 8) {
                Label("Release Highlights", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.cyan)
                
                changelogBullet(tag: "NEW", tagColor: .cyan, text: "Liquid Signer on-device IPA signing suite with secret '1337=' stealth vault")
                changelogBullet(tag: "NEW", tagColor: Color(red: 0.0, green: 1.0, blue: 0.64), text: "Cyberpunk dual-reticle unlock animations with progressive tactile haptics")
                changelogBullet(tag: "CLOUD", tagColor: .purple, text: "Serverless backend on Vercel with Gemini 2.5 Flash SSE streaming proxy")
                changelogBullet(tag: "OTA", tagColor: .blue, text: "Dynamic Apple itms-services manifest hosting for 1-tap wireless sideloading")
                changelogBullet(tag: "IMPROVED", tagColor: .orange, text: "In-app multi-channel update downloader with live progress and Liquid Signer handoff")
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
            )
            
            // Raw Notes
            if let body = release.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Detailed Release Notes", systemImage: "text.alignleft")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(body)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    
    private func changelogBullet(tag: String, tagColor: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(tag)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(tagColor.opacity(0.2))
                .foregroundColor(tagColor)
                .clipShape(Capsule())
            
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Tab 2: Installation Options & In-App Downloader
    
    private var installOptionsTab: some View {
        VStack(spacing: 16) {
            // Option 1: 1-Tap Wireless OTA Card (Fastest, no computer required)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("1-Tap Wireless Direct Install")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text("Installs over-the-air wirelessly without a PC or cable")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Button(action: {
                    updateManager.installWirelesslyOTA(for: release)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Install Wirelessly (OTA)")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(
                        LinearGradient(
                            colors: [Color.cyan, Color(red: 0.0, green: 1.0, blue: 0.64)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
            )
            
            // Option 2: In-App Download Card (with Live Progress, Signer Handoff, TrollStore)
            inAppDownloadCard
        }
    }
    
    private var inAppDownloadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.purple)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("In-App Download & Signer Handoff")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Download .ipa to sign with Liquid Signer or TrollStore")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            switch updateManager.downloadState {
            case .idle:
                Button(action: {
                    Task { @MainActor in
                        updateManager.startDownload(for: release)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.app.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Download LiquidCalc.ipa")
                            .font(.system(size: 13, weight: .bold))
                        
                        if let size = release.ipaAsset?.formattedSize {
                            Text("(\(size))")
                                .font(.system(size: 11))
                                .opacity(0.8)
                        }
                        
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                
            case .downloading(let progress, let written, let total, let speed):
                VStack(spacing: 8) {
                    HStack {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                        
                        Spacer()
                        
                        Text("\(formatBytes(written)) / \(formatBytes(total)) • \(speed)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            Task { @MainActor in
                                updateManager.cancelDownload()
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    
                    ProgressView(value: progress)
                        .tint(.cyan)
                }
                .padding(10)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
            case .completed(let fileUrl):
                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                        Text("Package Downloaded Successfully")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                        Spacer()
                    }
                    
                    // Route 1: Send to Liquid Signer
                    Button(action: {
                        sendToSigner(url: fileUrl)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Re-Sign with Liquid Signer")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Embed personal certificate & inject custom tweaks")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(Color.purple.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.purple.opacity(0.35), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Route 2: Open in TrollStore
                    if updateManager.getTrollStoreInstallURL(for: release) != nil {
                        Button(action: {
                            updateManager.openInTrollStore(for: release)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "app.badge.checkmark")
                                    .foregroundColor(.cyan)
                                Text("Open in TrollStore")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .background(Color.cyan.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Route 3: Share / AirDrop / Files
                    Button(action: {
                        showShareSheet = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white.opacity(0.9))
                            Text("Share / Save to Files")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                
            case .failed(let error):
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Download Failed")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Button("Retry Download") {
                        Task { @MainActor in
                            updateManager.startDownload(for: release)
                        }
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.cyan)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }
    
    // MARK: - Tab 3: Package Details
    
    private var packageDetailsTab: some View {
        VStack(spacing: 10) {
            detailRow(title: "Bundle Identifier", value: "com.liquidcalc.app")
            detailRow(title: "Release Tag", value: release.tagName)
            detailRow(title: "Target Platform", value: "iOS 17.0+ (Universal)")
            detailRow(title: "Binary Architecture", value: "arm64 (Native)")
            detailRow(title: "Distribution Source", value: "Vercel Cloud & GitHub")
            if let asset = release.ipaAsset {
                detailRow(title: "Asset Name", value: asset.name)
                if let size = asset.formattedSize {
                    detailRow(title: "File Size", value: size)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 4)
            
            // View Release on GitHub
            Button(action: {
                openURL(release.htmlURL)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "safari")
                    Text("View Release on GitHub")
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.cyan)
                .padding(12)
                .background(Color.cyan.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
        }
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack(spacing: 12) {
                Button(action: {
                    updateManager.dismissUpdateSheet()
                    dismiss()
                }) {
                    Text("Remind Later")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    updateManager.installWirelesslyOTA(for: release)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                        Text("Update Now")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        LinearGradient(
                            colors: [Color.cyan, Color(red: 0.0, green: 1.0, blue: 0.64)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.cyan.opacity(0.3), radius: 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .background(Color(red: 0.06, green: 0.07, blue: 0.10).opacity(0.95))
    }
    
    // MARK: - Sent to Signer Toast
    
    private var sentToSignerToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
            Text("Imported into Liquid Signer Vault!")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(red: 0.1, green: 0.12, blue: 0.18).opacity(0.95))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.4), lineWidth: 1))
        .padding(.top, 10)
    }
    
    // MARK: - Helpers
    
    private func sendToSigner(url: URL) {
        SoundAndHapticManager.shared.triggerHaptic(.success)
        let signer = LiquidSignerViewModel.shared
        signer.importIPA(from: url)
        withAnimation {
            showSentToSignerToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showSentToSignerToast = false
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
