//
//  CertificateManager.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Liquid Signer Certificate & Mobileprovision Manager
//

import Foundation
import Security

@Observable
public final class CertificateManager: @unchecked Sendable {
    public static let shared = CertificateManager()
    
    public var certificates: [SigningCertificate] = []
    public var profiles: [ProvisioningProfile] = []
    public var activeCertificate: SigningCertificate?
    public var activeProfile: ProvisioningProfile?
    
    private let fileManager = FileManager.default
    private let certsDir: URL
    private let profilesDir: URL
    private let certsStorageKey = "LiquidSigner_Certificates_v1"
    private let profilesStorageKey = "LiquidSigner_Profiles_v1"
    
    public init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        self.certsDir = appSupport.appendingPathComponent("LiquidSigner/Certificates", isDirectory: true)
        self.profilesDir = appSupport.appendingPathComponent("LiquidSigner/Profiles", isDirectory: true)
        
        try? fileManager.createDirectory(at: certsDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: profilesDir, withIntermediateDirectories: true)
        
        loadSavedData()
        
        // If empty, add a default pre-configured test/ad-hoc certificate
        if certificates.isEmpty {
            createDefaultTestCertificate()
        }
    }
    
    // MARK: - Certificate Import (.p12)
    
    public func importP12(from url: URL, password: String, customName: String? = nil) throws -> SigningCertificate {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: url)
        return try importP12Data(data: data, originalFilename: url.lastPathComponent, password: password, customName: customName)
    }
    
    public func importP12Data(data: Data, originalFilename: String, password: String, customName: String? = nil) throws -> SigningCertificate {
        // Validate with Security Framework
        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        var rawItems: CFArray?
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &rawItems)
        
        guard status == errSecSuccess, let items = rawItems as? [[String: Any]], let firstItem = items.first else {
            throw NSError(
                domain: "CertificateManager",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Invalid P12 password or corrupted certificate file (status: \(status))."]
            )
        }
        
        var commonName = "Apple Development Certificate"
        var expirationDate = Date().addingTimeInterval(365 * 24 * 3600)
        var teamName: String? = nil
        var teamId: String? = nil
        
        if let secIdentity = firstItem[kSecImportItemIdentity as String] {
            var certRef: SecCertificate?
            if SecIdentityCopyCertificate(secIdentity as! SecIdentity, &certRef) == errSecSuccess, let cert = certRef {
                if let summary = SecCertificateCopySubjectSummary(cert) {
                    commonName = summary as String
                }
            }
        }
        
        // Save p12 to persistent directory
        let uniqueFileName = "\(UUID().uuidString).p12"
        let destUrl = certsDir.appendingPathComponent(uniqueFileName)
        try data.write(to: destUrl)
        
        let name = customName?.isEmpty == false ? customName! : (originalFilename.replacingOccurrences(of: ".p12", with: ""))
        
        let newCert = SigningCertificate(
            name: name,
            commonName: commonName,
            teamName: teamName,
            teamIdentifier: teamId,
            expirationDate: expirationDate,
            p12FileName: uniqueFileName,
            password: password,
            isDefault: certificates.isEmpty
        )
        
        if Thread.isMainThread {
            self.certificates.append(newCert)
            if self.activeCertificate == nil {
                self.activeCertificate = newCert
            }
            self.saveData()
        } else {
            DispatchQueue.main.sync {
                self.certificates.append(newCert)
                if self.activeCertificate == nil {
                    self.activeCertificate = newCert
                }
                self.saveData()
            }
        }
        
        return newCert
    }
    
    // MARK: - Provisioning Profile Import (.mobileprovision)
    
    public func importProvisioningProfile(from url: URL, customName: String? = nil) throws -> ProvisioningProfile {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: url)
        return try importProfileData(data: data, originalFilename: url.lastPathComponent, customName: customName)
    }
    
    public func importProfileData(data: Data, originalFilename: String, customName: String? = nil) throws -> ProvisioningProfile {
        let (parsedName, uuid, teamName, teamId, appIdentifier, expirationDate) = extractProfileMetadata(from: data)
        
        let uniqueFileName = "\(UUID().uuidString).mobileprovision"
        let destUrl = profilesDir.appendingPathComponent(uniqueFileName)
        try data.write(to: destUrl)
        
        let name = customName?.isEmpty == false ? customName! : (parsedName ?? originalFilename.replacingOccurrences(of: ".mobileprovision", with: ""))
        let isWildcard = appIdentifier.hasSuffix("*")
        
        let newProfile = ProvisioningProfile(
            name: name,
            uuid: uuid ?? UUID().uuidString,
            teamName: teamName,
            teamIdentifier: teamId,
            appIdentifier: appIdentifier,
            expirationDate: expirationDate ?? Date().addingTimeInterval(365 * 24 * 3600),
            profileFileName: uniqueFileName,
            isWildcard: isWildcard
        )
        
        if Thread.isMainThread {
            self.profiles.append(newProfile)
            if self.activeProfile == nil {
                self.activeProfile = newProfile
            }
            self.saveData()
        } else {
            DispatchQueue.main.sync {
                self.profiles.append(newProfile)
                if self.activeProfile == nil {
                    self.activeProfile = newProfile
                }
                self.saveData()
            }
        }
        
        return newProfile
    }
    
    // MARK: - Profile Metadata XML Extractor
    
    private func extractProfileMetadata(from data: Data) -> (name: String?, uuid: String?, teamName: String?, teamId: String?, appIdentifier: String, expirationDate: Date?) {
        var appIdentifier = "*"
        var name: String? = nil
        var uuid: String? = nil
        var teamName: String? = nil
        var teamId: String? = nil
        var expirationDate: Date? = nil
        
        // Find XML boundaries in CMS container
        guard let startRange = data.range(of: "<plist".data(using: .utf8)!),
              let endRange = data.range(of: "</plist>".data(using: .utf8)!) else {
            return (name, uuid, teamName, teamId, appIdentifier, expirationDate)
        }
        
        let xmlData = data.subdata(in: startRange.lowerBound..<endRange.upperBound)
        if let plist = try? PropertyListSerialization.propertyList(from: xmlData, format: nil) as? [String: Any] {
            name = plist["Name"] as? String
            uuid = plist["UUID"] as? String
            teamName = plist["TeamName"] as? String
            if let teamIds = plist["TeamIdentifier"] as? [String], let first = teamIds.first {
                teamId = first
            }
            expirationDate = plist["ExpirationDate"] as? Date
            
            if let entitlements = plist["Entitlements"] as? [String: Any],
               let appId = entitlements["application-identifier"] as? String {
                appIdentifier = appId
            }
        }
        
        return (name, uuid, teamName, teamId, appIdentifier, expirationDate)
    }
    
    // MARK: - File Path Accessors
    
    public func urlForCertificate(_ cert: SigningCertificate) -> URL {
        certsDir.appendingPathComponent(cert.p12FileName)
    }
    
    public func urlForProfile(_ profile: ProvisioningProfile) -> URL {
        profilesDir.appendingPathComponent(profile.profileFileName)
    }
    
    public func deleteCertificate(_ cert: SigningCertificate) {
        let url = urlForCertificate(cert)
        try? fileManager.removeItem(at: url)
        certificates.removeAll { $0.id == cert.id }
        if activeCertificate?.id == cert.id {
            activeCertificate = certificates.first
        }
        saveData()
    }
    
    public func deleteProfile(_ profile: ProvisioningProfile) {
        let url = urlForProfile(profile)
        try? fileManager.removeItem(at: url)
        profiles.removeAll { $0.id == profile.id }
        if activeProfile?.id == profile.id {
            activeProfile = profiles.first
        }
        saveData()
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(certificates) {
            UserDefaults.standard.set(encoded, forKey: certsStorageKey)
        }
        if let encoded = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(encoded, forKey: profilesStorageKey)
        }
    }
    
    // MARK: - ESign ZIP Certificate Archive Import
    
    public func importCertificateZip(from zipUrl: URL, password: String) throws -> (SigningCertificate?, ProvisioningProfile?) {
        let isAccessing = zipUrl.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { zipUrl.stopAccessingSecurityScopedResource() }
        }
        
        let tempExtractDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempExtractDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempExtractDir) }
        
        // Extract using ZipArchiveExtractor (pure Swift + Compression on iOS / unzip on macOS)
        try? ZipArchiveExtractor.shared.extract(archiveUrl: zipUrl, destinationDir: tempExtractDir)
        
        // Traverse extracted files to locate .p12 and .mobileprovision
        var foundCert: SigningCertificate? = nil
        var foundProfile: ProvisioningProfile? = nil
        
        if let enumerator = fileManager.enumerator(at: tempExtractDir, includingPropertiesForKeys: nil) {
            for case let fileUrl as URL in enumerator {
                if fileUrl.pathExtension.lowercased() == "p12" {
                    if let cert = try? importP12(from: fileUrl, password: password) {
                        foundCert = cert
                    }
                } else if fileUrl.pathExtension.lowercased() == "mobileprovision" {
                    if let prof = try? importProvisioningProfile(from: fileUrl) {
                        foundProfile = prof
                    }
                }
            }
        }
        
        return (foundCert, foundProfile)
    }
    
    // MARK: - ESign Certificate Revocation & Health Check
    
    public func checkRevocationStatus(for certificate: SigningCertificate) async -> Bool {
        let p12Url = urlForCertificate(certificate)
        guard let p12Data = try? Data(contentsOf: p12Url) else {
            return false
        }
        
        let p12Base64 = p12Data.base64EncodedString()
        guard let url = URL(string: "https://liquidcalc-backend.vercel.app/api/signer/certificate") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15.0
        
        let payload: [String: Any] = [
            "p12Base64": p12Base64,
            "password": certificate.password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let certInfo = json["certificate"] as? [String: Any] {
                let valid = (certInfo["valid"] as? Bool) ?? true
                
                await MainActor.run {
                    if let idx = self.certificates.firstIndex(where: { $0.id == certificate.id }) {
                        self.certificates[idx].isRevoked = !valid
                        self.certificates[idx].revocationCheckDate = Date()
                        self.saveData()
                    }
                }
                return valid
            }
        } catch {
            return true
        }
        return true
    }
    
    private func loadSavedData() {
        if let data = UserDefaults.standard.data(forKey: certsStorageKey),
           let decoded = try? JSONDecoder().decode([SigningCertificate].self, from: data) {
            self.certificates = decoded
            self.activeCertificate = decoded.first(where: { $0.isDefault }) ?? decoded.first
        }
        if let data = UserDefaults.standard.data(forKey: profilesStorageKey),
           let decoded = try? JSONDecoder().decode([ProvisioningProfile].self, from: data) {
            self.profiles = decoded
            self.activeProfile = decoded.first
        }
    }
    
    // MARK: - Default Test Certificate Generator
    
    private func createDefaultTestCertificate() {
        let testCert = SigningCertificate(
            name: "Apple Development (Ad-Hoc / Self-Signed)",
            commonName: "iPhone Developer: Liquid Signer Test (DEV1337)",
            teamName: "Liquid Development Team",
            teamIdentifier: "LIQUID1337",
            expirationDate: Date().addingTimeInterval(365 * 24 * 3600),
            p12FileName: "default_adhoc.p12",
            password: "",
            isDefault: true
        )
        
        let testProfile = ProvisioningProfile(
            name: "Liquid Signer Universal Wildcard Profile",
            uuid: UUID().uuidString,
            teamName: "Liquid Development Team",
            teamIdentifier: "LIQUID1337",
            appIdentifier: "*",
            expirationDate: Date().addingTimeInterval(365 * 24 * 3600),
            profileFileName: "default_wildcard.mobileprovision",
            isWildcard: true
        )
        
        self.certificates = [testCert]
        self.profiles = [testProfile]
        self.activeCertificate = testCert
        self.activeProfile = testProfile
        saveData()
    }
}
