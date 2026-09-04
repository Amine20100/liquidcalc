//
//  ZipArchiveExtractor.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Pure Swift ZIP & IPA Archive Extractor with Apple Compression Framework Support
//

import Foundation
#if canImport(Compression)
import Compression
#endif

public final class ZipArchiveExtractor: @unchecked Sendable {
    public static let shared = ZipArchiveExtractor()
    
    private let fileManager = FileManager.default
    
    public init() {}
    
    // MARK: - Extracted Entry Model
    
    public struct ZipEntry {
        public let path: String
        public let isDirectory: Bool
        public let data: Data
        public let uncompressedSize: Int
    }
    
    // MARK: - Public Extraction APIs
    
    /// Extracts a ZIP or IPA archive at the given URL into the specified destination directory.
    @discardableResult
    public func extract(archiveUrl: URL, destinationDir: URL) throws -> [URL] {
        let isAccessing = archiveUrl.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                archiveUrl.stopAccessingSecurityScopedResource()
            }
        }
        
        try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        
        #if os(macOS)
        // If system unzip binary is available on macOS host, use it for speed
        if fileManager.fileExists(atPath: "/usr/bin/unzip") {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", "-o", archiveUrl.path, "-d", destinationDir.path]
            try? process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let items = (try? fileManager.contentsOfDirectory(at: destinationDir, includingPropertiesForKeys: nil)) ?? []
                if !items.isEmpty {
                    return items
                }
            }
        }
        #endif
        
        // Pure Swift decompression for iOS & fallback
        let data = try Data(contentsOf: archiveUrl)
        return try extract(zipData: data, destinationDir: destinationDir)
    }
    
    /// Extracts in-memory ZIP data directly into the destination directory.
    @discardableResult
    public func extract(zipData: Data, destinationDir: URL) throws -> [URL] {
        try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        let entries = parseEntries(from: zipData)
        var createdUrls: [URL] = []
        
        for entry in entries {
            let targetUrl = destinationDir.appendingPathComponent(entry.path)
            if entry.isDirectory {
                try fileManager.createDirectory(at: targetUrl, withIntermediateDirectories: true)
            } else {
                let parent = targetUrl.deletingLastPathComponent()
                try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
                try entry.data.write(to: targetUrl)
                createdUrls.append(targetUrl)
            }
        }
        
        return createdUrls
    }
    
    /// Scans a ZIP archive data for files matching any of the specified extensions (e.g. ["p12", "mobileprovision"]).
    public func findFiles(in zipData: Data, extensions: [String]) -> [(filename: String, data: Data)] {
        let entries = parseEntries(from: zipData)
        let extLower = extensions.map { $0.lowercased() }
        
        var matches: [(filename: String, data: Data)] = []
        for entry in entries where !entry.isDirectory {
            let pathExt = (entry.path as NSString).pathExtension.lowercased()
            if extLower.contains(pathExt) {
                let filename = (entry.path as NSString).lastPathComponent
                matches.append((filename: filename, data: entry.data))
            }
        }
        return matches
    }
    
    /// Reads Info.plist metadata dictionary from an IPA or ZIP archive without needing full extraction.
    public func extractInfoPlist(from archiveUrl: URL) -> [String: Any]? {
        let isAccessing = archiveUrl.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { archiveUrl.stopAccessingSecurityScopedResource() }
        }
        
        guard let data = try? Data(contentsOf: archiveUrl) else { return nil }
        let entries = parseEntries(from: data)
        
        // Find Info.plist inside Payload/<AppName>.app/
        for entry in entries where !entry.isDirectory {
            let path = entry.path
            if path.contains("Payload/") && path.hasSuffix(".app/Info.plist") {
                if let plist = try? PropertyListSerialization.propertyList(from: entry.data, format: nil) as? [String: Any] {
                    return plist
                }
            }
        }
        
        // Secondary check: any root Info.plist
        for entry in entries where !entry.isDirectory && entry.path.hasSuffix("Info.plist") {
            if let plist = try? PropertyListSerialization.propertyList(from: entry.data, format: nil) as? [String: Any] {
                return plist
            }
        }
        
        return nil
    }
    
    // MARK: - Internal ZIP Parser
    
    public func parseEntries(from data: Data) -> [ZipEntry] {
        var entries: [ZipEntry] = []
        var offset = 0
        let count = data.count
        
        while offset + 30 <= count {
            // Local file header signature: 0x04034b50 ("PK\x03\x04")
            let sig = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
            guard sig == 0x04034b50 else {
                // Central directory header (0x02014b50) or end of central dir reached
                break
            }
            
            let compressionMethod = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 8, as: UInt16.self) }
            let compressedSize = Int(data.withUnsafeBytes { $0.load(fromByteOffset: offset + 18, as: UInt32.self) })
            let uncompressedSize = Int(data.withUnsafeBytes { $0.load(fromByteOffset: offset + 22, as: UInt32.self) })
            let fileNameLength = Int(data.withUnsafeBytes { $0.load(fromByteOffset: offset + 26, as: UInt16.self) })
            let extraFieldLength = Int(data.withUnsafeBytes { $0.load(fromByteOffset: offset + 28, as: UInt16.self) })
            
            let fileHeaderSize = 30 + fileNameLength + extraFieldLength
            guard offset + fileHeaderSize + compressedSize <= count else { break }
            
            let nameData = data.subdata(in: (offset + 30)..<(offset + 30 + fileNameLength))
            let path = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) ?? "file_\(offset)"
            
            let compressedData = data.subdata(in: (offset + fileHeaderSize)..<(offset + fileHeaderSize + compressedSize))
            let isDirectory = path.hasSuffix("/")
            
            var extractedData = Data()
            if !isDirectory && uncompressedSize > 0 {
                if compressionMethod == 0 {
                    // Stored (no compression)
                    extractedData = compressedData
                } else if compressionMethod == 8 {
                    // Deflated
                    #if canImport(Compression)
                    extractedData = decompressDeflate(compressedData: compressedData, uncompressedSize: uncompressedSize) ?? Data()
                    #else
                    extractedData = compressedData
                    #endif
                }
            }
            
            entries.append(ZipEntry(path: path, isDirectory: isDirectory, data: extractedData, uncompressedSize: uncompressedSize))
            offset += fileHeaderSize + compressedSize
        }
        
        return entries
    }
    
    #if canImport(Compression)
    private func decompressDeflate(compressedData: Data, uncompressedSize: Int) -> Data? {
        guard uncompressedSize > 0, !compressedData.isEmpty else { return Data() }
        
        var destination = Data(count: uncompressedSize)
        let decompressedCount = destination.withUnsafeMutableBytes { dstPtr in
            compressedData.withUnsafeBytes { srcPtr in
                guard let srcBase = srcPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let dstBase = dstPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return compression_decode_buffer(
                    dstBase,
                    uncompressedSize,
                    srcBase,
                    compressedData.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        
        if decompressedCount > 0 {
            return destination.prefix(decompressedCount)
        }
        
        // Fallback to raw copy if decompression returned zero or partial
        return destination
    }
    #endif
}
