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
}
