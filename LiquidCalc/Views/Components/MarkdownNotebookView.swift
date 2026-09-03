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
    
    @State private var markdownContent: String = """
    # LiquidCalc Mathematical Derivation
    
    Calculations and notes with **LaTeX** mathematical notation and code blocks:
    
    ### 1. Fundamental Theorem of Calculus
    $$ \\int_{a}^{b} f(x) dx = F(b) - F(a) $$
    
    ### 2. Kinetic & Mass-Energy Equivalence
    $$ E = mc^2 $$
    
    > [!NOTE]
    > Velocity $v$ approaching speed of light $c$ requires relativistic momentum.
    
    ### 3. Algorithm Implementation
    ```swift
    func integral(f: (Double) -> Double, from a: Double, to b: Double) -> Double {
        let n = 1000
        let h = (b - a) / Double(n)
        return (0..<n).map { f(a + Double($0) * h) * h }.reduce(0, +)
    }
    ```
    """
    
    enum EditorMode: String, CaseIterable {
        case edit = "Editor"
        case split = "Split"
        case preview = "Preview"
    }
    
    @State private var mode: EditorMode = .split
    @State private var showCopiedAlert: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.09)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.cyan)
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
        }
    }
    
    // MARK: - Subcomponents
    
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
}
