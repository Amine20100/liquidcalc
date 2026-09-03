//
//  CertificateStoreView.swift
//  LiquidCalc
//
//  Created for LiquidCalc v2.6.0.
//  In-App Community & Enterprise Certificate Repository.
//

import SwiftUI

public struct CertificateStoreView: View {
    @ObservedObject var certManager: CertificateManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var remoteZipUrl: String = ""
    @State private var remoteZipPassword: String = "1"
    @State private var isImporting: Bool = false
    @State private var statusMessage: String?
    
    public init(certManager: CertificateManager) {
        self.certManager = certManager
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.09)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        headerCard
                        
                        // Import from URL card
                        remoteImportCard
                        
                        // Active & Installed Certificates
                        installedCertificatesCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Certificate Store")
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
                    .fill(Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("CERTIFICATE REPOSITORY")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.64))
                Text("Import, inspect, and manage Apple Developer & Enterprise P12 certificates")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(red: 0.0, green: 1.0, blue: 0.64).opacity(0.2), lineWidth: 0.8))
        )
    }
    
    private var remoteImportCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("IMPORT FROM REMOTE URL (.ZIP / .P12)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
            TextField("https://example.com/certificate.zip", text: $remoteZipUrl)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(10)
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            TextField("ZIP / P12 Password (default '1')", text: $remoteZipPassword)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(10)
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Button(action: downloadAndImportCertificate) {
                HStack {
                    if isImporting {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Download & Import Certificate")
                    }
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(red: 0.0, green: 1.0, blue: 0.64))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(remoteZipUrl.isEmpty || isImporting)
            
            if let status = statusMessage {
                Text(status)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.yellow)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        )
    }
    
    private var installedCertificatesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INSTALLED CERTIFICATES")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
            ForEach(certManager.certificates) { cert in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cert.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text(cert.teamName ?? "Personal Developer")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(cert.daysRemaining)d left")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(cert.isValid ? .green : .red)
                        
                        Button("Check Revocation") {
                            Task {
                                let isRevoked = await certManager.checkRevocationStatus(for: cert)
                                statusMessage = isRevoked ? "⚠️ Certificate has been REVOKED" : "✓ Certificate is ACTIVE"
                            }
                        }
                        .font(.system(size: 9))
                        .foregroundColor(.cyan)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        )
    }
    
    private func downloadAndImportCertificate() {
        guard let url = URL(string: remoteZipUrl.trimmingCharacters(in: .whitespaces)) else { return }
        isImporting = true
        statusMessage = "Downloading archive..."
        
        Task {
            do {
                let (tempData, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw NSError(domain: "CertDownload", code: 400, userInfo: [NSLocalizedDescriptionKey: "Download failed with HTTP status"])
                }
                
                let tempZip = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
                try tempData.write(to: tempZip)
                
                _ = try certManager.importCertificateZip(from: tempZip, password: remoteZipPassword)
                
                await MainActor.run {
                    isImporting = false
                    statusMessage = "✓ Certificate archive imported successfully"
                    remoteZipUrl = ""
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    statusMessage = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
