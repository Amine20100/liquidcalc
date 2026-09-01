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
