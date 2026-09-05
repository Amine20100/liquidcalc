//
//  MarkdownNotebookView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Interactive Markdown Math & Calculation Scratchpad
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct MarkdownNotebookView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var workspace = WorkspaceRepository.shared
    @Bindable private var subscriptionManager = SubscriptionManager.shared
    private let isEmbedded: Bool
    
    @State private var markdownContent: String = ""
    @State private var documentTitle: String = "Untitled note"
    @State private var tagText: String = ""
    @State private var selectedDocumentID: UUID?
    @State private var searchText: String = ""
    @State private var showCloudSyncSheet: Bool = false
    
    enum EditorMode: String, CaseIterable {
        case edit = "Editor"
        case split = "Split"
        case preview = "Preview"
    }
    
    @State private var mode: EditorMode = .split
    @State private var showCopiedAlert: Bool = false
    
    public init(isEmbedded: Bool = false) { self.isEmbedded = isEmbedded }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.09)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    documentLibraryBar
                    modePickerToolbar
                    quickSymbolBar
                    
                    switch mode {
                    case .edit:
                        editorView
                    case .split:
                        VStack(spacing: 0) {
                            editorView
                                .frame(maxHeight: 280)
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 1)
                            
                            previewView
                        }
                    case .preview:
                        previewView
                    }
                }
            }
            .navigationTitle("Math Scratchpad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isEmbedded {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                            .foregroundColor(.cyan)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: copyToClipboard) {
                            Label("Copy Markdown", systemImage: "doc.on.doc")
                        }
                        
                        Button(action: insertSampleEquations) {
                            Label("Insert Template", systemImage: "text.badge.plus")
                        }
                        
                        Button(role: .destructive, action: { markdownContent = "" }) {
                            Label("Clear Note", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.cyan)
                    }
                }
            }
            .sheet(isPresented: $showCloudSyncSheet) {
                CloudSyncSheetView()
                    .presentationDetents([.medium, .large])
            }
        }
        .onAppear(perform: loadInitialDocument)
        .onChange(of: markdownContent) { _, _ in saveCurrentDocument() }
        .onChange(of: documentTitle) { _, _ in saveCurrentDocument() }
        .onChange(of: tagText) { _, _ in saveCurrentDocument() }
    }
    
    // MARK: - Subcomponents

    private var documentLibraryBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(workspace.search(searchText)) { document in
                        Button(document.title) { select(document) }
                    }
                    Divider()
                    Button { createDocument() } label: { Label("New note", systemImage: "plus") }
                } label: {
                    Label("Library", systemImage: "books.vertical.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.cyan).frame(minHeight: 36)
                }
                TextField("Note title", text: $documentTitle).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Button { createDocument() } label: { Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundStyle(.cyan) }
                    .accessibilityLabel("Create note")
            }
            HStack(spacing: 8) {
                TextField("Search notes", text: $searchText).font(.system(size: 11)).foregroundStyle(.white).padding(.horizontal, 9).frame(height: 32).background(.white.opacity(0.06), in: Capsule())
                TextField("tags, comma separated", text: $tagText).font(.system(size: 11)).foregroundStyle(.white).padding(.horizontal, 9).frame(height: 32).background(.white.opacity(0.06), in: Capsule())

                Button(action: { showCloudSyncSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: subscriptionManager.isPaid ? "cloud.sun.fill" : "icloud.fill")
                            .font(.system(size: 10))
                            .foregroundColor(subscriptionManager.isPaid ? .purple : .cyan)
                        Text(subscriptionManager.cloudSyncStatusPillText)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(Color.white.opacity(0.06), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cloud Sync: \(subscriptionManager.cloudSyncStatusPillText)")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8).background(.black.opacity(0.22))
    }
    
    private var modePickerToolbar: some View {
        Picker("Mode", selection: $mode) {
            ForEach(EditorMode.allCases, id: \.self) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
    }
    
    private var quickSymbolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                symbolButton("∫", insert: "\\int_{a}^{b} f(x) dx")
                symbolButton("∑", insert: "\\sum_{i=1}^{n} x_i")
                symbolButton("√", insert: "\\sqrt{x}")
                symbolButton("π", insert: "\\pi")
                symbolButton("x²", insert: "x^2")
                symbolButton("lim", insert: "\\lim_{x \\to 0}")
                symbolButton("$$", insert: "\n$$\n\n$$\n")
                symbolButton("```swift", insert: "\n```swift\n\n```\n")
                symbolButton("# H2", insert: "\n## ")
                symbolButton("> Note", insert: "\n> ")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .background(Color.black.opacity(0.3))
    }
    
    private func symbolButton(_ title: String, insert: String) -> some View {
        Button(action: {
            markdownContent.append(insert)
            SoundAndHapticManager.shared.triggerHaptic(.selection)
        }) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.cyan.opacity(0.3), lineWidth: 0.8))
        }
    }
    
    private var editorView: some View {
        TextEditor(text: $markdownContent)
            .font(.system(size: 13, design: .monospaced))
            .foregroundColor(.white)
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.07, green: 0.08, blue: 0.12))
            .padding(8)
    }
    
    private var previewView: some View {
        ScrollView {
            LiquidMarkdownView(text: markdownContent)
                .padding(16)
        }
        .background(Color(red: 0.05, green: 0.06, blue: 0.09))
    }
    
    private func copyToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = markdownContent
        #endif
        SoundAndHapticManager.shared.triggerHaptic(.success)
    }
    
    private func insertSampleEquations() {
        markdownContent.append("""
        
        ### Maxwell's Equations
        $$ \\nabla \\cdot \\mathbf{E} = \\frac{\\rho}{\\varepsilon_0} $$
        $$ \\nabla \\cdot \\mathbf{B} = 0 $$
        """)
        SoundAndHapticManager.shared.triggerHaptic(.selection)
    }

    private func loadInitialDocument() {
        if let context = workspace.pendingContext {
            let document = workspace.saveContext(context)
            workspace.pendingContext = nil
            select(document)
        } else if let existing = workspace.documents.first {
            select(existing)
        } else {
            createDocument()
        }
    }

    private func createDocument() {
        let document = workspace.create()
        select(document)
    }

    private func select(_ document: WorkspaceDocument) {
        selectedDocumentID = document.id
        documentTitle = document.title
        markdownContent = document.markdown
        tagText = document.tags.joined(separator: ", ")
    }

    private func saveCurrentDocument() {
        guard let selectedDocumentID else { return }
        let tags = tagText.split(separator: ",").map { String($0) }
        workspace.upsert(WorkspaceDocument(id: selectedDocumentID, title: documentTitle, markdown: markdownContent, tags: tags))
    }
}
