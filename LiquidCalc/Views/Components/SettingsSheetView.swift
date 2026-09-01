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
                            Text("1.0.0 (Build 1)")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Platform Target")
                            Spacer()
                            Text("iOS 18+ • Swift 6")
                                .foregroundColor(.secondary)
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
        }
    }
}
