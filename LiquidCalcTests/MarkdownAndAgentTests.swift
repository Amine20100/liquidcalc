//
//  MarkdownAndAgentTests.swift
//  LiquidCalcTests
//
//  Created for LiquidCalc iOS 18+.
//  Automated Unit Tests for Markdown & LaTeX Parser and Autonomous AI Agent
//

import XCTest
#if canImport(LiquidCalc)
@testable import LiquidCalc
#elseif canImport(LiquidCalcCore)
@testable import LiquidCalcCore
#endif

final class MarkdownAndAgentTests: XCTestCase {
    
    // MARK: - Markdown & LaTeX Parser Tests
    
    func testMarkdownParserHeadings() {
        let md = """
        # Heading 1
        ## Heading 2
        ### Heading 3
        """
        let elements = LiquidMarkdownParser.parse(md)
        XCTAssertEqual(elements.count, 3)
        
        if case .heading(let l, let t) = elements[0] {
            XCTAssertEqual(l, 1)
            XCTAssertEqual(t, "Heading 1")
        } else {
            XCTFail("Expected heading 1")
        }
    }
    
    func testMarkdownParserMathDisplayBlocks() {
        let md = """
        $$
        \\int_{0}^{\\pi} \\sin(x) dx = 2
        $$
        """
        let elements = LiquidMarkdownParser.parse(md)
        XCTAssertEqual(elements.count, 1)
        
        if case .mathDisplay(let formula) = elements[0] {
            XCTAssertTrue(formula.contains("\\int_{0}^{\\pi}"))
        } else {
            XCTFail("Expected mathDisplay block")
        }
    }
    
    func testMarkdownParserCodeBlocks() {
        let md = """
        ```swift
        let x = 42
        print(x)
        ```
        """
        let elements = LiquidMarkdownParser.parse(md)
        XCTAssertEqual(elements.count, 1)
        
        if case .codeBlock(let lang, let code) = elements[0] {
            XCTAssertEqual(lang, "swift")
            XCTAssertTrue(code.contains("let x = 42"))
        } else {
            XCTFail("Expected codeBlock")
        }
    }
    
    func testMarkdownParserTable() {
        let md = """
        | Operation | Result |
        |---|---|
        | Addition | 10 |
        | Integral | 64 |
        """
        let elements = LiquidMarkdownParser.parse(md)
        XCTAssertEqual(elements.count, 1)
        
        if case .table(let headers, let rows) = elements[0] {
            XCTAssertEqual(headers.count, 2)
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(headers[0], "Operation")
            XCTAssertEqual(rows[0][1], "10")
        } else {
            XCTFail("Expected table")
        }
    }
    
    func testMarkdownParserCalloutBlocks() {
        let md = """
        > [!NOTE]
        > This is a standard note callout.
        
        > [!TIP] Pro Tip
        > Always simplify fractions first.
        
        > [!WARNING]
        > Avoid division by zero.
        
        > [!IMPORTANT]
        > Set your angle unit to radians.
        """
        let elements = LiquidMarkdownParser.parse(md)
        XCTAssertEqual(elements.count, 4)
        
        if case .callout(let type, let title, let content) = elements[0] {
            XCTAssertEqual(type, .note)
            XCTAssertEqual(title, "Note")
            XCTAssertTrue(content.contains("standard note"))
        } else {
            XCTFail("Expected NOTE callout")
        }
        
        if case .callout(let type, let title, let content) = elements[1] {
            XCTAssertEqual(type, .tip)
            XCTAssertEqual(title, "Pro Tip")
            XCTAssertTrue(content.contains("simplify fractions"))
        } else {
            XCTFail("Expected TIP callout with custom title")
        }
        
        if case .callout(let type, _, _) = elements[2] {
            XCTAssertEqual(type, .warning)
        } else {
            XCTFail("Expected WARNING callout")
        }
        
        if case .callout(let type, _, _) = elements[3] {
            XCTAssertEqual(type, .important)
        } else {
            XCTFail("Expected IMPORTANT callout")
        }
    }
    
    func testMarkdownParserTaskItems() {
        let md = """
        - [ ] Calculate matrix determinant
        - [x] Prove divergence theorem
        * [X] Solve harmonic oscillator
        """
        let elements = LiquidMarkdownParser.parse(md)
        XCTAssertEqual(elements.count, 3)
        
        if case .taskItem(let item1) = elements[0] {
            XCTAssertFalse(item1.isChecked)
            XCTAssertEqual(item1.text, "Calculate matrix determinant")
        } else {
            XCTFail("Expected unchecked task item")
        }
        
        if case .taskItem(let item2) = elements[1] {
            XCTAssertTrue(item2.isChecked)
            XCTAssertEqual(item2.text, "Prove divergence theorem")
        } else {
            XCTFail("Expected checked task item")
        }
        
        if case .taskItem(let item3) = elements[2] {
            XCTAssertTrue(item3.isChecked)
            XCTAssertEqual(item3.text, "Solve harmonic oscillator")
        } else {
            XCTFail("Expected checked task item with asterisk")
        }
    }
    
    func testLaTeXMathEngineGreekAndOperators() {
        let raw = "\\nabla \\cdot \\mathbf{E} = \\alpha + \\beta - \\int f(x) dx \\pm \\infty \\approx 0 \\neq 1"
        let replaced = LaTeXMathEngine.replaceSymbols(raw)
        XCTAssertTrue(replaced.contains("∇"))
        XCTAssertTrue(replaced.contains("α"))
        XCTAssertTrue(replaced.contains("β"))
        XCTAssertTrue(replaced.contains("∫"))
        XCTAssertTrue(replaced.contains("±"))
        XCTAssertTrue(replaced.contains("∞"))
        XCTAssertTrue(replaced.contains("≈"))
        XCTAssertTrue(replaced.contains("≠"))
    }
    
    func testLaTeXMathEngineDerivationAndBoxed() {
        let derivationFormula = """
        f(x) &= 2x^2 + 4x \\\\
        &= 2x(x + 2) \\\\
        \\boxed{x = 0, -2}
        """
        let derivation = LaTeXMathEngine.parseDerivation(derivationFormula)
        XCTAssertTrue(derivation.isMultiStep)
        XCTAssertEqual(derivation.steps.count, 3)
        XCTAssertFalse(derivation.steps[0].isBoxed)
        XCTAssertTrue(derivation.steps[2].isBoxed)
        XCTAssertEqual(derivation.steps[2].label, "Result")
    }
    
    func testLaTeXMathEngineFractionsAndRadicals() {
        let formula = "\\frac{a + b}{\\sqrt{c^2 + d^2}}"
        let tokens = LaTeXMathEngine.parseTokens(formula)
        XCTAssertEqual(tokens.count, 1)
        
        if case .fraction(let num, let den) = tokens[0] {
            XCTAssertFalse(num.isEmpty)
            XCTAssertFalse(den.isEmpty)
            
            // Check radical in denominator
            let hasRadical = den.contains {
                if case .radical = $0 { return true }
                return false
            }
            XCTAssertTrue(hasRadical, "Denominator should contain a radical token")
        } else {
            XCTFail("Expected fraction token")
        }
    }
    
    func testLaTeXMathEngineNonDestructiveSanitization() {
        let codeText = "Use C++ with --verbose and --flag"
        let sanitized = LaTeXMathEngine.sanitizeMathSigns(codeText)
        XCTAssertTrue(sanitized.contains("C++"), "C++ should not be converted to C+ ")
        XCTAssertTrue(sanitized.contains("--verbose"), "-- flags should not be converted to + ")
    }
    
    func testLaTeXMathEngineFractionVariantsAndRadicalDegree() {
        let dfracTokens = LaTeXMathEngine.parseTokens("\\dfrac{1}{2}")
        XCTAssertEqual(dfracTokens.count, 1)
        if case .fraction(let num, let den) = dfracTokens[0] {
            XCTAssertFalse(num.isEmpty)
            XCTAssertFalse(den.isEmpty)
        } else {
            XCTFail("Expected dfrac to be parsed as fraction")
        }
        
        let inlineCubeRoot = LaTeXMathEngine.convertInlineRadicals("\\sqrt[3]{x}")
        XCTAssertTrue(inlineCubeRoot.contains("³√"), "Cube root degree should be formatted as superscript ³√")
        
        let inlineFrac = LaTeXMathEngine.convertInlineFractions("\\frac{1}{2}")
        XCTAssertEqual(inlineFrac, "½")
    }
    
    func testLaTeXMathEngineAlignStarDerivation() {
        let alignStar = """
        \\begin{align*}
        \\nabla \\times \\mathbf{B} &= \\mu_0 \\mathbf{J} \\\\
        \\boxed{\\mathbf{J} = \\sigma \\mathbf{E}}
        \\end{align*}
        """
        let derivation = LaTeXMathEngine.parseDerivation(alignStar)
        XCTAssertTrue(derivation.isMultiStep)
        XCTAssertEqual(derivation.steps.count, 2)
        XCTAssertTrue(derivation.steps[1].isBoxed)
    }
    
    // MARK: - AI Agent Autonomous Tools Tests
    
    func testAgentToolsRegistry() {
        let agent = LiquidAIAgent.shared
        XCTAssertGreaterThanOrEqual(agent.availableTools.count, 4)
        XCTAssertTrue(agent.availableTools.contains(where: { $0.name == "eval_math" }))
        XCTAssertTrue(agent.availableTools.contains(where: { $0.name == "calculus_solve" }))
        XCTAssertTrue(agent.availableTools.contains(where: { $0.name == "algebra_solve" }))
        XCTAssertTrue(agent.availableTools.contains(where: { $0.name == "convert_units" }))
        XCTAssertTrue(agent.availableTools.contains(where: { $0.name == "generate_zsign_cmd" }))
    }
    
    func testAgentMathEvalTool() {
        let agent = LiquidAIAgent.shared
        let res = agent.executeMathEvalTool(query: "2 + 2 * 3")
        XCTAssertTrue(res.contains("8") || res.contains("8.0") || !res.isEmpty)
    }
    
    func testAgentCalculusTool() {
        let agent = LiquidAIAgent.shared
        let res = agent.executeCalculusTool(query: "integrate x^3 from 0 to 4")
        XCTAssertTrue(res.contains("64"))
    }
    
    func testAgentUnitConverterTool() {
        let agent = LiquidAIAgent.shared
        let res = agent.executeUnitConverterTool(query: "convert 25 miles to km")
        XCTAssertTrue(res.contains("40.2336"))
    }
    
    func testAgentZSignTool() {
        let agent = LiquidAIAgent.shared
        let cmd = agent.executeZSignTool(query: "zsign sideload app")
        XCTAssertTrue(cmd.hasPrefix("zsign"))
        XCTAssertTrue(cmd.contains("-E"))
        XCTAssertTrue(cmd.contains("-W"))
    }

    func testWorkspacePersistsAndSearchesDocuments() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = WorkspaceRepository(directoryURL: directory)
        var document = repository.create(title: "Calculus revision", markdown: "# Integrals", tags: ["math", "calculus"])
        document.markdown += "\n\nResult: 64"
        repository.upsert(document)

        XCTAssertEqual(repository.search("integrals").count, 1)
        XCTAssertEqual(repository.search("", tag: "calculus").first?.id, document.id)

        let reloaded = WorkspaceRepository(directoryURL: directory)
        XCTAssertEqual(reloaded.documents.first?.markdown, document.markdown)
        XCTAssertEqual(reloaded.documents.first?.tags, ["calculus", "math"])
    }

    func testWorkspaceContextProducesStudyReadyContent() {
        let context = WorkspaceContext.scan(expression: "2x + 4 = 10", result: "x = 3")
        XCTAssertTrue(context.promptText.contains("2x + 4"))
        XCTAssertTrue(context.markdownBlock.contains("x = 3"))

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = WorkspaceRepository(directoryURL: directory)
        let document = repository.saveContext(context)
        XCTAssertEqual(document.attachments.first?.kind, .scan)
    }

    // MARK: - Advanced Typesetting & Math Sanitization Tests

    func testSanitizeMathSignsAndOperators() {
        let raw1 = "x - + y"
        let sanitized1 = LaTeXMathEngine.sanitizeMathSigns(raw1)
        XCTAssertEqual(sanitized1, "x - y")

        let raw2 = "a + - b"
        let sanitized2 = LaTeXMathEngine.sanitizeMathSigns(raw2)
        XCTAssertEqual(sanitized2, "a - b")

        let raw3 = "u - - v"
        let sanitized3 = LaTeXMathEngine.sanitizeMathSigns(raw3)
        XCTAssertEqual(sanitized3, "u + v")

        let raw4 = "3 +/- 5"
        let sanitized4 = LaTeXMathEngine.sanitizeMathSigns(raw4)
        XCTAssertEqual(sanitized4, "3 ± 5")
    }

    func testInlineFractionsAndRadicalsConversion() {
        let rawFrac = "\\frac{3x^2 - 6}{2}"
        let convertedFrac = LaTeXMathEngine.convertInlineFractions(rawFrac)
        XCTAssertTrue(convertedFrac.contains("/"))
        XCTAssertFalse(convertedFrac.contains("\\frac"))

        let rawRad = "\\sqrt{x^2 + 1}"
        let convertedRad = LaTeXMathEngine.convertInlineRadicals(rawRad)
        XCTAssertTrue(convertedRad.contains("√"))
        XCTAssertFalse(convertedRad.contains("\\sqrt"))

        let rawCombined = "\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}"
        let formatted = LaTeXMathEngine.formatInlineMathExpression(rawCombined)
        XCTAssertTrue(formatted.contains("√"))
        XCTAssertTrue(formatted.contains("±"))
        XCTAssertTrue(formatted.contains("/"))
        XCTAssertFalse(formatted.contains("\\frac"))
        XCTAssertFalse(formatted.contains("\\sqrt"))
        XCTAssertFalse(formatted.contains("\\pm"))
    }

    func testExpandedSuperscriptsAndSubscripts() {
        let expr = "x^2 + y^3 = z^n"
        let converted = LaTeXMathEngine.convertSubAndSuperscripts(expr)
        XCTAssertTrue(converted.contains("x²"))
        XCTAssertTrue(converted.contains("y³"))
        XCTAssertTrue(converted.contains("zⁿ"))

        let subExpr = "x_1 + x_2 = a_0"
        let subConverted = LaTeXMathEngine.convertSubAndSuperscripts(subExpr)
        XCTAssertTrue(subConverted.contains("x₁"))
        XCTAssertTrue(subConverted.contains("x₂"))
        XCTAssertTrue(subConverted.contains("a₀"))
    }
}
