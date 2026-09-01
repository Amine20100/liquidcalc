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
    
    var body: some Scene {
        WindowGroup {
            MainCalculatorView()
                .preferredColorScheme(.dark)
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
