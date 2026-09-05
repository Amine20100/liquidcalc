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
            ZStack(alignment: .bottom) {
                Color(red: 0.05, green: 0.06, blue: 0.09)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    documentLibraryBar
                    modePickerToolbar
                    
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
                
                if mode != .preview {
                    floatingGlassInsertionBar
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: mode)
            .navigationTitle("Markdown Notebook")
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
                        
                        Menu("Templates") {
                            Button(action: insertEngineerTemplate) {
                                Label("Engineer Notebook Template", systemImage: "atom")
                            }
                            
                            Button(action: insertSampleEquations) {
                                Label("Maxwell's Equations", systemImage: "function")
                            }
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
        .padding(.horizontal, 16).padding(.vertical, 8).background(.black.opacity(0.22))
    }
    
    private var modePickerToolbar: some View {
        HStack(spacing: 10) {
            Picker("Mode", selection: $mode) {
                ForEach(EditorMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            
            // Seamless 1-tap quick toggle between Live Rendered View and Source Markdown Editor
            Button(action: toggleEditorPreview) {
                HStack(spacing: 5) {
                    Image(systemName: mode == .preview ? "pencil.line" : "eye.fill")
                    Text(mode == .preview ? "Edit" : "Preview")
                }
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundColor(.cyan)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.cyan.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.cyan.opacity(0.35), lineWidth: 0.9))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(mode == .preview ? "Switch to Source Markdown Editor" : "Switch to Live Rendered View")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.03))
    }
    
    private var floatingGlassInsertionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                glassInsertButton(title: "Math ($$)", icon: "function", insertText: "\n$$\n\\int_{a}^{b} f(x) dx = F(b) - F(a)\n$$\n")
                glassInsertButton(title: "Fraction", icon: "divide", insertText: "\\frac{a}{b}")
                glassInsertButton(title: "Table", icon: "tablecells", insertText: "\n| Variable | Symbol | Value |\n| :--- | :--- | :--- |\n| Velocity | v | 25 m/s |\n| Time | t | 5 s |\n")
                glassInsertButton(title: "Callout", icon: "quote.bubble.fill", insertText: "\n> [!NOTE]\n> Key theorem statement or insight.\n")
                glassInsertButton(title: "Code Block", icon: "chevron.left.forwardslash.chevron.right", insertText: "\n```swift\nlet result = 42\n```\n")
                glassInsertButton(title: "Task", icon: "checkmark.square", insertText: "\n- [ ] ")
                
                Divider().frame(height: 18).background(Color.white.opacity(0.25))
                
                glassSymbolButton("√", insert: "\\sqrt{x}")
                glassSymbolButton("π", insert: "\\pi")
                glassSymbolButton("∑", insert: "\\sum_{i=1}^{n} x_i")
                glassSymbolButton("∫", insert: "\\int_{a}^{b} f(x) dx")
                glassSymbolButton("x²", insert: "x^2")
                glassSymbolButton("lim", insert: "\\lim_{x \\to 0}")
                glassSymbolButton("±", insert: "\\pm")
                glassSymbolButton("≠", insert: "\\neq")
                glassSymbolButton("≤", insert: "\\leq")
                glassSymbolButton("≥", insert: "\\geq")
                glassSymbolButton("∞", insert: "\\infty")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.08, green: 0.1, blue: 0.15).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.5), Color.purple.opacity(0.35), Color.white.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.1
                        )
                )
                .shadow(color: Color.black.opacity(0.55), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func glassInsertButton(title: String, icon: String, insertText: String) -> some View {
        Button(action: {
            insertSnippet(insertText)
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundColor(.cyan)
            .padding(.horizontal, 9)
            .padding(.vertical, 5.5)
            .background(Color.cyan.opacity(0.1))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.cyan.opacity(0.3), lineWidth: 0.8))
        }
    }
    
    private func glassSymbolButton(_ title: String, insert: String) -> some View {
        Button(action: {
            insertSnippet(insert)
        }) {
            Text(title)
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 9)
                .padding(.vertical, 5.5)
                .background(Color.white.opacity(0.07))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
        }
    }
    
    private func insertSnippet(_ snippet: String) {
        markdownContent.append(snippet)
        SoundAndHapticManager.shared.triggerHaptic(.selection)
    }
    
    private func toggleEditorPreview() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            if mode == .preview {
                mode = .edit
            } else {
                mode = .preview
            }
        }
        SoundAndHapticManager.shared.triggerHaptic(.selection)
    }
    
    private var editorView: some View {
        TextEditor(text: $markdownContent)
            .font(.system(size: 13.5, design: .monospaced))
            .foregroundColor(.white)
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.07, green: 0.08, blue: 0.12))
            .padding(8)
            .padding(.bottom, mode != .preview ? 64 : 0)
    }
    
    private var previewView: some View {
        ScrollView {
            LiquidMarkdownView(text: markdownContent, onTaskToggle: { lineIndex in
                toggleTaskAtLine(lineIndex)
            })
            .padding(16)
            .padding(.bottom, mode != .preview ? 64 : 16)
        }
        .background(Color(red: 0.05, green: 0.06, blue: 0.09))
    }
    
    private func toggleTaskAtLine(_ lineIndex: Int) {
        var lines = markdownContent.components(separatedBy: "\n")
        guard lineIndex >= 0 && lineIndex < lines.count else { return }
        let line = lines[lineIndex]
        
        let pairs: [(String, String)] = [
            ("- [ ]", "- [x]"),
            ("- [x]", "- [ ]"),
            ("- [X]", "- [ ]"),
            ("* [ ]", "* [x]"),
            ("* [x]", "* [ ]"),
            ("* [X]", "* [ ]"),
            ("+ [ ]", "+ [x]"),
            ("+ [x]", "+ [ ]"),
            ("+ [X]", "+ [ ]")
        ]
        
        for (target, replacement) in pairs {
            if let range = line.range(of: target) {
                var updated = line
                updated.replaceSubrange(range, with: replacement)
                lines[lineIndex] = updated
                break
            }
        }
        
        withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
            markdownContent = lines.joined(separator: "\n")
        }
        SoundAndHapticManager.shared.triggerHaptic(.selection)
    }
    
    private func copyToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = markdownContent
        #endif
        SoundAndHapticManager.shared.triggerHaptic(.success)
    }
    
    private func insertEngineerTemplate() {
        let template = """
        # Engineering Notebook: Harmonic Oscillator
        
        > [!NOTE]
        > Second-order linear differential equation describing damped harmonic motion.
        
        ## 1. Governing Equation & Derivation
        $$
        \\begin{aligned}
        m \\frac{d^2 x}{dt^2} + c \\frac{dx}{dt} + k x &= 0 \\\\
        \\frac{d^2 x}{dt^2} + 2\\zeta\\omega_n \\frac{dx}{dt} + \\omega_n^2 x &= 0 \\\\
        \\boxed{\\omega_n = \\sqrt{\\frac{k}{m}}}
        \\end{aligned}
        $$
        
        ## 2. Parameter Specifications
        | Parameter | Symbol | Design Value | Status |
        | :--- | :--- | :--- | :--- |
        | Mass | m | 2.50 kg | Nominal |
        | Spring Constant | k | 400 N/m | Verified |
        | Natural Frequency | \\omega_n | 12.65 rad/s | Calibrated |
        
        ## 3. Verification Checklist
        - [x] Measure spring stiffness constant
        - [x] Calculate undamped natural frequency \\omega_n
        - [ ] Verify critical damping ratio \\zeta \\ge 1.0
        - [ ] Perform numerical step response simulation in Swift
        
        ```swift
        // Autonomous solver simulation
        let k: Double = 400.0
        let m: Double = 2.5
        let omegaN = sqrt(k / m)
        print("Natural frequency: \\(omegaN) rad/s")
        ```
        """
        if !markdownContent.isEmpty && !markdownContent.hasSuffix("\n\n") {
            markdownContent.append("\n\n")
        }
        markdownContent.append(template)
        SoundAndHapticManager.shared.triggerHaptic(.selection)
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
