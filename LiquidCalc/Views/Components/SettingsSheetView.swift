//
//  SettingsSheetView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var feedbackManager = SoundAndHapticManager.shared
    @Bindable private var updateManager = AppUpdateManager.shared
    @Bindable private var hotUpdateManager = HotUpdateManager.shared
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.12)
                    .ignoresSafeArea()
                
                Form {
                    Section("Feedback & Interactions") {
                        Toggle("Haptic Feedback", isOn: $feedbackManager.isHapticsEnabled)
                        Toggle("Key Sounds", isOn: $feedbackManager.isSoundEnabled)
                    }
                    .listRowBackground(Color(white: 0.15, opacity: 0.5))
                    
                    Section("In-App Dynamic Updates (No Reinstall)") {
                        HStack {
                            Text("Active Hot Patch")
                            Spacer()
                            Text("v\(hotUpdateManager.currentPatchVersion)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        
                        Button(action: {
                            Task {
                                await hotUpdateManager.checkForHotPatch()
                            }
                        }) {
                            HStack {
                                if hotUpdateManager.isCheckingForHotPatch {
                                    ProgressView()
                                        .tint(.cyan)
                                        .padding(.trailing, 6)
                                    Text("Checking for In-App Updates...")
                                        .foregroundColor(.cyan)
                                } else {
                                    Image(systemName: "bolt.badge.automatic.fill")
                                        .foregroundColor(.cyan)
                                    Text("Check for In-App Hot Patch")
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                        }
                        .disabled(hotUpdateManager.isCheckingForHotPatch || hotUpdateManager.isApplyingPatch)
                        
                        if let patch = hotUpdateManager.availablePatch {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.cyan)
                                    Text("Hot Patch Available: v\(patch.patchVersion)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.cyan)
                                }
                                Text(patch.description)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.85))
                                
                                if hotUpdateManager.isApplyingPatch {
                                    ProgressView(value: hotUpdateManager.patchDownloadProgress)
                                        .tint(.cyan)
                                    Text("Applying changes live...")
                                        .font(.system(size: 11))
                                        .foregroundColor(.cyan)
                                } else {
                                    Button(action: {
                                        Task {
                                            await hotUpdateManager.applyHotPatch(patch)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                            Text("Apply Changes Inside App")
                                        }
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(Color.cyan))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        if let msg = hotUpdateManager.lastAppliedPatchMessage {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                Text(msg)
                                    .font(.system(size: 11))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.15, opacity: 0.5))
                    
                    Section("Full App Release (OTA)") {
                        Toggle("Auto-Check on Launch", isOn: $updateManager.autoCheckOnLaunch)
                        
                        Button(action: {
                            Task {
                                await updateManager.checkForUpdates(manual: true)
                            }
                        }) {
                            HStack {
                                if updateManager.isChecking {
                                    ProgressView()
                                        .tint(.cyan)
                                        .padding(.trailing, 6)
                                    Text("Checking for updates...")
                                        .foregroundColor(.cyan)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundColor(.cyan)
                                    Text("Check for Updates")
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                        }
                        .disabled(updateManager.isChecking)
                        
                        HStack {
                            Text("Last Checked")
                            Spacer()
                            Text(lastCheckedFormatted)
                                .foregroundColor(.secondary)
                        }
                        
                        if updateManager.updateAvailable, let release = updateManager.latestRelease {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.cyan)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Update Available: \(release.tagName)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.cyan)
                                    Text(release.displayTitle)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("View") {
                                    updateManager.showUpdateSheet = true
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.cyan.opacity(0.2))
                                .foregroundColor(.cyan)
                                .clipShape(Capsule())
                            }
                        }
                        
                        if let error = updateManager.errorMessage {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 14))
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange.opacity(0.9))
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.15, opacity: 0.5))
                    
                    Section("Smart Vision Engine") {
                        HStack {
                            Text("Engine")
                            Spacer()
                            Text("Apple Vision OCR (On-Device)")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Accuracy")
                            Spacer()
                            Text("VNRequestAccurate")
                                .foregroundColor(.cyan)
                        }
                    }
                    .listRowBackground(Color(white: 0.15, opacity: 0.5))
                    
                    Section("About LiquidCalc") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("\(updateManager.currentVersionString) (Build \(updateManager.currentBuildString))")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Platform Target")
                            Spacer()
                            Text("iOS 18+ • Swift 6")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("GitHub Repository")
                            Spacer()
                            Link("Amine20100/liquidcalc", destination: URL(string: "https://github.com/Amine20100/liquidcalc")!)
                                .font(.system(size: 14))
                                .foregroundColor(.cyan)
                        }
                    }
                    .listRowBackground(Color(white: 0.15, opacity: 0.5))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $updateManager.showUpdateSheet) {
                if let release = updateManager.latestRelease {
                    UpdateAvailableView(release: release, updateManager: updateManager)
                }
            }
            .alert("LiquidCalc is Up to Date", isPresented: $updateManager.showNoUpdateAlert) {
                Button("OK", role: .cancel) {
                    updateManager.dismissNoUpdateAlert()
                }
            } message: {
                Text("Version \(updateManager.currentVersionString) is currently the newest version available.")
            }
        }
    }
    
    // MARK: - Formatters
    
    private var lastCheckedFormatted: String {
        guard let date = updateManager.lastCheckedDate else {
            return "Never"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
