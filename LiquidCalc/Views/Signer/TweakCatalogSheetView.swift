//
//  TweakCatalogSheetView.swift
//  LiquidCalc
//
//  Created for LiquidCalc v2.6.0.
//  In-App Dylib Tweak Catalog & Downloader.
//

import SwiftUI

public struct TweakCatalogSheetView: View {
    @Bindable var catalogManager: TweakCatalogManager
    @Bindable var signerViewModel: LiquidSignerViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var customUrlString: String = ""
    @State private var customTweakName: String = ""
    @State private var showUrlInput: Bool = false
    
    public init(catalogManager: TweakCatalogManager, signerViewModel: LiquidSignerViewModel) {
        self.catalogManager = catalogManager
        self.signerViewModel = signerViewModel
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.09)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Header Banner
                        headerBanner
                        
                        // Download Custom URL Button / Input
                        customUrlSection
                        
                        // Catalog List
                        catalogListSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Tweak Catalog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        syncTweaksWithSigner()
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.cyan)
                }
            }
        }
    }
    
    private var headerBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.purple)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("DYLIB TWEAK STORE")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)
                Text("Select tweaks to inject directly into target Mach-O during signing")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.purple.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.purple.opacity(0.2), lineWidth: 0.8))
        )
    }
    
    private var customUrlSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("IMPORT CUSTOM DYLIB VIA URL")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                Spacer()
                Button(action: { showUrlInput.toggle() }) {
                    Image(systemName: showUrlInput ? "chevron.up" : "plus")
                        .foregroundColor(.cyan)
                }
            }
            
            if showUrlInput {
                VStack(spacing: 8) {
                    TextField("Tweak Name (e.g. MyTweak)", text: $customTweakName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(10)
                        .background(Color.black.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    TextField("https://domain.com/tweak.dylib", text: $customUrlString)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(10)
                        .background(Color.black.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Button(action: downloadTweakFromUrl) {
                        HStack {
                            if catalogManager.isDownloading {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Download & Install")
                            }
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(customUrlString.isEmpty || catalogManager.isDownloading)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        )
    }
    
    private var catalogListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AVAILABLE TWEAKS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
            ForEach(catalogManager.catalogItems) { item in
                tweakRow(item)
            }
        }
    }
    
    private func tweakRow(_ item: TweakCatalogItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("v\(item.version)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.15))
                        .clipShape(Capsule())
                    
                    Text(item.category)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Text(item.summary)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(2)
                
                Text("by \(item.author) • \(item.filename)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { _ in
                    catalogManager.toggleTweak(item)
                    SoundAndHapticManager.shared.triggerHaptic(.selection)
                }
            ))
            .labelsHidden()
            .tint(Color(red: 0.0, green: 1.0, blue: 0.64))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(item.isEnabled ? Color.purple.opacity(0.08) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(item.isEnabled ? Color.purple.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
    
    private func downloadTweakFromUrl() {
        guard let url = URL(string: customUrlString.trimmingCharacters(in: .whitespaces)) else { return }
        Task {
            do {
                _ = try await catalogManager.downloadCustomTweak(from: url, name: customTweakName)
                await MainActor.run {
                    customUrlString = ""
                    customTweakName = ""
                    showUrlInput = false
                }
            } catch {
                await MainActor.run {
                    catalogManager.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func syncTweaksWithSigner() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let tweaksDir = appSupport.appendingPathComponent("LiquidSigner/Tweaks", isDirectory: true)
        
        for item in catalogManager.catalogItems where item.isEnabled {
            if !signerViewModel.tweaks.contains(where: { $0.filename == item.filename }) {
                let fileUrl = tweaksDir.appendingPathComponent(item.filename)
                signerViewModel.tweaks.append(
                    DylibTweak(filename: item.filename, fileUrl: fileUrl, isEnabled: true)
                )
            }
        }
    }
}
