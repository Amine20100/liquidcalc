//
//  HistoryManager.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation
import SwiftUI

@Observable
public final class HistoryManager {
    public static let shared = HistoryManager()
    
    public var items: [HistoryItem] = []
    private let storageKey = "LiquidCalc_History_Storage_v1"
    private let maxCapacity = 200
    
    public init() {
        loadHistory()
    }
    
    public func addItem(expression: String, result: String, mode: String) {
        let trimmedExpr = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRes = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExpr.isEmpty, !trimmedRes.isEmpty, trimmedRes != "Error" else { return }
        
        let newItem = HistoryItem(expression: trimmedExpr, result: trimmedRes, mode: mode)
        items.insert(newItem, at: 0)
        
        if items.count > maxCapacity {
            items = Array(items.prefix(maxCapacity))
        }
        
        saveHistory()
    }
    
    public func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        saveHistory()
    }
    
    public func clearAll() {
        items.removeAll()
        saveHistory()
    }
    
    public func clearHistory() {
        clearAll()
    }
    
    public func exportAsText() -> String {
        return items.map { "\($0.formattedDate) \($0.formattedTime): \($0.expression) = \($0.result)" }
            .joined(separator: "\n")
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) else {
            return
        }
        self.items = decoded
    }
}

// MARK: - Private Workspace

/// A lightweight, file-backed study workspace. It deliberately contains only user
/// authored text and attachment metadata: images never leave the device merely by
/// being saved to a note.
public struct WorkspaceDocument: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var title: String
    public var markdown: String
    public var tags: [String]
    public var attachments: [WorkspaceAttachment]
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), title: String, markdown: String = "", tags: [String] = [], attachments: [WorkspaceAttachment] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.markdown = markdown
        self.tags = tags
        self.attachments = attachments
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct WorkspaceAttachment: Identifiable, Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case scan, aiAnswer, calculation }
    public let id: UUID
    public var kind: Kind
    public var summary: String
    public var createdAt: Date

    public init(id: UUID = UUID(), kind: Kind, summary: String, createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.summary = summary
        self.createdAt = createdAt
    }
}

public enum WorkspaceContext: Sendable, Equatable {
    case calculation(expression: String, result: String)
    case scan(expression: String, result: String?)
    case ai(markdown: String)
    case graph(expression: String)
    case drawing(recognizedText: String, result: String?)
    case note(documentID: UUID)

    public var promptText: String {
        switch self {
        case .calculation(let expression, let result): return "Explain and verify: \(expression) = \(result)"
        case .scan(let expression, let result): return result.map { "Explain this scanned problem: \(expression) = \($0)" } ?? "Help solve this scanned problem: \(expression)"
        case .ai(let markdown): return markdown
        case .graph(let expression): return "Explain and help me graph: \(expression)"
        case .drawing(let recognizedText, let result): return result.map { "Explain this handwritten work: \(recognizedText) = \($0)" } ?? "Help solve this handwritten work: \(recognizedText)"
        case .note: return "Help me improve this study note."
        }
    }

    public var markdownBlock: String {
        switch self {
        case .calculation(let expression, let result): return "## Calculation\n\n`\(expression)` = **\(result)**"
        case .scan(let expression, let result): return "## Scanned problem\n\n`\(expression)`\n\n**Result:** \(result ?? "Pending")"
        case .ai(let markdown): return markdown
        case .graph(let expression): return "## Graph\n\n`\(expression)`"
        case .drawing(let recognizedText, let result): return "## Handwritten work\n\n`\(recognizedText)`\n\n**Result:** \(result ?? "Pending")"
        case .note: return ""
        }
    }
}

public enum WorkspaceDestination: String, CaseIterable, Identifiable, Sendable {
    case calculator, scan, ai, notes

    public var id: String { rawValue }
    public var title: String { switch self { case .calculator: return "LiquidCalc"; case .scan: return "Scan"; case .ai: return "AI Tutor"; case .notes: return "Study Notes" } }
    public var shortTitle: String { switch self { case .calculator: return "Calc"; case .scan: return "Scan"; case .ai: return "AI"; case .notes: return "Notes" } }
    public var icon: String { switch self { case .calculator: return "plus.slash.minus"; case .scan: return "camera.viewfinder"; case .ai: return "sparkles"; case .notes: return "square.and.pencil" } }
}

@Observable
public final class WorkspaceRepository {
    public static let shared = WorkspaceRepository()
    public private(set) var documents: [WorkspaceDocument] = []
    public var pendingContext: WorkspaceContext?

    private let fileManager: FileManager
    private let storageURL: URL

    public init(fileManager: FileManager = .default, directoryURL: URL? = nil) {
        self.fileManager = fileManager
        let base = directoryURL ?? (fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory)
        let directory = directoryURL == nil ? base.appendingPathComponent("LiquidCalc/Workspace", isDirectory: true) : base
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.storageURL = directory.appendingPathComponent("documents.json")
        load()
    }

    @discardableResult
    public func create(title: String = "Untitled note", markdown: String = "", tags: [String] = [], attachments: [WorkspaceAttachment] = []) -> WorkspaceDocument {
        let document = WorkspaceDocument(title: title, markdown: markdown, tags: normalized(tags), attachments: attachments)
        documents.insert(document, at: 0)
        save()
        return document
    }

    public func upsert(_ document: WorkspaceDocument) {
        var updated = document
        updated.title = updated.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled note" : updated.title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.tags = normalized(updated.tags)
        updated.updatedAt = Date()
        if let index = documents.firstIndex(where: { $0.id == updated.id }) {
            if updated.attachments.isEmpty { updated.attachments = documents[index].attachments }
            if updated.createdAt > documents[index].createdAt { updated.createdAt = documents[index].createdAt }
            documents[index] = updated
        } else { documents.insert(updated, at: 0) }
        documents.sort { $0.updatedAt > $1.updatedAt }
        save()
    }

    public func delete(id: UUID) {
        documents.removeAll { $0.id == id }
        save()
    }

    public func search(_ query: String, tag: String? = nil) -> [WorkspaceDocument] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return documents.filter { document in
            let tagMatches = tag.map { document.tags.contains($0) } ?? true
            guard tagMatches else { return false }
            return needle.isEmpty || document.title.lowercased().contains(needle) || document.markdown.lowercased().contains(needle) || document.tags.contains(where: { $0.lowercased().contains(needle) })
        }
    }

    public func saveContext(_ context: WorkspaceContext, into documentID: UUID? = nil) -> WorkspaceDocument {
        if let documentID, let index = documents.firstIndex(where: { $0.id == documentID }) {
            documents[index].markdown += (documents[index].markdown.isEmpty ? "" : "\n\n") + context.markdownBlock
            documents[index].attachments.append(WorkspaceAttachment(kind: attachmentKind(for: context), summary: String(context.markdownBlock.prefix(120))))
            documents[index].updatedAt = Date()
            save()
            return documents[index]
        }
        return create(
            title: title(for: context),
            markdown: context.markdownBlock,
            tags: ["study"],
            attachments: [WorkspaceAttachment(kind: attachmentKind(for: context), summary: String(context.markdownBlock.prefix(120)))]
        )
    }

    private func attachmentKind(for context: WorkspaceContext) -> WorkspaceAttachment.Kind {
        switch context { case .calculation: return .calculation; case .scan: return .scan; case .ai, .graph, .drawing: return .aiAnswer; case .note: return .calculation }
    }

    private func title(for context: WorkspaceContext) -> String {
        switch context { case .calculation: return "Calculation"; case .scan: return "Scanned problem"; case .ai: return "AI study note"; case .graph: return "Graph study note"; case .drawing: return "Handwritten work"; case .note: return "Study note" }
    }

    private func normalized(_ tags: [String]) -> [String] {
        Array(Set(tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty })).sorted()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(documents) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL), let decoded = try? JSONDecoder().decode([WorkspaceDocument].self, from: data) else { return }
        documents = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }
}
