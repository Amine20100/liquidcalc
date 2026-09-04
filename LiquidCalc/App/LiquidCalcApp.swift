//
//  LiquidCalcApp.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

@main
struct LiquidCalcApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var updateManager = AppUpdateManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainCalculatorView()
                .preferredColorScheme(.dark)
                .sheet(isPresented: $updateManager.showUpdateSheet) {
                    if let release = updateManager.latestRelease {
                        UpdateAvailableView(release: release, updateManager: updateManager)
                    }
                }
                .task {
                    if updateManager.autoCheckOnLaunch {
                        _ = await updateManager.checkForUpdates(manual: false)
                    }
                }
                .onOpenURL { url in
                    let isAccessing = url.startAccessingSecurityScopedResource()
                    defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }
                    
                    let ext = url.pathExtension.lowercased()
                    if ext == "ipa" || ext == "zip" {
                        LiquidSignerViewModel.shared.importIPA(from: url)
                    } else if ext == "dylib" {
                        LiquidSignerViewModel.shared.importDylib(from: url)
                    } else if ext == "mobileprovision" {
                        _ = try? CertificateManager.shared.importProvisioningProfile(from: url)
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                SoundAndHapticManager.shared.handleAppForeground()
            case .background, .inactive:
                SoundAndHapticManager.shared.handleAppBackground()
            @unknown default:
                break
            }
        }
    }
}
