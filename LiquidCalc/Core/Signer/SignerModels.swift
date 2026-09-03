//
//  SignerModels.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Liquid Signer Hidden Vault Data Models
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct SignedApp: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var bundleIdentifier: String
    public var version: String
    public var originalIpaUrl: URL?
    public var signedIpaUrl: URL?
    public var dateAdded: Date
    public var dateSigned: Date?
    public var sizeBytes: Int64
    public var injectedDylibs: [String]
    public var status: AppSigningStatus
    
    public init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String,
        version: String = "1.0",
        originalIpaUrl: URL? = nil,
        signedIpaUrl: URL? = nil,
        dateAdded: Date = Date(),
        dateSigned: Date? = nil,
        sizeBytes: Int64 = 0,
        injectedDylibs: [String] = [],
        status: AppSigningStatus = .readyToSign
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.originalIpaUrl = originalIpaUrl
        self.signedIpaUrl = signedIpaUrl
        self.dateAdded = dateAdded
        self.dateSigned = dateSigned
        self.sizeBytes = sizeBytes
        self.injectedDylibs = injectedDylibs
        self.status = status
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

public enum AppSigningStatus: String, Codable, Sendable {
    case readyToSign = "Ready to Sign"
    case signing = "Signing..."
    case signed = "Signed"
    case failed = "Failed"
}

public struct SigningCertificate: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var commonName: String
    public var teamName: String?
    public var teamIdentifier: String?
    public var expirationDate: Date
    public var p12FileName: String
    public var password: String
    public var isDefault: Bool
    public var isRevoked: Bool
    public var revocationCheckDate: Date?
    
    public init(
        id: UUID = UUID(),
        name: String,
        commonName: String,
        teamName: String? = nil,
        teamIdentifier: String? = nil,
        expirationDate: Date,
        p12FileName: String,
        password: String = "",
        isDefault: Bool = false,
        isRevoked: Bool = false,
        revocationCheckDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.commonName = commonName
        self.teamName = teamName
        self.teamIdentifier = teamIdentifier
        self.expirationDate = expirationDate
        self.p12FileName = p12FileName
        self.password = password
        self.isDefault = isDefault
        self.isRevoked = isRevoked
        self.revocationCheckDate = revocationCheckDate
    }
    
    public var isExpired: Bool {
        expirationDate < Date()
    }
    
    public var isValid: Bool {
        !isExpired && !isRevoked
    }
    
    public var daysRemaining: Int {
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        return max(0, diff)
    }
}

public struct ProvisioningProfile: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var uuid: String
    public var teamName: String?
    public var teamIdentifier: String?
    public var appIdentifier: String
    public var expirationDate: Date
    public var profileFileName: String
    public var isWildcard: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        uuid: String,
        teamName: String? = nil,
        teamIdentifier: String? = nil,
        appIdentifier: String,
        expirationDate: Date,
        profileFileName: String,
        isWildcard: Bool = false
    ) {
        self.id = id
        self.name = name
        self.uuid = uuid
        self.teamName = teamName
        self.teamIdentifier = teamIdentifier
        self.appIdentifier = appIdentifier
        self.expirationDate = expirationDate
        self.profileFileName = profileFileName
        self.isWildcard = isWildcard
    }
    
    public var isExpired: Bool {
        expirationDate < Date()
    }
}

public struct DylibTweak: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var filename: String
    public var fileUrl: URL
    public var isEnabled: Bool
    public var sizeBytes: Int64
    
    public init(
        id: UUID = UUID(),
        filename: String,
        fileUrl: URL,
        isEnabled: Bool = true,
        sizeBytes: Int64 = 0
    ) {
        self.id = id
        self.filename = filename
        self.fileUrl = fileUrl
        self.isEnabled = isEnabled
        self.sizeBytes = sizeBytes
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

public struct SignerLogMessage: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public let timestamp = Date()
    public let text: String
    public let level: LogLevel
    
    public enum LogLevel: String, Sendable {
        case info
        case success
        case warning
        case error
        case terminal
    }
    
    public init(text: String, level: LogLevel = .info) {
        self.text = text
        self.level = level
    }
}

public struct SigningConfig: Sendable {
    public var customName: String
    public var customBundleId: String
    public var customVersion: String
    public var certificate: SigningCertificate?
    public var profile: ProvisioningProfile?
    public var dylibs: [DylibTweak]
    public var removeExtensions: Bool
    public var injectGetTaskAllow: Bool
    public var enableFileSharing: Bool
    public var installAfterSigned: Bool
    
    public init(
        customName: String,
        customBundleId: String,
        customVersion: String = "1.0",
        certificate: SigningCertificate? = nil,
        profile: ProvisioningProfile? = nil,
        dylibs: [DylibTweak] = [],
        removeExtensions: Bool = false,
        injectGetTaskAllow: Bool = false,
        enableFileSharing: Bool = true,
        installAfterSigned: Bool = false
    ) {
        self.customName = customName
        self.customBundleId = customBundleId
        self.customVersion = customVersion
        self.certificate = certificate
        self.profile = profile
        self.dylibs = dylibs
        self.removeExtensions = removeExtensions
        self.injectGetTaskAllow = injectGetTaskAllow
        self.enableFileSharing = enableFileSharing
        self.installAfterSigned = installAfterSigned
    }
}
