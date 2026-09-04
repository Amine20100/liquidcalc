//
//  LiquidAIAgentView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Interactive Autonomous AI Agent Workbench & ReAct Execution Inspector
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct LiquidAIAgentView: View {
    @Bindable var agent: LiquidAIAgent
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputPrompt: String = ""
    @State private var showScratchpadSheet: Bool = false
    
    public init(agent: LiquidAIAgent = LiquidAIAgent.shared) {
        self.agent = agent
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.09)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    agentWorkbenchHeader
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            presetPromptsSection
                            inputCard
                            
                            if !agent.steps.isEmpty {
                                executionTimelineCard
                            }
                            
                            if let result = agent.finalMarkdownResult {
                                finalResultCard(markdown: result)
                            }
                        }
                        .padding(14)
                    }
                }
            }
            .navigationTitle("AI Agent Workbench")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.cyan)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showScratchpadSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.pencil")
                            Text("Scratchpad")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.cyan)
                    }
                }
            }
            .sheet(isPresented: $showScratchpadSheet) {
                MarkdownNotebookView()
            }
        }
    }
    
    // MARK: - 1. Workbench Header
    
    private var agentWorkbenchHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                        .font(.system(size: 14, weight: .bold))
                    Text("STUDY AGENT")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                Text("Reasoning + Action Engine • Direct Tool Execution")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            
            HStack(spacing: 5) {
                Circle()
                    .fill(agent.isExecuting ? Color.yellow : Color.green)
                    .frame(width: 8, height: 8)
                Text(agent.isExecuting ? "WORKING" : "READY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(agent.isExecuting ? .yellow : .green)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.4))
    }
    
    // MARK: - 2. Quick Preset Prompts
    
    private var presetPromptsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STARTER MISSIONS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    presetChip("Integrate x^3 from 0 to 4 & convert 25 mi to km")
                    presetChip("Solve quadratic equation 3x^2 - 6x + 2 = 0")
                    presetChip("Generate ZSign CLI command for cloned app with flex.dylib")
                }
            }
        }
    }
    
    private func presetChip(_ title: String) -> some View {
        Button(action: {
            inputPrompt = title
            Task {
                await agent.execute(query: title)
            }
        }) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.8))
        }
        .disabled(agent.isExecuting)
    }
    
    // MARK: - 3. Input Card
    
    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MISSION PROMPT")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
            HStack {
                TextField("Ask anything (e.g. calculus, units, equations, zsign)...", text: $inputPrompt)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .submitLabel(.send)
                    .onSubmit {
                        guard !inputPrompt.isEmpty else { return }
                        Task {
                            await agent.execute(query: inputPrompt)
                        }
                    }
                
                if agent.isExecuting {
                    ProgressView()
                        .tint(.cyan)
                        .scaleEffect(0.8)
                } else {
                    Button(action: {
                        guard !inputPrompt.isEmpty else { return }
                        Task {
                            await agent.execute(query: inputPrompt)
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(inputPrompt.isEmpty ? .gray : .cyan)
                    }
                    .disabled(inputPrompt.isEmpty)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        )
    }
    
    // MARK: - 4. Execution Timeline Card
    
    private var executionTimelineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .foregroundColor(.purple)
                Text("TOOL ACTIVITY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)
                Spacer()
                Text("\(agent.steps.count) STEPS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            VStack(spacing: 8) {
                ForEach(agent.steps) { step in
                    stepRow(step)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        )
    }
    
    private func stepRow(_ step: AgentStep) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(stepColor(step.type).opacity(0.2))
                    .frame(width: 24, height: 24)
                
                Image(systemName: stepIcon(step.type))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(stepColor(step.type))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(step.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let tool = step.toolName {
                        Text(tool)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    Text(step.status.rawValue)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(step.status == .success ? .green : (step.status == .running ? .yellow : .white.opacity(0.4)))
                }
                
                Text(step.detail)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func stepIcon(_ type: AgentStepType) -> String {
        switch type {
        case .thought: return "brain.head.profile"
        case .toolCall: return "wrench.and.screwdriver.fill"
        case .observation: return "eye.fill"
        case .finalAnswer: return "checkmark.seal.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    private func stepColor(_ type: AgentStepType) -> Color {
        switch type {
        case .thought: return .yellow
        case .toolCall: return .cyan
        case .observation: return .blue
        case .finalAnswer: return .green
        case .error: return .red
        }
    }
    
    // MARK: - 5. Final Result Card
    
    private func finalResultCard(markdown: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AGENT SOLUTION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)
                
                Spacer()
                
                Button(action: {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = markdown
                    #endif
                    SoundAndHapticManager.shared.triggerHaptic(.success)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Solution")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.12))
                    .clipShape(Capsule())
                }

                Button(action: {
                    WorkspaceRepository.shared.saveContext(.ai(markdown: markdown))
                    SoundAndHapticManager.shared.triggerHaptic(.success)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.pencil")
                        Text("Save to Notes")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            
            LiquidMarkdownView(text: markdown)
                .padding(10)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
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
    }
}
