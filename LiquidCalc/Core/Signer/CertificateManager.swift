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
        
        DispatchQueue.main.async {
            self.certificates.append(newCert)
            if self.activeCertificate == nil {
                self.activeCertificate = newCert
            }
            self.saveData()
        }
        
        return newCert
    }
    
    // MARK: - Provisioning Profile Import (.mobileprovision)
    
    public func importProvisioningProfile(from url: URL, customName: String? = nil) throws -> ProvisioningProfile {
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
        
        DispatchQueue.main.async {
            self.profiles.append(newProfile)
            if self.activeProfile == nil {
                self.activeProfile = newProfile
            }
            self.saveData()
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
