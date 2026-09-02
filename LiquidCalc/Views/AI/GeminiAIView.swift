//
//  GeminiAIView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Gemini 2.5 Flash Multimodal Math & Science Assistant with Live Streaming & Haptics
//

import SwiftUI
import PhotosUI

public struct GeminiAIView: View {
    @Bindable var calculatorViewModel: CalculatorViewModel
    @Bindable private var geminiService = GeminiService.shared
    
    @State private var promptText: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    
    public init(calculatorViewModel: CalculatorViewModel) {
        self.calculatorViewModel = calculatorViewModel
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Top AI Status Banner
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.cyan)
                        .symbolEffect(.pulse, options: .repeating)
                    Text("Gemini 2.5 Flash AI")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .indigo, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                Spacer()
                
                if !geminiService.chatHistory.isEmpty {
                    Button(action: {
                        withAnimation {
                            geminiService.clearChat()
                        }
                    }) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(6)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(geminiService.isStreaming ? Color.cyan : Color.green)
                        .frame(width: 6, height: 6)
                        .scaleEffect(geminiService.isStreaming ? 1.4 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: geminiService.isStreaming)
                    
                    Text(geminiService.isStreaming ? "Streaming..." : "Online")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(geminiService.isStreaming ? .cyan : .green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.3))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            
            // Conversation Display Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if geminiService.chatHistory.isEmpty {
                            // Empty State / Starter Suggestions
                            VStack(spacing: 12) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 44))
                                    .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .padding(.top, 40)
                                
                                Text("Ask Gemini 2.5 Flash Anything")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Snap a photo of a math problem or ask for a diagram, calculus proof, or physics explanation.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                                
                                // Quick Suggestion Chips
                                VStack(spacing: 10) {
                                    suggestionChip("Solve derivative of sin(x)*e^(2x)")
                                    suggestionChip("Draw a flowchart of cellular respiration")
                                    suggestionChip("Calculate moon gravitational escape velocity")
                                }
                                .padding(.top, 16)
                            }
                        } else {
                            ForEach(geminiService.chatHistory) { msg in
                                ChatMessageBubble(
                                    message: msg,
                                    isStreaming: geminiService.isStreaming && msg.id == geminiService.chatHistory.last?.id
                                )
                                .id(msg.id)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
                .onChange(of: geminiService.chatHistory.last?.text) { _, _ in
                    if let lastId = geminiService.chatHistory.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
                .onChange(of: geminiService.chatHistory.count) { _, _ in
                    if let lastId = geminiService.chatHistory.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Image Attachment Preview
            if let img = selectedImage {
                HStack {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Text("Photo attached")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Button(action: {
                        selectedImage = nil
                        selectedPhotoItem = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                .padding(.horizontal, 14)
            }
            
            // Bottom Input Bar
            HStack(spacing: 8) {
                // Photo Picker Button
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.cyan)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Text Input Field
                TextField("Ask math question or formula...", text: $promptText, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                // Submit Button
                Button(action: {
                    sendQuery()
                }) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                        
                        if geminiService.isStreaming || geminiService.isAnalyzing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(geminiService.isStreaming || geminiService.isAnalyzing || (promptText.isEmpty && selectedImage == nil))
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImg = UIImage(data: data) {
                    await MainActor.run {
                        self.selectedImage = uiImg
                    }
                }
            }
        }
    }
    
    private func suggestionChip(_ text: String) -> some View {
        Button(action: {
            promptText = text
            SoundAndHapticManager.shared.triggerHaptic(.light)
            sendQuery()
        }) {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.cyan)
                    .font(.system(size: 12))
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }
    
    private func sendQuery() {
        guard !promptText.isEmpty || selectedImage != nil else { return }
        SoundAndHapticManager.shared.triggerHaptic(.medium)
        
        let query = promptText
        let img = selectedImage
        promptText = ""
        selectedImage = nil
        selectedPhotoItem = nil
        
        Task {
            do {
                try await geminiService.streamMathTutor(prompt: query, image: img) { _ in
                    // text chunks are appended inside streamMathTutor to chatHistory natively
                }
            } catch {
                await MainActor.run {
                    SoundAndHapticManager.shared.triggerHaptic(.error)
                }
            }
        }
    }
}
