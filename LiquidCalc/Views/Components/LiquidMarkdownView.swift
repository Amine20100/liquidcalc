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

// MARK: - Callout Block Types

public enum CalloutType: String, Sendable, CaseIterable {
    case note = "NOTE"
    case tip = "TIP"
    case important = "IMPORTANT"
    case warning = "WARNING"
    case caution = "CAUTION"
    
    public var iconName: String {
        switch self {
        case .note: return "info.circle.fill"
        case .tip: return "lightbulb.fill"
        case .important: return "exclamationmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .caution: return "flame.fill"
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .note: return Color(red: 0.22, green: 0.72, blue: 1.0)
        case .tip: return Color(red: 0.28, green: 0.88, blue: 0.58)
        case .important: return Color(red: 0.78, green: 0.48, blue: 1.0)
        case .warning: return Color(red: 1.0, green: 0.70, blue: 0.22)
        case .caution: return Color(red: 1.0, green: 0.38, blue: 0.42)
        }
    }
    
    public var defaultTitle: String {
        switch self {
        case .note: return "Note"
        case .tip: return "Tip"
        case .important: return "Important"
        case .warning: return "Warning"
        case .caution: return "Caution"
        }
    }
}

// MARK: - Task List Item Model

public struct TaskItem: Identifiable, Sendable, Equatable {
    public let id: String
    public var isChecked: Bool
    public var text: String
    public var lineIndex: Int
    
    public init(id: String = UUID().uuidString, isChecked: Bool, text: String, lineIndex: Int) {
        self.id = id
        self.isChecked = isChecked
        self.text = text
        self.lineIndex = lineIndex
    }
}

// MARK: - Markdown Element AST Model

public enum MarkdownElement: Identifiable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case codeBlock(language: String, code: String)
    case mathDisplay(formula: String)
    case quote(text: String)
    case callout(type: CalloutType, title: String, content: String)
    case taskItem(item: TaskItem)
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
        case .callout(let type, let title, let content): return "callout-\(type.rawValue)-\(title.prefix(15))-\(content.prefix(15))"
        case .taskItem(let item): return "task-\(item.lineIndex)-\(item.isChecked)-\(item.text.prefix(20))"
        case .bulletItem(let t): return "b-\(t.prefix(20))"
        case .table(let h, _): return "table-\(h.joined().prefix(20))"
        case .divider: return "hr"
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
                if trimmed.hasSuffix("$$") && trimmed.count >= 4 {
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
            
            // 3. Headings (# H1, ## H2, ### H3, #### H4)
            if trimmed.hasPrefix("#### ") {
                elements.append(.heading(level: 4, text: String(trimmed.dropFirst(5))))
                i += 1
                continue
            } else if trimmed.hasPrefix("### ") {
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
            
            // 4. Interactive Task List Items (- [ ] or - [x] or * [ ] or * [x] or + [ ] or + [x])
            if isTaskLine(trimmed) {
                let isChecked = trimmed.contains("[x]") || trimmed.contains("[X]")
                var text = ""
                if trimmed.count >= 6 {
                    text = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                }
                elements.append(.taskItem(item: TaskItem(isChecked: isChecked, text: text, lineIndex: i)))
                i += 1
                continue
            }
            
            // 5. Callouts & Blockquotes (> [!NOTE] or > text)
            if trimmed.hasPrefix(">") {
                let strippedFirst = stripQuoteMarker(trimmed)
                
                // Check if this is an Obsidian / GitHub callout block
                if let calloutMatch = parseCalloutHeader(strippedFirst) {
                    var calloutLines: [String] = []
                    i += 1
                    while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                        let nextTrimmed = lines[i].trimmingCharacters(in: .whitespaces)
                        calloutLines.append(stripQuoteMarker(nextTrimmed))
                        i += 1
                    }
                    elements.append(.callout(type: calloutMatch.type, title: calloutMatch.title, content: calloutLines.joined(separator: "\n")))
                    continue
                } else {
                    // Regular blockquote
                    var quoteLines: [String] = [strippedFirst]
                    i += 1
                    while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                        let nextQuote = lines[i].trimmingCharacters(in: .whitespaces)
                        quoteLines.append(stripQuoteMarker(nextQuote))
                        i += 1
                    }
                    elements.append(.quote(text: quoteLines.joined(separator: "\n")))
                    continue
                }
            }
            
            // 6. Horizontal Rules (---, ***, ___)
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                elements.append(.divider)
                i += 1
                continue
            }
            
            // 7. Bullet Lists (* item, - item, + item)
            if (trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ")) && !isTaskLine(trimmed) {
                elements.append(.bulletItem(text: String(trimmed.dropFirst(2))))
                i += 1
                continue
            }
            
            // 8. Markdown Tables (| a | b |)
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
            
            // 9. Paragraphs / Text
            if !trimmed.isEmpty {
                elements.append(.paragraph(text: line))
            }
            
            i += 1
        }
        
        return elements
    }
    
    private static func isTaskLine(_ line: String) -> Bool {
        let prefixes = ["- [ ]", "- [x]", "- [X]", "* [ ]", "* [x]", "* [X]", "+ [ ]", "+ [x]", "+ [X]"]
        for p in prefixes {
            if line == p || line.hasPrefix(p + " ") {
                return true
            }
        }
        return false
    }
    
    private static func stripQuoteMarker(_ line: String) -> String {
        var str = line
        if str.hasPrefix(">") {
            str = String(str.dropFirst())
            if str.hasPrefix(" ") {
                str = String(str.dropFirst())
            }
        }
        return str
    }
    
    private static func parseCalloutHeader(_ line: String) -> (type: CalloutType, title: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("[!") else { return nil }
        
        guard let closeIdx = trimmed.firstIndex(of: "]") else { return nil }
        let tag = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<closeIdx]).uppercased()
        
        let type: CalloutType
        switch tag {
        case "NOTE", "INFO": type = .note
        case "TIP": type = .tip
        case "IMPORTANT": type = .important
        case "WARNING": type = .warning
        case "CAUTION", "DANGER": type = .caution
        default: return nil
        }
        
        let afterTag = String(trimmed[trimmed.index(after: closeIdx)...]).trimmingCharacters(in: .whitespaces)
        let title = afterTag.isEmpty ? type.defaultTitle : afterTag
        return (type, title)
    }
    
    private static func parseTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|") && trimmed.hasSuffix("|") else { return [] }
        let stripped = String(trimmed.dropFirst().dropLast())
        return stripped.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - LaTeX Math Parser & AST Models

public enum LaTeXRenderToken: Sendable {
    case text(String)
    case fraction(numerator: [LaTeXRenderToken], denominator: [LaTeXRenderToken])
    case radical(degree: String?, radicand: [LaTeXRenderToken])
    case boxed(content: [LaTeXRenderToken])
    case superscript(base: String, exp: String)
    case subscriptToken(base: String, sub: String)
}

public struct LaTeXStep: Identifiable, Sendable {
    public let id: String
    public let stepNumber: Int
    public let label: String
    public let rawLatex: String
    public let tokens: [LaTeXRenderToken]
    public let isBoxed: Bool
    
    public init(stepNumber: Int, label: String, rawLatex: String, tokens: [LaTeXRenderToken], isBoxed: Bool) {
        self.id = "step-\(stepNumber)-\(UUID().uuidString)"
        self.stepNumber = stepNumber
        self.label = label
        self.rawLatex = rawLatex
        self.tokens = tokens
        self.isBoxed = isBoxed
    }
}

public struct LaTeXDerivation: Identifiable, Sendable {
    public let id: String = UUID().uuidString
    public let isMultiStep: Bool
    public let steps: [LaTeXStep]
    
    public init(steps: [LaTeXStep]) {
        self.steps = steps
        self.isMultiStep = steps.count > 1
    }
}

public struct LaTeXMathEngine {
    
    private static let greekAndMathSymbols: [(String, String)] = [
        // Greek lowercase
        ("\\alpha", "α"), ("\\beta", "β"), ("\\gamma", "γ"), ("\\delta", "δ"),
        ("\\epsilon", "ε"), ("\\varepsilon", "ε"), ("\\zeta", "ζ"), ("\\eta", "η"),
        ("\\theta", "θ"), ("\\vartheta", "ϑ"), ("\\iota", "ι"), ("\\kappa", "κ"),
        ("\\lambda", "λ"), ("\\mu", "μ"), ("\\nu", "ν"), ("\\xi", "ξ"),
        ("\\pi", "π"), ("\\varpi", "ϖ"), ("\\rho", "ρ"), ("\\varrho", "ϱ"),
        ("\\sigma", "σ"), ("\\varsigma", "ς"), ("\\tau", "τ"), ("\\upsilon", "υ"),
        ("\\phi", "φ"), ("\\varphi", "ϕ"), ("\\chi", "χ"), ("\\psi", "ψ"), ("\\omega", "ω"),
        
        // Greek uppercase
        ("\\Gamma", "Γ"), ("\\Delta", "Δ"), ("\\Theta", "Θ"), ("\\Lambda", "Λ"),
        ("\\Xi", "Ξ"), ("\\Pi", "Π"), ("\\Sigma", "Σ"), ("\\Upsilon", "Υ"),
        ("\\Phi", "Φ"), ("\\Psi", "Ψ"), ("\\Omega", "Ω"),
        
        // Calculus & Vector Operators
        ("\\nabla", "∇"), ("\\partial", "∂"), ("\\infty", "∞"),
        ("\\iint", "∬"), ("\\iiint", "∭"), ("\\oint", "∮"), ("\\int", "∫"),
        ("\\sum", "∑"), ("\\prod", "∏"),
        
        // Logic & Relations
        ("\\approx", "≈"), ("\\neq", "≠"), ("\\ne", "≠"),
        ("\\leq", "≤"), ("\\le", "≤"), ("\\geq", "≥"), ("\\ge", "≥"),
        ("\\pm", "±"), ("\\mp", "∓"), ("\\times", "×"), ("\\div", "÷"),
        ("\\cdot", "·"), ("\\in", "∈"), ("\\notin", "∉"),
        ("\\subset", "⊂"), ("\\supset", "⊃"), ("\\cup", "∪"), ("\\cap", "∩"),
        ("\\forall", "∀"), ("\\exists", "∃"),
        ("\\implies", "⟹"), ("\\iff", "⟺"), ("\\to", "→"), ("\\rightarrow", "→"),
        ("\\leftarrow", "←"), ("\\hbar", "ℏ")
    ]
    
    public static func sanitizeMathSigns(_ input: String) -> String {
        var str = input.replacingOccurrences(of: "−", with: "-")
        
        // Protect non-math code tokens
        let protectedCpp = "__LC_PROTECTED_CPP__"
        str = str.replacingOccurrences(of: "C++", with: protectedCpp)
        
        // Protect CLI flags: e.g. --verbose, --flag
        if let flagRegex = try? NSRegularExpression(pattern: "(?<=\\s|^)--([a-zA-Z0-9_-]+)") {
            str = flagRegex.stringByReplacingMatches(in: str, range: NSRange(location: 0, length: str.utf16.count), withTemplate: "__LC_FLAG_$1__")
        }
        
        // 1. Spaced & unspaced consecutive operators:
        // "- +" or "-+" or "-  +" -> "- "
        if let regex = try? NSRegularExpression(pattern: "-\\s*\\+") {
            str = regex.stringByReplacingMatches(in: str, range: NSRange(location: 0, length: str.utf16.count), withTemplate: "- ")
        }
        // "+ -" or "+-" or "+  -" -> "- "
        if let regex = try? NSRegularExpression(pattern: "\\+\\s*-") {
            str = regex.stringByReplacingMatches(in: str, range: NSRange(location: 0, length: str.utf16.count), withTemplate: "- ")
        }
        // "- -" -> "+ "
        if let regex = try? NSRegularExpression(pattern: "-\\s*-") {
            str = regex.stringByReplacingMatches(in: str, range: NSRange(location: 0, length: str.utf16.count), withTemplate: "+ ")
        }
        // "+ +" -> "+ "
        if let regex = try? NSRegularExpression(pattern: "\\+\\s*\\+") {
            str = regex.stringByReplacingMatches(in: str, range: NSRange(location: 0, length: str.utf16.count), withTemplate: "+ ")
        }
        // "+/-" -> "±", "-/+" -> "∓"
        if let regex = try? NSRegularExpression(pattern: "\\+\\s*/\\s*-") {
            str = regex.stringByReplacingMatches(in: str, range: NSRange(location: 0, length: str.utf16.count), withTemplate: "±")
        }
        if let regex = try? NSRegularExpression(pattern: "-\\s*/\\s*\\+") {
            str = regex.stringByReplacingMatches(in: str, range: NSRange(location: 0, length: str.utf16.count), withTemplate: "∓")
        }
        
        // 2. Parenthesized signs: e.g. "x - (+y)" -> "x - y", "x + (-y)" -> "x - y", "x - (-y)" -> "x + y"
        if let regex = try? NSRegularExpression(pattern: "-\\s*\\(\\s*\\+\\s*([^()]+?)\\s*\\)") {
            str = regex.stringByReplacingMatches(in: str, range: NSRange(location: 0, length: str.utf16.count), withTemplate: "- $1")
        }
        if let regex = try? NSRegularExpression(pattern: "\\+\\s*\\(\\s*-\\s*([^()]+?)\\s*\\)") {
            str = regex.stringByReplacingMatches(in: str, range: NSRange(location: 0, length: str.utf16.count), withTemplate: "- $1")
        }
        if let regex = try? NSRegularExpression(pattern: "-\\s*\\(\\s*-\\s*([^()]+?)\\s*\\)") {
            str = regex.stringByReplacingMatches(in: str, range: NSRange(location: 0, length: str.utf16.count), withTemplate: "+ $1")
        }
        if let regex = try? NSRegularExpression(pattern: "\\+\\s*\\(\\s*\\+\\s*([^()]+?)\\s*\\)") {
            str = regex.stringByReplacingMatches(in: str, range: NSRange(location: 0, length: str.utf16.count), withTemplate: "+ $1")
        }
        
        // Restore protected tokens
        str = str.replacingOccurrences(of: protectedCpp, with: "C++")
        if let restoreRegex = try? NSRegularExpression(pattern: "__LC_FLAG_([a-zA-Z0-9_-]+)__") {
            str = restoreRegex.stringByReplacingMatches(in: str, range: NSRange(location: 0, length: str.utf16.count), withTemplate: "--$1")
        }
        
        return str
    }
    
    public static func convertInlineFractions(_ input: String) -> String {
        var str = input
        while let range = str.range(of: "\\frac") ?? str.range(of: "\\dfrac") ?? str.range(of: "\\tfrac") {
            let after = range.upperBound
            if let (num, nextIdx) = extractBracedContent(str, from: after),
               let (den, endIdx) = extractBracedContent(str, from: nextIdx) {
                let numClean = num.trimmingCharacters(in: .whitespaces)
                let denClean = den.trimmingCharacters(in: .whitespaces)
                
                // Common Unicode fractions for simple numbers
                if let unicodeFrac = commonUnicodeFraction(num: numClean, den: denClean) {
                    str.replaceSubrange(range.lowerBound..<endIdx, with: unicodeFrac)
                    continue
                }
                
                let numFormatted = convertInlineFractions(convertSubAndSuperscripts(replaceSymbols(numClean)))
                let denFormatted = convertInlineFractions(convertSubAndSuperscripts(replaceSymbols(denClean)))
                
                let isNumSimple = !numFormatted.contains(" ") && !numFormatted.contains("+") && !numFormatted.contains("-")
                let isDenSimple = !denFormatted.contains(" ") && !denFormatted.contains("+") && !denFormatted.contains("-")
                
                let numStr = isNumSimple ? numFormatted : "(\(numFormatted))"
                let denStr = isDenSimple ? denFormatted : "(\(denFormatted))"
                let replacement = "\(numStr) / \(denStr)"
                str.replaceSubrange(range.lowerBound..<endIdx, with: replacement)
            } else {
                break
            }
        }
        
        // Also convert standalone plaintext fractions (e.g. 1/2, 3/4)
        str = convertPlaintextFractions(str)
        return str
    }
    
    public static func commonUnicodeFraction(num: String, den: String) -> String? {
        let n = num.trimmingCharacters(in: .whitespaces)
        let d = den.trimmingCharacters(in: .whitespaces)
        switch (n, d) {
        case ("1", "2"): return "½"
        case ("1", "3"): return "⅓"
        case ("2", "3"): return "⅔"
        case ("1", "4"): return "¼"
        case ("3", "4"): return "¾"
        case ("1", "5"): return "⅕"
        case ("2", "5"): return "⅖"
        case ("3", "5"): return "⅗"
        case ("4", "5"): return "⅘"
        case ("1", "6"): return "⅙"
        case ("5", "6"): return "⅚"
        case ("1", "8"): return "⅛"
        case ("3", "8"): return "⅜"
        case ("5", "8"): return "⅝"
        case ("7", "8"): return "⅞"
        default: return nil
        }
    }
    
    public static func convertPlaintextFractions(_ input: String) -> String {
        var str = input
        let fracMap: [(String, String)] = [
            ("1/2", "½"), ("1/3", "⅓"), ("2/3", "⅔"),
            ("1/4", "¼"), ("3/4", "¾"), ("1/5", "⅕"),
            ("2/5", "⅖"), ("3/5", "⅗"), ("4/5", "⅘"),
            ("1/6", "⅙"), ("5/6", "⅚"), ("1/8", "⅛"),
            ("3/8", "⅜"), ("5/8", "⅝"), ("7/8", "⅞")
        ]
        for (pattern, replacement) in fracMap {
            if let regex = try? NSRegularExpression(pattern: "(?<!/)(?<=\\b|\\s|\\()\(NSRegularExpression.escapedPattern(for: pattern))(?=\\b|\\s|\\)|$)(?!/)") {
                str = regex.stringByReplacingMatches(in: str, range: NSRange(location: 0, length: str.utf16.count), withTemplate: replacement)
            }
        }
        return str
    }
    
    public static func convertInlineRadicals(_ input: String) -> String {
        var str = input
        // 1. LaTeX \sqrt[degree]{radicand} or \sqrt{radicand}
        while let range = str.range(of: "\\sqrt") {
            var after = range.upperBound
            var degree: String? = nil
            if after < str.endIndex && str[after] == "[" {
                if let closeBracket = str[after...].firstIndex(of: "]") {
                    let rawDeg = String(str[str.index(after: after)..<closeBracket]).trimmingCharacters(in: .whitespaces)
                    degree = convertSubAndSuperscripts("^\(rawDeg)")
                    after = str.index(after: closeBracket)
                }
            }
            if let (radicand, endIdx) = extractBracedContent(str, from: after) {
                let radFormatted = convertSubAndSuperscripts(replaceSymbols(radicand))
                let prefix = degree != nil ? "\(degree!)√" : "√"
                let replacement = "\(prefix)(\(radFormatted))"
                str.replaceSubrange(range.lowerBound..<endIdx, with: replacement)
            } else {
                break
            }
        }
        
        // 2. Raw plaintext sqrt(...) e.g. sqrt(x^2 + 1) -> √(x² + 1)
        if let sqrtRegex = try? NSRegularExpression(pattern: "(?<![a-zA-Z0-9_\\\\])sqrt\\(([^)]+)\\)") {
            let nsStr = str as NSString
            let matches = sqrtRegex.matches(in: str, range: NSRange(location: 0, length: nsStr.length))
            for match in matches.reversed() {
                if let innerRange = Range(match.range(at: 1), in: str),
                   let fullRange = Range(match.range(at: 0), in: str) {
                    let inner = String(str[innerRange])
                    let formatted = convertSubAndSuperscripts(replaceSymbols(inner))
                    str.replaceSubrange(fullRange, with: "√(\(formatted))")
                }
            }
        }
        
        return str
    }
    
    public static func formatInlineMathExpression(_ expr: String) -> String {
        var str = expr.trimmingCharacters(in: .whitespaces)
        str = sanitizeMathSigns(str)
        str = replaceSymbols(str)
        str = convertInlineFractions(str)
        str = convertInlineRadicals(str)
        str = convertSubAndSuperscripts(str)
        return str
    }

    public static func replaceSymbols(_ input: String) -> String {
        var str = sanitizeMathSigns(input)
        for (pattern, replacement) in greekAndMathSymbols {
            str = str.replacingOccurrences(of: pattern, with: replacement)
        }
        // Clean LaTeX formatting wrappers
        str = str.replacingOccurrences(of: "\\mathbf", with: "")
        str = str.replacingOccurrences(of: "\\mathit", with: "")
        str = str.replacingOccurrences(of: "\\mathrm", with: "")
        str = str.replacingOccurrences(of: "\\text", with: "")
        str = str.replacingOccurrences(of: "\\left", with: "")
        str = str.replacingOccurrences(of: "\\right", with: "")
        str = str.replacingOccurrences(of: "\\quad", with: "   ")
        str = str.replacingOccurrences(of: "\\qquad", with: "      ")
        str = str.replacingOccurrences(of: "\\,", with: " ")
        str = str.replacingOccurrences(of: "\\;", with: " ")
        str = str.replacingOccurrences(of: "\\!", with: "")
        return str
    }
    
    public static func parseDerivation(_ formula: String) -> LaTeXDerivation {
        // Normalize LaTeX environment blocks
        var cleaned = formula.trimmingCharacters(in: .whitespacesAndNewlines)
        let envs = ["aligned", "aligned*", "align", "align*", "gather", "gather*", "split", "split*", "equation", "equation*", "multline", "multline*"]
        for env in envs {
            cleaned = cleaned.replacingOccurrences(of: "\\begin{\(env)}", with: "")
            cleaned = cleaned.replacingOccurrences(of: "\\end{\(env)}", with: "")
        }
        
        let rawSteps: [String]
        if cleaned.contains("\\\\") {
            rawSteps = cleaned.components(separatedBy: "\\\\")
        } else if cleaned.contains("\n") {
            rawSteps = cleaned.components(separatedBy: "\n")
        } else {
            rawSteps = [cleaned]
        }
        
        var steps: [LaTeXStep] = []
        var stepNum = 1
        
        for raw in rawSteps {
            var stepText = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if stepText.isEmpty { continue }
            
            // Clean alignment markers &= or &
            if stepText.hasPrefix("&=") {
                stepText = "= " + String(stepText.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            } else if stepText.hasPrefix("&") {
                stepText = String(stepText.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            stepText = stepText.replacingOccurrences(of: "&=", with: "= ")
            stepText = stepText.replacingOccurrences(of: "&", with: " ")
            
            // Check for \boxed{...}
            var isBoxed = false
            if stepText.contains("\\boxed") {
                isBoxed = true
            }
            
            let tokens = parseTokens(stepText)
            let label = isBoxed ? "Result" : "Step \(stepNum)"
            steps.append(LaTeXStep(stepNumber: stepNum, label: label, rawLatex: stepText, tokens: tokens, isBoxed: isBoxed))
            stepNum += 1
        }
        
        if steps.isEmpty {
            steps.append(LaTeXStep(stepNumber: 1, label: "Formula", rawLatex: formula, tokens: parseTokens(formula), isBoxed: false))
        }
        
        return LaTeXDerivation(steps: steps)
    }
    
    public static func parseTokens(_ latex: String) -> [LaTeXRenderToken] {
        var tokens: [LaTeXRenderToken] = []
        let preprocessed = replaceSymbols(latex)
        var i = preprocessed.startIndex
        var textBuffer = ""
        
        func flushBuffer() {
            if !textBuffer.isEmpty {
                tokens.append(.text(convertSubAndSuperscripts(textBuffer)))
                textBuffer = ""
            }
        }
        
        while i < preprocessed.endIndex {
            let remaining = preprocessed[i...]
            
            // 1. \frac{...}{...}, \dfrac{...}{...}, \tfrac{...}{...}
            if remaining.hasPrefix("\\frac") || remaining.hasPrefix("\\dfrac") || remaining.hasPrefix("\\tfrac") {
                flushBuffer()
                let offset = remaining.hasPrefix("\\frac") ? 5 : 6
                let afterFrac = preprocessed.index(i, offsetBy: offset)
                if let (num, nextIdx) = extractBracedContent(preprocessed, from: afterFrac),
                   let (den, endIdx) = extractBracedContent(preprocessed, from: nextIdx) {
                    let numTokens = parseTokens(num)
                    let denTokens = parseTokens(den)
                    tokens.append(.fraction(numerator: numTokens, denominator: denTokens))
                    i = endIdx
                    continue
                }
            }
            
            // 2. \sqrt[degree]{radicand} or \sqrt{radicand}
            if remaining.hasPrefix("\\sqrt") {
                flushBuffer()
                var afterSqrt = preprocessed.index(i, offsetBy: 5)
                var degree: String? = nil
                
                // Check for optional [degree]
                if afterSqrt < preprocessed.endIndex && preprocessed[afterSqrt] == "[" {
                    if let closeBracket = preprocessed[afterSqrt...].firstIndex(of: "]") {
                        degree = String(preprocessed[preprocessed.index(after: afterSqrt)..<closeBracket])
                        afterSqrt = preprocessed.index(after: closeBracket)
                    }
                }
                
                if let (radicand, endIdx) = extractBracedContent(preprocessed, from: afterSqrt) {
                    let radTokens = parseTokens(radicand)
                    tokens.append(.radical(degree: degree, radicand: radTokens))
                    i = endIdx
                    continue
                }
            }
            
            // 3. \boxed{content}
            if remaining.hasPrefix("\\boxed") {
                flushBuffer()
                let afterBoxed = preprocessed.index(i, offsetBy: 6)
                if let (content, endIdx) = extractBracedContent(preprocessed, from: afterBoxed) {
                    let contentTokens = parseTokens(content)
                    tokens.append(.boxed(content: contentTokens))
                    i = endIdx
                    continue
                }
            }
            
            // Normal character
            textBuffer.append(preprocessed[i])
            i = preprocessed.index(after: i)
        }
        
        flushBuffer()
        return tokens
    }
    
    private static func extractBracedContent(_ str: String, from start: String.Index) -> (content: String, next: String.Index)? {
        var idx = start
        // Skip leading whitespace
        while idx < str.endIndex && str[idx].isWhitespace {
            idx = str.index(after: idx)
        }
        guard idx < str.endIndex else { return nil }
        
        // If braced with { ... }
        if str[idx] == "{" {
            var depth = 1
            idx = str.index(after: idx)
            let contentStart = idx
            while idx < str.endIndex && depth > 0 {
                if str[idx] == "{" { depth += 1 }
                else if str[idx] == "}" { depth -= 1 }
                if depth > 0 {
                    idx = str.index(after: idx)
                }
            }
            if depth == 0 {
                let content = String(str[contentStart..<idx])
                return (content, str.index(after: idx))
            }
            return nil
        } else {
            // Single character argument
            let next = str.index(after: idx)
            return (String(str[idx]), next)
        }
    }
    
    public static func convertSubAndSuperscripts(_ text: String) -> String {
        var result = ""
        var i = text.startIndex
        
        let supMap: [Character: Character] = [
            "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
            "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
            "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
            "n": "ⁿ", "i": "ⁱ", "x": "ˣ", "y": "ʸ", "z": "ᶻ",
            "a": "ᵃ", "b": "ᵇ", "c": "ᶜ", "d": "ᵈ", "e": "ᵉ",
            "f": "ᶠ", "g": "ᵍ", "h": "ʰ", "j": "ʲ", "k": "ᵏ",
            "l": "ˡ", "m": "ᵐ", "o": "ᵒ", "p": "ᵖ", "r": "ʳ",
            "s": "ˢ", "t": "ᵗ", "u": "ᵘ", "v": "ᵛ", "w": "ʷ"
        ]
        
        let subMap: [Character: Character] = [
            "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
            "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
            "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
            "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ",
            "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ", "o": "ₒ",
            "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ",
            "v": "ᵥ", "x": "ₓ"
        ]
        
        while i < text.endIndex {
            let ch = text[i]
            
            // Superscript ^
            if ch == "^" {
                let nextIdx = text.index(after: i)
                if nextIdx < text.endIndex {
                    // 1. Braced ^{...}
                    if text[nextIdx] == "{" {
                        if let closeBrace = text[nextIdx...].firstIndex(of: "}") {
                            let exp = text[text.index(after: nextIdx)..<closeBrace]
                            for c in exp {
                                result.append(supMap[c] ?? c)
                            }
                            i = text.index(after: closeBrace)
                            continue
                        }
                    }
                    // 2. Parenthesized ^(...) e.g. x^(n+1) -> xⁿ⁺¹, e^(-x) -> e⁻ˣ, x^(2) -> x²
                    else if text[nextIdx] == "(" {
                        if let closeParen = text[nextIdx...].firstIndex(of: ")") {
                            let exp = text[text.index(after: nextIdx)..<closeParen]
                            for c in exp {
                                result.append(supMap[c] ?? c)
                            }
                            i = text.index(after: closeParen)
                            continue
                        }
                    }
                    // 3. Negative exponent or multi-digit: e.g. ^-3, ^-12, ^10, ^2026
                    else if text[nextIdx] == "-" || text[nextIdx].isNumber {
                        var endScan = nextIdx
                        if text[endScan] == "-" {
                            endScan = text.index(after: endScan)
                        }
                        while endScan < text.endIndex && text[endScan].isNumber {
                            endScan = text.index(after: endScan)
                        }
                        if endScan > nextIdx {
                            let token = text[nextIdx..<endScan]
                            for c in token {
                                result.append(supMap[c] ?? c)
                            }
                            i = endScan
                            continue
                        }
                    }
                    // 4. Single character or symbol
                    else {
                        let expChar = text[nextIdx]
                        result.append(supMap[expChar] ?? expChar)
                        i = text.index(after: nextIdx)
                        continue
                    }
                }
            }
            
            // Subscript _
            if ch == "_" {
                let nextIdx = text.index(after: i)
                if nextIdx < text.endIndex {
                    // 1. Braced _{...}
                    if text[nextIdx] == "{" {
                        if let closeBrace = text[nextIdx...].firstIndex(of: "}") {
                            let sub = text[text.index(after: nextIdx)..<closeBrace]
                            for c in sub {
                                result.append(subMap[c] ?? c)
                            }
                            i = text.index(after: closeBrace)
                            continue
                        }
                    }
                    // 2. Parenthesized _(...) e.g. x_(i+1) -> xᵢ₊₁
                    else if text[nextIdx] == "(" {
                        if let closeParen = text[nextIdx...].firstIndex(of: ")") {
                            let sub = text[text.index(after: nextIdx)..<closeParen]
                            for c in sub {
                                result.append(subMap[c] ?? c)
                            }
                            i = text.index(after: closeParen)
                            continue
                        }
                    }
                    // 3. Multi-digit or signed subscript: e.g. _10, _-1
                    else if text[nextIdx] == "-" || text[nextIdx].isNumber {
                        var endScan = nextIdx
                        if text[endScan] == "-" {
                            endScan = text.index(after: endScan)
                        }
                        while endScan < text.endIndex && text[endScan].isNumber {
                            endScan = text.index(after: endScan)
                        }
                        if endScan > nextIdx {
                            let token = text[nextIdx..<endScan]
                            for c in token {
                                result.append(subMap[c] ?? c)
                            }
                            i = endScan
                            continue
                        }
                    }
                    // 4. Single character or symbol
                    else {
                        let subChar = text[nextIdx]
                        result.append(subMap[subChar] ?? subChar)
                        i = text.index(after: nextIdx)
                        continue
                    }
                }
            }
            
            result.append(ch)
            i = text.index(after: i)
        }
        
        return result
    }
}

// MARK: - Dedicated LaTeX Math Card View

public struct LaTeXMathCardView: View {
    public let formula: String
    @State private var showCopiedBadge: Bool = false
    
    public init(formula: String) {
        self.formula = formula
    }
    
    public var body: some View {
        let derivation = LaTeXMathEngine.parseDerivation(formula)
        
        VStack(alignment: .leading, spacing: 10) {
            // Header bar
            HStack(spacing: 8) {
                Image(systemName: derivation.isMultiStep ? "arrow.triangle.branch" : "function")
                    .foregroundColor(.purple)
                    .font(.system(size: 12, weight: .bold))
                
                Text(derivation.isMultiStep ? "STEP-BY-STEP DERIVATION" : "LATEX EQUATION")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)
                
                Spacer()
                
                if showCopiedBadge {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                        Text("Copied!")
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())
                    .transition(.opacity.combined(with: .scale))
                }
                
                Button(action: copyLatex) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("LaTeX")
                    }
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.14))
                    .clipShape(Capsule())
                }
            }
            
            // Derivation / Equation Body
            if derivation.isMultiStep {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(derivation.steps) { step in
                        LaTeXStepRowView(step: step)
                    }
                }
                .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Spacer(minLength: 8)
                        if let firstStep = derivation.steps.first {
                            LaTeXTokensRowView(tokens: firstStep.tokens)
                        } else {
                            Text(formula)
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                                .foregroundColor(.white)
                        }
                        Spacer(minLength: 8)
                    }
                    .frame(minWidth: 260)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.08, green: 0.09, blue: 0.14).opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.55), Color.cyan.opacity(0.35), Color.blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
        )
        .padding(.vertical, 3)
    }
    
    private func copyLatex() {
        #if canImport(UIKit)
        UIPasteboard.general.string = formula
        #endif
        SoundAndHapticManager.shared.triggerHaptic(.selection)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopiedBadge = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { showCopiedBadge = false }
        }
    }
}

// MARK: - LaTeX Token & Step Component Views

public struct LaTeXStepRowView: View {
    public let step: LaTeXStep
    
    public init(step: LaTeXStep) {
        self.step = step
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(step.label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(step.isBoxed ? .cyan : .white.opacity(0.6))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(step.isBoxed ? Color.cyan.opacity(0.18) : Color.white.opacity(0.06))
                .clipShape(Capsule())
                .frame(width: 54, alignment: .leading)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LaTeXTokensRowView(tokens: step.tokens)
            }
        }
        .padding(8)
        .background(step.isBoxed ? Color.cyan.opacity(0.06) : Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(step.isBoxed ? Color.cyan.opacity(0.4) : Color.white.opacity(0.04), lineWidth: 1)
        )
    }
}

public struct LaTeXTokensRowView: View {
    public let tokens: [LaTeXRenderToken]
    
    public init(tokens: [LaTeXRenderToken]) {
        self.tokens = tokens
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<tokens.count, id: \.self) { idx in
                LaTeXTokenItemView(token: tokens[idx])
            }
        }
    }
}

public struct LaTeXTokenItemView: View {
    public let token: LaTeXRenderToken
    
    public init(token: LaTeXRenderToken) {
        self.token = token
    }
    
    public var body: some View {
        switch token {
        case .text(let str):
            Text(str)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundColor(Color(red: 0.95, green: 0.96, blue: 1.0))
            
        case .fraction(let num, let den):
            VStack(spacing: 3) {
                HStack(spacing: 2) {
                    ForEach(0..<num.count, id: \.self) { idx in
                        LaTeXTokenItemView(token: num[idx])
                    }
                }
                .font(.system(size: 13, weight: .medium, design: .serif))
                .padding(.horizontal, 4)
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.85), .purple.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1.5)
                
                HStack(spacing: 2) {
                    ForEach(0..<den.count, id: \.self) { idx in
                        LaTeXTokenItemView(token: den[idx])
                    }
                }
                .font(.system(size: 13, weight: .medium, design: .serif))
                .padding(.horizontal, 4)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 3)
            
        case .radical(let degree, let radicand):
            HStack(alignment: .center, spacing: 1) {
                if let degree = degree {
                    Text(degree)
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .foregroundColor(.cyan)
                        .offset(y: -7)
                }
                
                Text("√")
                    .font(.system(size: 21, weight: .light, design: .serif))
                    .foregroundColor(.cyan)
                
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle()
                        .fill(Color.cyan.opacity(0.85))
                        .frame(height: 1.2)
                    
                    HStack(spacing: 2) {
                        ForEach(0..<radicand.count, id: \.self) { idx in
                            LaTeXTokenItemView(token: radicand[idx])
                        }
                    }
                    .padding(.horizontal, 3)
                    .padding(.top, 2)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            
        case .boxed(let content):
            HStack(spacing: 3) {
                ForEach(0..<content.count, id: \.self) { idx in
                    LaTeXTokenItemView(token: content[idx])
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.cyan.opacity(0.12)))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1.5
                    )
            )
            
        case .superscript(let base, let exp):
            HStack(alignment: .top, spacing: 1) {
                Text(base).font(.system(size: 16, weight: .medium, design: .serif))
                Text(exp).font(.system(size: 11, weight: .bold, design: .serif)).foregroundColor(.cyan).offset(y: -6)
            }
            
        case .subscriptToken(let base, let sub):
            HStack(alignment: .bottom, spacing: 1) {
                Text(base).font(.system(size: 16, weight: .medium, design: .serif))
                Text(sub).font(.system(size: 11, weight: .semibold, design: .serif)).foregroundColor(.white.opacity(0.8)).offset(y: 4)
            }
        }
    }
}

// MARK: - Syntax-Highlighted Code Block View

public struct SyntaxHighlightedCodeView: View {
    public let language: String
    public let code: String
    
    @State private var isCopied: Bool = false
    
    public init(language: String, code: String) {
        self.language = language
        self.code = code
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar
            HStack(spacing: 8) {
                // macOS window dots
                HStack(spacing: 5) {
                    Circle().fill(Color.red.opacity(0.75)).frame(width: 8, height: 8)
                    Circle().fill(Color.yellow.opacity(0.75)).frame(width: 8, height: 8)
                    Circle().fill(Color.green.opacity(0.75)).frame(width: 8, height: 8)
                }
                
                // Language badge
                Text(language.uppercased())
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(languageColor(language))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(languageColor(language).opacity(0.15))
                    .clipShape(Capsule())
                
                Spacer()
                
                // Copy Button
                Button(action: copyCode) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Copied" : "Copy")
                    }
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(isCopied ? .green : .white.opacity(0.75))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(isCopied ? Color.green.opacity(0.15) : Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.45))
            
            Divider().background(Color.white.opacity(0.08))
            
            // Code lines with optional line numbering and syntax highlighting
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    let lines = code.components(separatedBy: "\n")
                    
                    // Line numbers gutter
                    VStack(alignment: .trailing, spacing: 3) {
                        ForEach(1...max(1, lines.count), id: \.self) { lineNum in
                            Text("\(lineNum)")
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.25))
                        }
                    }
                    .padding(.leading, 10)
                    .padding(.vertical, 10)
                    
                    // Code content with highlight colors
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(highlightedLine(line))
                                .font(.system(size: 12, design: .monospaced))
                        }
                    }
                    .padding(.trailing, 14)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(Color(red: 0.05, green: 0.06, blue: 0.09).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.9)
        )
        .padding(.vertical, 3)
    }
    
    private func languageColor(_ lang: String) -> Color {
        switch lang.lowercased() {
        case "swift": return Color(red: 1.0, green: 0.55, blue: 0.2)
        case "python", "py": return Color(red: 0.35, green: 0.72, blue: 1.0)
        case "latex", "tex": return Color(red: 0.8, green: 0.45, blue: 1.0)
        case "javascript", "js", "ts", "typescript": return Color(red: 0.95, green: 0.82, blue: 0.25)
        case "rust": return Color(red: 0.9, green: 0.42, blue: 0.15)
        case "json": return Color(red: 0.25, green: 0.85, blue: 0.9)
        case "bash", "sh", "zsh": return Color(red: 0.3, green: 0.85, blue: 0.45)
        default: return .cyan
        }
    }
    
    private static let stringRegex = try? NSRegularExpression(pattern: "\"[^\"]*\"|'[^']*'")
    private static let keywordRegex = try? NSRegularExpression(pattern: "\\b(func|let|var|class|struct|enum|import|return|if|else|guard|switch|case|for|in|while|def|async|await|self|nil|None|null|true|false|const|mut|type|val|override|private|public|open|static)\\b")
    private static let numberRegex = try? NSRegularExpression(pattern: "\\b\\d+(\\.\\d+)?\\b")
    
    private func highlightedLine(_ line: String) -> AttributedString {
        var attributed = AttributedString(line.isEmpty ? " " : line)
        attributed.foregroundColor = Color(red: 0.88, green: 0.92, blue: 0.98)
        
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
            attributed.foregroundColor = Color(red: 0.48, green: 0.55, blue: 0.52)
            return attributed
        }
        
        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)
        
        // Match numbers
        if let numberRegex = Self.numberRegex {
            let matches = numberRegex.matches(in: line, range: fullRange)
            for m in matches {
                if let r = Range(m.range, in: line), let ar = Range(r, in: attributed) {
                    attributed[ar].foregroundColor = Color(red: 1.0, green: 0.72, blue: 0.32)
                }
            }
        }
        
        // Match string literals
        if let stringRegex = Self.stringRegex {
            let matches = stringRegex.matches(in: line, range: fullRange)
            for m in matches {
                if let r = Range(m.range, in: line), let ar = Range(r, in: attributed) {
                    attributed[ar].foregroundColor = Color(red: 0.45, green: 0.88, blue: 0.55)
                }
            }
        }
        
        // Match keywords
        if let keywordRegex = Self.keywordRegex {
            let matches = keywordRegex.matches(in: line, range: fullRange)
            for m in matches {
                if let r = Range(m.range, in: line), let ar = Range(r, in: attributed) {
                    attributed[ar].foregroundColor = Color(red: 0.92, green: 0.45, blue: 0.95)
                }
            }
        }
        
        return attributed
    }
    
    private func copyCode() {
        #if canImport(UIKit)
        UIPasteboard.general.string = code
        #endif
        SoundAndHapticManager.shared.triggerHaptic(.selection)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { isCopied = false }
        }
    }
}

// MARK: - Main LiquidMarkdownView

public struct LiquidMarkdownView: View {
    public let text: String
    public let isAnimated: Bool
    public var onTaskToggle: ((Int) -> Void)?
    
    public init(text: String, isAnimated: Bool = false, onTaskToggle: ((Int) -> Void)? = nil) {
        self.text = text
        self.isAnimated = isAnimated
        self.onTaskToggle = onTaskToggle
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
            SyntaxHighlightedCodeView(language: language, code: code)
        case .mathDisplay(let formula):
            LaTeXMathCardView(formula: formula)
        case .callout(let type, let title, let content):
            calloutView(type: type, title: title, content: content)
        case .taskItem(let item):
            taskItemView(item: item)
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
                .font(.system(size: level == 1 ? 19 : (level == 2 ? 16.5 : (level == 3 ? 14.5 : 13)), weight: .bold, design: .rounded))
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
    
    @ViewBuilder
    private func inlineMathParagraphView(text: String) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("**Solution:**") || trimmed.hasPrefix("**Result:**") || trimmed.hasPrefix("**Final Answer:**") || trimmed.hasPrefix("Result:") {
            styledMathSolutionCard(text: trimmed)
        } else {
            let formatted = formatInlineMath(text)
            Text(LocalizedStringKey(formatted))
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.92))
                .lineSpacing(5)
        }
    }
    
    private func styledMathSolutionCard(text: String) -> some View {
        let formatted = formatInlineMath(text)
        let isResult = text.contains("Result:") || text.contains("Final Answer:")
        return HStack(spacing: 10) {
            Image(systemName: isResult ? "checkmark.circle.fill" : "sparkles")
                .foregroundColor(isResult ? .green : .cyan)
                .font(.system(size: 15, weight: .bold))
            
            Text(LocalizedStringKey(formatted))
                .font(.system(size: 14, weight: isResult ? .semibold : .regular))
                .foregroundColor(.white)
                .lineSpacing(4)
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.08, green: 0.10, blue: 0.16).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: isResult
                                    ? [Color.green.opacity(0.6), Color.cyan.opacity(0.4)]
                                    : [Color.cyan.opacity(0.5), Color.purple.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
        )
        .padding(.vertical, 2)
    }
    
    private func taskItemView(item: TaskItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: {
                onTaskToggle?(item.lineIndex)
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(item.isChecked ? Color.cyan : Color.white.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    
                    if item.isChecked {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 18, height: 18)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, -2)
            
            Text(LocalizedStringKey(formatInlineMath(item.text)))
                .font(.system(size: 14))
                .foregroundColor(item.isChecked ? Color.white.opacity(0.45) : Color.white.opacity(0.92))
                .strikethrough(item.isChecked, color: Color.cyan.opacity(0.7))
                .lineSpacing(4)
                .padding(.top, 4)
        }
        .padding(.vertical, 1)
    }
    
    private func calloutView(type: CalloutType, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: type.iconName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(type.accentColor)
                
                Text(title.isEmpty ? type.defaultTitle : title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(type.accentColor)
            }
            
            if !content.isEmpty {
                Text(LocalizedStringKey(formatInlineMath(content)))
                    .font(.system(size: 13.5))
                    .foregroundColor(Color.white.opacity(0.92))
                    .lineSpacing(4)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .padding(.leading, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(type.accentColor.opacity(0.08))
        )
        .overlay(
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(type.accentColor)
                    .frame(width: 3.5)
                    .padding(.vertical, 6)
                    .padding(.leading, 5)
                Spacer()
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(type.accentColor.opacity(0.25), lineWidth: 1)
        )
        .padding(.vertical, 3)
    }
    
    private func quoteView(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.cyan)
                .frame(width: 3)
            
            Text(LocalizedStringKey(formatInlineMath(text)))
                .font(.system(size: 13, weight: .regular))
                .italic()
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(4)
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
            
            Text(LocalizedStringKey(formatInlineMath(text)))
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(4)
        }
        .padding(.vertical, 1)
    }
    
    private func tableView(headers: [String], rows: [[String]]) -> some View {
        let colCount = headers.count
        var columnWidths: [CGFloat] = []
        for c in 0..<colCount {
            var maxLen = headers[c].count
            for row in rows {
                if c < row.count {
                    maxLen = max(maxLen, row[c].count)
                }
            }
            let estWidth = max(80.0, min(260.0, CGFloat(maxLen) * 9.5 + 28.0))
            columnWidths.append(estWidth)
        }
        
        return ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { idx, h in
                        Text(h)
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .frame(width: columnWidths[idx], alignment: .leading)
                        
                        if idx < headers.count - 1 {
                            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 18)
                        }
                    }
                }
                .background(Color.white.opacity(0.07))
                
                // Header Divider
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.6), Color.purple.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1.5)
                
                // Data rows with alternating row glass tints and uniform column widths
                ForEach(Array(rows.enumerated()), id: \.offset) { rIdx, row in
                    HStack(spacing: 0) {
                        ForEach(0..<colCount, id: \.self) { cIdx in
                            let cell = cIdx < row.count ? row[cIdx] : ""
                            Text(LocalizedStringKey(formatInlineMath(cell)))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.88))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .frame(width: columnWidths[cIdx], alignment: .leading)
                            
                            if cIdx < colCount - 1 {
                                Rectangle().fill(Color.white.opacity(0.04)).frame(width: 1, height: 16)
                            }
                        }
                    }
                    .background(rIdx % 2 == 0 ? Color.white.opacity(0.02) : Color.white.opacity(0.05))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.9)
            )
        }
        .padding(.vertical, 4)
    }
    
    private func formatInlineMath(_ text: String) -> String {
        var str = text
        
        // 1. Normalize LaTeX delimiters \( ... \) and \[ ... \]
        str = str.replacingOccurrences(of: "\\[", with: "$$")
        str = str.replacingOccurrences(of: "\\]", with: "$$")
        str = str.replacingOccurrences(of: "\\(", with: "$")
        str = str.replacingOccurrences(of: "\\)", with: "$")
        
        // 2. Handle double dollar display math $$ ... $$ first
        while let startRange = str.range(of: "$$") {
            let afterStart = startRange.upperBound
            if let endRange = str[afterStart...].range(of: "$$") {
                let mathContent = String(str[afterStart..<endRange.lowerBound])
                let formatted = LaTeXMathEngine.formatInlineMathExpression(mathContent)
                str.replaceSubrange(startRange.lowerBound..<endRange.upperBound, with: formatted)
            } else {
                break
            }
        }
        
        // 3. Handle single dollar inline math $ ... $
        var result = ""
        var inMath = false
        var currentToken = ""
        var i = str.startIndex
        
        while i < str.endIndex {
            let ch = str[i]
            if ch == "$" {
                if inMath {
                    result.append(LaTeXMathEngine.formatInlineMathExpression(currentToken))
                    currentToken = ""
                    inMath = false
                } else {
                    inMath = true
                }
            } else {
                if inMath {
                    currentToken.append(ch)
                } else {
                    result.append(ch)
                }
            }
            i = str.index(after: i)
        }
        if inMath {
            result.append(LaTeXMathEngine.formatInlineMathExpression(currentToken))
        }
        
        // 4. Typeset any remaining un-delimited math expressions (e.g. raw \frac, \sqrt, \alpha)
        result = LaTeXMathEngine.convertInlineFractions(result)
        result = LaTeXMathEngine.convertInlineRadicals(result)
        result = LaTeXMathEngine.replaceSymbols(result)
        result = LaTeXMathEngine.convertSubAndSuperscripts(result)
        result = LaTeXMathEngine.sanitizeMathSigns(result)
        
        return result
    }
}
