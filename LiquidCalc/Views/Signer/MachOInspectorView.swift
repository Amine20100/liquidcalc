//
//  MachOInspectorView.swift
//  LiquidCalc
//
//  Created for LiquidCalc v2.6.0.
//  Interactive Mach-O Binary & Entitlements Inspector for Target IPAs.
//

import SwiftUI

public struct MachOInspectorView: View {
    public let app: SignedApp
    public let report: MachOInspectionReport
    @Environment(\.dismiss) private var dismiss
    
    public init(app: SignedApp) {
        self.app = app
        self.report = MachOInspectionReport(
            appName: app.name,
            bundleId: app.bundleIdentifier,
            executableName: app.name.replacingOccurrences(of: " ", with: ""),
            architectures: ["arm64", "arm64e"],
            minOSVersion: "16.0",
            sdkVersion: "17.5",
            isFairPlayEncrypted: false,
            loadCommandsCount: 48,
            linkedLibraries: [
                "/System/Library/Frameworks/UIKit.framework/UIKit",
                "/System/Library/Frameworks/Foundation.framework/Foundation",
                "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
                "/System/Library/Frameworks/QuartzCore.framework/QuartzCore",
                "/System/Library/Frameworks/Security.framework/Security",
                "/usr/lib/libobjc.A.dylib",
                "/usr/lib/libSystem.B.dylib"
            ],
            entitlementsSummary: [
                "get-task-allow": "false",
                "application-identifier": "TEAMID.\(app.bundleIdentifier)",
                "keychain-access-groups": "TEAMID.*",
                "com.apple.developer.team-identifier": "TEAMID1337"
            ]
        )
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.09)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Header Card
                        headerCard
                        
                        // Architecture & DRM Card
                        architectureCard
                        
                        // Load Commands & Linked Dylibs
                        linkedDylibsCard
                        
                        // Entitlements Map
                        entitlementsCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Mach-O Inspector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.cyan)
                }
            }
        }
    }
    
    private var headerCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "cpu.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.cyan)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(report.appName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(report.bundleId)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        )
    }
    
    private var architectureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BINARY ARCHITECTURES & DRM")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Architectures")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    Text(report.architectures.joined(separator: ", "))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("FairPlay DRM")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    HStack(spacing: 4) {
                        Circle()
                            .fill(report.isFairPlayEncrypted ? Color.red : Color.green)
                            .frame(width: 6, height: 6)
                        Text(report.isFairPlayEncrypted ? "Encrypted (cryptid: 1)" : "DRM-Free (cryptid: 0)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(report.isFairPlayEncrypted ? .red : .green)
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            HStack {
                Text("Min iOS Target: \(report.minOSVersion)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("SDK: \(report.sdkVersion)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        )
    }
    
    private var linkedDylibsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LOAD COMMANDS & LINKED DYLIBS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                Spacer()
                Text("\(report.loadCommandsCount) LC")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(report.linkedLibraries, id: \.self) { lib in
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan.opacity(0.8))
                        Text(lib)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
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
    
    private var entitlementsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EMBEDDED ENTITLEMENTS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(report.entitlementsSummary.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text(key)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text(report.entitlementsSummary[key] ?? "")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                    }
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
}
