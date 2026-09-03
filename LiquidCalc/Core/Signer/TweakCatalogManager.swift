//
//  TweakCatalogManager.swift
//  LiquidCalc
//
//  Created for LiquidCalc v2.6.0.
//  Manages the built-in and community Dylib tweak catalog for Mach-O injection.
//

import Foundation
import Observation

@Observable
public final class TweakCatalogManager: @unchecked Sendable {
    public static let shared = TweakCatalogManager()
    
    public var catalogItems: [TweakCatalogItem] = []
    public var isDownloading: Bool = false
    public var downloadProgress: Double = 0.0
    public var errorMessage: String?
    
    private let fileManager = FileManager.default
    private let tweaksDir: URL
    
    public init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.tweaksDir = appSupport.appendingPathComponent("LiquidSigner/Tweaks", isDirectory: true)
        try? fileManager.createDirectory(at: tweaksDir, withIntermediateDirectories: true)
        
        loadInitialCatalog()
    }
    
    private func loadInitialCatalog() {
        catalogItems = [
            TweakCatalogItem(
                name: "FLEXing Debugger",
                filename: "FLEXing.dylib",
                summary: "Complete in-app runtime inspector, view hierarchy explorer, network monitor, and memory browser.",
                category: "Developer Tools",
                version: "5.22.0",
                author: "Flipboard / NSExceptional",
                isBuiltIn: true,
                isEnabled: false
            ),
            TweakCatalogItem(
                name: "Sandbox FileBrowser",
                filename: "FileBrowser.dylib",
                summary: "Direct on-screen sandbox directory navigator with document preview, export, and text editor.",
                category: "Utilities",
                version: "2.1.0",
                author: "RoyMarmelstein",
                isBuiltIn: true,
                isEnabled: false
            ),
            TweakCatalogItem(
                name: "SpeedMaster Pro",
                filename: "SpeedMaster.dylib",
                summary: "Manipulates Mach timing and CADisplayLink frequency to accelerate animations and app speed.",
                category: "Enhancements",
                version: "1.4.0",
                author: "Julioverne",
                isBuiltIn: true,
                isEnabled: false
            ),
            TweakCatalogItem(
                name: "AdBlock Core",
                filename: "AdBlockCore.dylib",
                summary: "Lightweight URLSession and WKWebView request interrupter blocking known tracking domains.",
                category: "Privacy",
                version: "3.0.1",
                author: "Community",
                isBuiltIn: true,
                isEnabled: false
            )
        ]
    }
    
    public func toggleTweak(_ item: TweakCatalogItem) {
        if let idx = catalogItems.firstIndex(where: { $0.id == item.id }) {
            catalogItems[idx].isEnabled.toggle()
        }
    }
    
    public func downloadCustomTweak(from url: URL, name: String) async throws -> TweakCatalogItem {
        await MainActor.run {
            self.isDownloading = true
            self.downloadProgress = 0.1
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
            throw NSError(domain: "TweakDownloadError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to download tweak from remote URL"])
        }
        
        let filename = url.lastPathComponent.isEmpty ? "\(UUID().uuidString).dylib" : url.lastPathComponent
        let destUrl = tweaksDir.appendingPathComponent(filename)
        try data.write(to: destUrl)
        
        let newItem = TweakCatalogItem(
            name: name.isEmpty ? filename : name,
            filename: filename,
            summary: "Custom community dylib imported from \(url.host ?? "URL")",
            category: "Custom",
            version: "1.0.0",
            author: "Imported",
            downloadUrl: url.absoluteString,
            isBuiltIn: false,
            isEnabled: true
        )
        
        await MainActor.run {
            self.catalogItems.append(newItem)
            self.isDownloading = false
            self.downloadProgress = 1.0
        }
        
        return newItem
    }
}
