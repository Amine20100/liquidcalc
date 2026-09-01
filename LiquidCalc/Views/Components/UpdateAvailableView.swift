//
//  UpdateAvailableView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

/// Glassmorphic modal / sheet view presenting update information when a newer version of LiquidCalc is released on GitHub.
public struct UpdateAvailableView: View {
    public let release: GitHubRelease
    @Bindable public var updateManager: AppUpdateManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    public init(release: GitHubRelease, updateManager: AppUpdateManager = .shared) {
        self.release = release
        self.updateManager = updateManager
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Frosted background
                Color(red: 0.07, green: 0.08, blue: 0.12)
                    .ignoresSafeArea()
                
                // Ambient glass glow spots
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 260, height: 260)
                    .blur(radius: 60)
                    .offset(x: -80, y: -180)
                
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 280, height: 280)
                    .blur(radius: 70)
                    .offset(x: 100, y: 120)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header Icon & Title
                        headerSection
                        
                        // Version Comparison Badges
                        versionBadgesSection
                        
                        // Release Notes Card
                        releaseNotesSection
                        
                        // Action Buttons (Download IPA / View on GitHub / Dismiss)
                        actionButtonsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Update Available")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Dismiss") {
                        updateManager.dismissUpdateSheet()
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle()
                            .stroke(Color.cyan.opacity(0.4), lineWidth: 1.5)
                    )
                
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text("New Version Available")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(release.displayTitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }
    
    private var versionBadgesSection: some View {
        HStack(spacing: 12) {
            // Current Version Pill
            HStack(spacing: 6) {
                Text("Installed:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Text("v\(updateManager.currentVersionString)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
            
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.cyan)
            
            // Latest Version Pill
            HStack(spacing: 6) {
                Text("Latest:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Text(release.tagName)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.cyan.opacity(0.15))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.cyan.opacity(0.35), lineWidth: 0.8))
        }
    }
    
    private var releaseNotesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.cyan)
                    .font(.system(size: 14, weight: .semibold))
                Text("What's New")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                if let date = release.publishedDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            let notes = release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No release notes provided for this release.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Primary Action: Download IPA if available
            if let ipaURL = release.ipaDownloadURL {
                Button(action: {
                    openURL(ipaURL)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.app.fill")
                            .font(.system(size: 16, weight: .bold))
                        
                        Text("Download LiquidCalc.ipa")
                            .font(.system(size: 16, weight: .semibold))
                        
                        if let size = release.ipaAsset?.formattedSize {
                            Text("(\(size))")
                                .font(.system(size: 13, weight: .regular))
                                .opacity(0.8)
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color.cyan, Color(red: 0.3, green: 0.8, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.cyan.opacity(0.35), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
            
            // Secondary Action: View on GitHub
            Button(action: {
                openURL(release.htmlURL)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "safari")
                        .font(.system(size: 15, weight: .medium))
                    Text("View on GitHub")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
            
            // Later / Dismiss Button
            Button(action: {
                updateManager.dismissUpdateSheet()
                dismiss()
            }) {
                Text("Remind Me Later")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }
}
