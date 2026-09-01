//
//  GitHubRelease.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation

/// Model representing an individual downloadable asset attached to a GitHub Release.
public struct GitHubReleaseAsset: Codable, Sendable, Identifiable, Equatable {
    public let id: Int?
    public let name: String
    public let size: Int?
    public let downloadCount: Int?
    public let browserDownloadURL: URL
    public let contentType: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case size
        case downloadCount = "download_count"
        case browserDownloadURL = "browser_download_url"
        case contentType = "content_type"
    }
    
    public init(
        id: Int? = nil,
        name: String,
        size: Int? = nil,
        downloadCount: Int? = nil,
        browserDownloadURL: URL,
        contentType: String? = nil
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.downloadCount = downloadCount
        self.browserDownloadURL = browserDownloadURL
        self.contentType = contentType
    }
    
    /// User-friendly file size formatted string (e.g. "15.4 MB").
    public var formattedSize: String? {
        guard let size = size else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

/// Model representing a GitHub Release fetched from the GitHub Releases REST API.
/// Target endpoint: `https://api.github.com/repos/Amine20100/liquidcalc/releases/latest`
public struct GitHubRelease: Codable, Sendable, Identifiable, Equatable {
    public let id: Int?
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlURL: URL
    public let publishedAtString: String?
    public let isPrerelease: Bool?
    public let isDraft: Bool?
    public let assets: [GitHubReleaseAsset]
    
    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case publishedAtString = "published_at"
        case isPrerelease = "prerelease"
        case isDraft = "draft"
        case assets
    }
    
    public init(
        id: Int? = nil,
        tagName: String,
        name: String? = nil,
        body: String? = nil,
        htmlURL: URL,
        publishedAtString: String? = nil,
        isPrerelease: Bool? = false,
        isDraft: Bool? = false,
        assets: [GitHubReleaseAsset] = []
    ) {
        self.id = id
        self.tagName = tagName
        self.name = name
        self.body = body
        self.htmlURL = htmlURL
        self.publishedAtString = publishedAtString
        self.isPrerelease = isPrerelease
        self.isDraft = isDraft
        self.assets = assets
    }
    
    // MARK: - Computed Helpers
    
    /// Find the primary `LiquidCalc.ipa` installation asset from release assets.
    public var ipaAsset: GitHubReleaseAsset? {
        // Look for exact "LiquidCalc.ipa" first, then any asset ending with .ipa
        if let exact = assets.first(where: { $0.name.caseInsensitiveCompare("LiquidCalc.ipa") == .orderedSame }) {
            return exact
        }
        return assets.first(where: { $0.name.lowercased().hasSuffix(".ipa") })
    }
    
    /// Direct download URL for the LiquidCalc IPA asset, if present.
    public var ipaDownloadURL: URL? {
        ipaAsset?.browserDownloadURL
    }
    
    /// Parsed semantic version from `tagName` (e.g. "v1.1.0" -> SemanticVersion(1, 1, 0)).
    public var semanticVersion: SemanticVersion? {
        SemanticVersion(tagName)
    }
    
    /// User-visible display title (e.g. "LiquidCalc v1.1.0 - Next-Gen Glass Engine").
    public var displayTitle: String {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return tagName
    }
    
    /// Formatted publication date parsed from ISO 8601 string.
    public var publishedDate: Date? {
        guard let str = publishedAtString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: str) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: str)
    }
}
