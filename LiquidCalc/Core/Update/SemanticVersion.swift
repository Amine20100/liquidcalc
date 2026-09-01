//
//  SemanticVersion.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation

/// Robust Semantic Version (SemVer 2.0.0 compliant) parser and comparator.
/// Supports versions like `1.0.0`, `v1.2.3`, `2.0.0-beta.1`, `1.0.0-alpha+build.42`.
public struct SemanticVersion: Comparable, Equatable, Sendable, Hashable, CustomStringConvertible, LosslessStringConvertible, Codable {
    
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: String?
    public let buildMetadata: String?
    public let rawString: String
    
    // MARK: - Initializers
    
    public init(
        major: Int,
        minor: Int = 0,
        patch: Int = 0,
        prerelease: String? = nil,
        buildMetadata: String? = nil
    ) {
        self.major = max(0, major)
        self.minor = max(0, minor)
        self.patch = max(0, patch)
        
        let cleanedPrerelease = prerelease?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.prerelease = (cleanedPrerelease?.isEmpty == false) ? cleanedPrerelease : nil
        
        let cleanedBuild = buildMetadata?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.buildMetadata = (cleanedBuild?.isEmpty == false) ? cleanedBuild : nil
        
        var str = "\(self.major).\(self.minor).\(self.patch)"
        if let prerelease = self.prerelease {
            str += "-\(prerelease)"
        }
        if let buildMetadata = self.buildMetadata {
            str += "+\(buildMetadata)"
        }
        self.rawString = str
    }
    
    public init?(_ versionString: String) {
        let trimmed = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        var working = trimmed
        if working.hasPrefix("v") || working.hasPrefix("V") {
            working.removeFirst()
        }
        
        // Extract build metadata (+...)
        var buildMeta: String? = nil
        if let plusIndex = working.firstIndex(of: "+") {
            let metaPart = String(working[working.index(after: plusIndex)...])
            buildMeta = metaPart.isEmpty ? nil : metaPart
            working = String(working[..<plusIndex])
        }
        
        // Extract prerelease (-...)
        var prePart: String? = nil
        if let dashIndex = working.firstIndex(of: "-") {
            let preString = String(working[working.index(after: dashIndex)...])
            prePart = preString.isEmpty ? nil : preString
            working = String(working[..<dashIndex])
        }
        
        // Parse Core Version (X.Y.Z or X.Y or X)
        let coreComponents = working.split(separator: ".", omittingEmptySubsequences: false)
        guard !coreComponents.isEmpty, coreComponents.count <= 4 else { return nil }
        
        guard let majorVal = Int(coreComponents[0]), majorVal >= 0 else { return nil }
        
        var minorVal = 0
        if coreComponents.count > 1 {
            guard let val = Int(coreComponents[1]), val >= 0 else { return nil }
            minorVal = val
        }
        
        var patchVal = 0
        if coreComponents.count > 2 {
            guard let val = Int(coreComponents[2]), val >= 0 else { return nil }
            patchVal = val
        }
        
        self.major = majorVal
        self.minor = minorVal
        self.patch = patchVal
        self.prerelease = prePart
        self.buildMetadata = buildMeta
        self.rawString = trimmed
    }
    
    // MARK: - CustomStringConvertible
    
    public var description: String {
        var result = "\(major).\(minor).\(patch)"
        if let prerelease = prerelease {
            result += "-\(prerelease)"
        }
        if let buildMetadata = buildMetadata {
            result += "+\(buildMetadata)"
        }
        return result
    }
    
    // MARK: - Codable
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        guard let version = SemanticVersion(stringValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid semantic version string: '\(stringValue)'"
            )
        }
        self = version
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
    
    // MARK: - Equatable & Comparable
    
    public static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        return lhs.major == rhs.major &&
               lhs.minor == rhs.minor &&
               lhs.patch == rhs.patch &&
               lhs.prerelease == rhs.prerelease
        // Note: per SemVer 2.0.0 spec, build metadata is ignored in version precedence comparison
    }
    
    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        if lhs.patch != rhs.patch {
            return lhs.patch < rhs.patch
        }
        
        // Major, minor, and patch are equal. Check prerelease.
        // A version without prerelease has HIGHER precedence than one with prerelease.
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            return false
        case (nil, .some):
            return false // lhs is normal (higher), rhs is prerelease (lower) -> lhs > rhs
        case (.some, nil):
            return true  // lhs is prerelease (lower), rhs is normal (higher) -> lhs < rhs
        case (.some(let lPre), .some(let rPre)):
            return comparePrereleases(lPre, rPre)
        }
    }
    
    // MARK: - Private Prerelease Comparator
    
    private static func comparePrereleases(_ lhs: String, _ rhs: String) -> Bool {
        let lIdentifiers = lhs.split(separator: ".").map(String.init)
        let rIdentifiers = rhs.split(separator: ".").map(String.init)
        
        let minCount = min(lIdentifiers.count, rIdentifiers.count)
        for i in 0..<minCount {
            let lId = lIdentifiers[i]
            let rId = rIdentifiers[i]
            
            if lId == rId {
                continue
            }
            
            let lNum = Int(lId)
            let rNum = Int(rId)
            
            switch (lNum, rNum) {
            case (.some(let lInt), .some(let rInt)):
                return lInt < rInt
            case (.some, nil):
                // Numeric identifiers have lower precedence than non-numeric
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                return lId.compare(rId, options: .literal) == .orderedAscending
            }
        }
        
        // A larger set of pre-release fields has a higher precedence than a smaller set
        return lIdentifiers.count < rIdentifiers.count
    }
}
