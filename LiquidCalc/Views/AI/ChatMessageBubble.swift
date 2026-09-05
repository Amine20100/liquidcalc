import SwiftUI

#if canImport(UIKit)
import UIKit

public struct ChatMessageBubble: View {
    public let message: ChatMessage
    public let isStreaming: Bool
    
    @State private var hasAppeared: Bool = false
    @State private var cursorBlink: Bool = false
    @State private var borderGlowPhase: Bool = false
    
    public init(message: ChatMessage, isStreaming: Bool = false) {
        self.message = message
        self.isStreaming = isStreaming
    }
    
    public var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
                userBubble
            } else {
                modelBubble
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 16)
        .scaleEffect(hasAppeared ? 1.0 : 0.88, anchor: message.role == .user ? .bottomTrailing : .bottomLeading)
        .opacity(hasAppeared ? 1.0 : 0.0)
        .animation(.spring(response: 0.32, dampingFraction: 0.74), value: hasAppeared)
        .onAppear {
            hasAppeared = true
            cursorBlink = true
            borderGlowPhase = true
        }
    }
    
    @ViewBuilder
    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if let img = message.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.3), radius: 6)
            }
            if !message.text.isEmpty {
                Text(message.text)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(ChatBubbleShape(isUser: true))
                    .shadow(color: Color.blue.opacity(0.35), radius: 8, x: 0, y: 3)
            }
        }
    }
    
    @ViewBuilder
    private var modelBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                    .font(.system(size: 12))
                    .symbolEffect(.pulse, options: .repeating, value: isStreaming)
                Text("Gemini")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)
                
                if isStreaming {
                    Text("Thinking...")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.8))
                        .transition(.opacity)
                }
            }
            
            let parts = splitMessageByMermaid(message.text)
            
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                if part.isMermaid {
                    MermaidDiagramView(mermaidCode: part.content)
                        .frame(minHeight: 200)
                        .background(Color.black.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.vertical, 4)
                } else {
                    let isLast = index == parts.count - 1
                    VStack(alignment: .leading, spacing: 4) {
                        LiquidMarkdownView(text: part.content)
                        
                        if isStreaming && isLast {
                            Text("▋")
                                .foregroundColor(.purple)
                                .font(.system(size: 14, weight: .bold))
                                .opacity(cursorBlink ? 1.0 : 0.2)
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: cursorBlink)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.12, opacity: 0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: isStreaming
                                    ? [.purple, .cyan, .indigo]
                                    : [Color.purple.opacity(0.4), Color.purple.opacity(0.2)],
                                startPoint: borderGlowPhase ? .topLeading : .bottomTrailing,
                                endPoint: borderGlowPhase ? .bottomTrailing : .topLeading
                            ),
                            lineWidth: isStreaming ? 1.8 : 1.0
                        )
                        .animation(
                            isStreaming ? .linear(duration: 2.0).repeatForever(autoreverses: true) : .default,
                            value: borderGlowPhase
                        )
                )
                .shadow(color: isStreaming ? Color.purple.opacity(0.4) : Color.clear, radius: 10)
        )
    }
    
    struct MessagePart {
        let content: String
        let isMermaid: Bool
    }
    
    private func splitMessageByMermaid(_ text: String) -> [MessagePart] {
        var parts: [MessagePart] = []
        let components = text.components(separatedBy: "```mermaid")
        
        for (i, component) in components.enumerated() {
            if i == 0 {
                if !component.isEmpty {
                    parts.append(MessagePart(content: component, isMermaid: false))
                }
            } else {
                let subComponents = component.components(separatedBy: "```")
                if subComponents.count >= 1 {
                    let mermaidContent = subComponents[0]
                    parts.append(MessagePart(content: mermaidContent, isMermaid: true))
                    
                    if subComponents.count > 1 {
                        let textContent = subComponents.dropFirst().joined(separator: "```")
                        if !textContent.isEmpty {
                            parts.append(MessagePart(content: textContent, isMermaid: false))
                        }
                    }
                }
            }
        }
        
        if parts.isEmpty {
            parts.append(MessagePart(content: text, isMermaid: false))
        }
        
        return parts
    }
}

public struct ChatBubbleShape: Shape {
    public var isUser: Bool
    
    public func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [
                .topLeft, .topRight,
                isUser ? .bottomLeft : .bottomRight
            ],
            cornerRadii: CGSize(width: 18, height: 18)
        )
        return Path(path.cgPath)
    }
}
#endif
