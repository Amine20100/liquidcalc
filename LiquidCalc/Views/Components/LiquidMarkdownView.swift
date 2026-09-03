//
//  LiquidMarkdownView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  High-Performance Markdown & LaTeX Math Typography Engine
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Markdown Element AST Model

public enum MarkdownElement: Identifiable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case codeBlock(language: String, code: String)
    case mathDisplay(formula: String)
    case quote(text: String)
    case bulletItem(text: String)
    case table(headers: [String], rows: [[String]])
    case divider
    
    public var id: String {
        switch self {
        case .heading(let l, let t): return "h-\(l)-\(t.prefix(20))"
        case .paragraph(let t): return "p-\(t.prefix(25))"
        case .codeBlock(let lang, let c): return "code-\(lang)-\(c.prefix(20))"
        case .mathDisplay(let f): return "math-\(f.prefix(20))"
        case .quote(let t): return "q-\(t.prefix(25))"
        case .bulletItem(let t): return "b-\(t.prefix(20))"
        case .table(let h, _): return "table-\(h.joined().prefix(20))"
        case .divider: return "hr-\(UUID().uuidString)"
        }
    }
}

// MARK: - Markdown Parser

public struct LiquidMarkdownParser {
    public static func parse(_ rawText: String) -> [MarkdownElement] {
        var elements: [MarkdownElement] = []
        let lines = rawText.components(separatedBy: "\n")
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 1. Math Display Block ($$ ... $$)
            if trimmed.hasPrefix("$$") {
                if trimmed.hasSuffix("$$") && trimmed.count > 4 {
                    let formula = String(trimmed.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
                    elements.append(.mathDisplay(formula: formula))
                    i += 1
                    continue
                } else {
                    var mathLines: [String] = []
                    let firstLine = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    if !firstLine.isEmpty { mathLines.append(firstLine) }
                    i += 1
                    while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasSuffix("$$") {
                        mathLines.append(lines[i])
                        i += 1
                    }
                    if i < lines.count {
                        let lastLine = lines[i].trimmingCharacters(in: .whitespaces)
                        let stripped = String(lastLine.dropLast(2)).trimmingCharacters(in: .whitespaces)
                        if !stripped.isEmpty { mathLines.append(stripped) }
                        i += 1
                    }
                    elements.append(.mathDisplay(formula: mathLines.joined(separator: "\n")))
                    continue
                }
            }
            
            // 2. Fenced Code Blocks (```lang ... ```)
            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 } // consume closing ```
                elements.append(.codeBlock(language: language.isEmpty ? "text" : language, code: codeLines.joined(separator: "\n")))
                continue
            }
            
            // 3. Headings (# H1, ## H2, ### H3)
            if trimmed.hasPrefix("### ") {
                elements.append(.heading(level: 3, text: String(trimmed.dropFirst(4))))
                i += 1
                continue
            } else if trimmed.hasPrefix("## ") {
                elements.append(.heading(level: 2, text: String(trimmed.dropFirst(3))))
                i += 1
                continue
            } else if trimmed.hasPrefix("# ") {
                elements.append(.heading(level: 1, text: String(trimmed.dropFirst(2))))
                i += 1
                continue
            }
            
            // 4. Blockquotes (> text)
            if trimmed.hasPrefix("> ") {
                var quoteLines: [String] = [String(trimmed.dropFirst(2))]
                i += 1
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("> ") {
                    let nextQuote = lines[i].trimmingCharacters(in: .whitespaces)
                    quoteLines.append(String(nextQuote.dropFirst(2)))
                    i += 1
                }
                elements.append(.quote(text: quoteLines.joined(separator: "\n")))
                continue
            }
            
            // 5. Horizontal Rules (---, ***)
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                elements.append(.divider)
                i += 1
                continue
            }
            
            // 6. Bullet Lists (* item, - item)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                elements.append(.bulletItem(text: String(trimmed.dropFirst(2))))
                i += 1
                continue
            }
            
            // 7. Markdown Tables (| a | b |)
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && lines.count > i + 1 && lines[i+1].contains("---") {
                let headerCols = parseTableRow(trimmed)
                i += 2 // skip header and separator row
                var tableRows: [[String]] = []
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    tableRows.append(parseTableRow(lines[i].trimmingCharacters(in: .whitespaces)))
                    i += 1
                }
                elements.append(.table(headers: headerCols, rows: tableRows))
                continue
            }
            
            // 8. Paragraphs / Text
            if !trimmed.isEmpty {
                elements.append(.paragraph(text: line))
            }
            
            i += 1
        }
        
        return elements
    }
    
    private static func parseTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|") && trimmed.hasSuffix("|") else { return [] }
        let stripped = String(trimmed.dropFirst().dropLast())
        return stripped.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - Main LiquidMarkdownView

public struct LiquidMarkdownView: View {
    public let text: String
    public let isAnimated: Bool
    
    public init(text: String, isAnimated: Bool = false) {
        self.text = text
        self.isAnimated = isAnimated
    }
    
    public var body: some View {
        let elements = LiquidMarkdownParser.parse(text)
        
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(elements.enumerated()), id: \.offset) { _, element in
                renderElement(element)
            }
        }
    }
    
    @ViewBuilder
    private func renderElement(_ element: MarkdownElement) -> some View {
        switch element {
        case .heading(let level, let text):
            headingView(level: level, text: text)
        case .paragraph(let text):
            inlineMathParagraphView(text: text)
        case .codeBlock(let language, let code):
            codeBlockView(language: language, code: code)
        case .mathDisplay(let formula):
            mathDisplayCard(formula: formula)
        case .quote(let text):
            quoteView(text: text)
        case .bulletItem(let text):
            bulletView(text: text)
        case .table(let headers, let rows):
            tableView(headers: headers, rows: rows)
        case .divider:
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
                .padding(.vertical, 4)
        }
    }
    
    // MARK: - Subcomponents
    
    private func headingView(level: Int, text: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: level == 1 ? [.cyan, .blue] : (level == 2 ? [.purple, .indigo] : [.orange, .yellow]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: level == 1 ? 4 : 3, height: level == 1 ? 22 : (level == 2 ? 18 : 16))
            
            Text(text)
                .font(.system(size: level == 1 ? 18 : (level == 2 ? 16 : 14), weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.vertical, 2)
    }
    
    private func inlineMathParagraphView(text: String) -> some View {
        // Formatted text rendering supporting inline markdown and inline LaTeX math $...$
        Text(LocalizedStringKey(text))
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.92))
            .lineSpacing(4)
    }
    
    private func codeBlockView(language: String, code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                HStack(spacing: 5) {
                    Circle().fill(Color.red.opacity(0.7)).frame(width: 8, height: 8)
                    Circle().fill(Color.yellow.opacity(0.7)).frame(width: 8, height: 8)
                    Circle().fill(Color.green.opacity(0.7)).frame(width: 8, height: 8)
                    
                    Text(language.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .padding(.leading, 4)
                }
                
                Spacer()
                
                Button(action: {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = code
                    #endif
                    SoundAndHapticManager.shared.triggerHaptic(.selection)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.45))
            
            // Code Content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(red: 0.8, green: 0.9, blue: 1.0))
                    .padding(10)
            }
        }
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
        )
        .padding(.vertical, 2)
    }
    
    private func mathDisplayCard(formula: String) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "function")
                    .foregroundColor(.purple)
                    .font(.system(size: 11, weight: .bold))
                Text("MATH EXPRESSION")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)
                Spacer()
                Button(action: {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = formula
                    #endif
                    SoundAndHapticManager.shared.triggerHaptic(.selection)
                }) {
                    Text("Copy LaTeX")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            
            Text(formula)
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundColor(Color(red: 0.95, green: 0.96, blue: 1.0))
                .multilineTextAlignment(.center)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.purple.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.5), Color.cyan.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.vertical, 2)
    }
    
    private func quoteView(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.cyan)
                .frame(width: 3)
            
            Text(text)
                .font(.system(size: 13, weight: .regular))
                .italic()
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(3)
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.vertical, 2)
    }
    
    private func bulletView(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.cyan)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            
            Text(LocalizedStringKey(text))
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(3)
        }
        .padding(.vertical, 1)
    }
    
    private func tableView(headers: [String], rows: [[String]]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 12) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, h in
                        Text(h)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                            .frame(minWidth: 70, alignment: .leading)
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.06))
                
                Divider().background(Color.white.opacity(0.12))
                
                // Data rows
                ForEach(Array(rows.enumerated()), id: \.offset) { rIdx, row in
                    HStack(spacing: 12) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(minWidth: 70, alignment: .leading)
                        }
                    }
                    .padding(8)
                    .background(rIdx % 2 == 0 ? Color.white.opacity(0.02) : Color.clear)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
            )
        }
        .padding(.vertical, 4)
    }
}
