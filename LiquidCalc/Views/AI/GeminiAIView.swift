//
//  GeminiAIView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Gemini 2.5 Flash Multimodal Math & Science Assistant
//

import SwiftUI
import PhotosUI

public struct GeminiAIView: View {
    @Bindable var calculatorViewModel: CalculatorViewModel
    @State private var geminiService = GeminiService.shared
    
    @State private var promptText: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var aiResponse: String = ""
    @State private var mathResult: GeminiMathResponse? = nil
    @State private var isProcessing: Bool = false
    @State private var showCopiedAlert: Bool = false
    
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
                    Text("Gemini 2.5 Flash Math AI")
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
                Text("Online")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            
            // Conversation / Solution Display Area
            ScrollView {
                VStack(spacing: 14) {
                    if let result = mathResult {
                        // Formatted Math Solution Card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("SOLVED EQUATION")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                                Spacer()
                                Button(action: {
                                    UIPasteboard.general.string = result.result
                                    SoundAndHapticManager.shared.triggerHaptic(.light)
                                    withAnimation { showCopiedAlert = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation { showCopiedAlert = false }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc")
                                        Text(showCopiedAlert ? "Copied!" : "Copy")
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.cyan)
                                }
                            }
                            
                            Text(result.expression)
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))
                            
                            Text(result.result)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.cyan)
                            
                            if !result.steps.isEmpty {
                                Divider().background(Color.white.opacity(0.15))
                                Text("Step-by-Step Breakdown:")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                ForEach(Array(result.steps.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1).")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundColor(.cyan)
                                        Text(step)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                            }
                            
                            if !result.explanation.isEmpty {
                                Text(result.explanation)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.top, 4)
                            }
                            
                            Button(action: {
                                calculatorViewModel.expression = result.result
                                calculatorViewModel.currentMode = .standard
                                SoundAndHapticManager.shared.triggerHaptic(.success)
                            }) {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                    Text("Send to Standard Calculator")
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.cyan))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 6)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(white: 0.12, opacity: 0.7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(LinearGradient(colors: [.cyan.opacity(0.6), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                                )
                        )
                    } else if !aiResponse.isEmpty {
                        // General Assistant Response
                        VStack(alignment: .leading, spacing: 8) {
                            Text("GEMINI EXPLANATION")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.purple)
                            
                            Text(aiResponse)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.95))
                                .lineSpacing(4)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(white: 0.12, opacity: 0.7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                                )
                        )
                    } else {
                        // Empty State / Starter Suggestions
                        VStack(spacing: 12) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 40))
                                .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .padding(.top, 20)
                            
                            Text("Ask Gemini 2.5 Flash Anything")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Snap a photo of a math problem or type any equation, word problem, calculus proof, or physics question.")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            // Quick Suggestion Chips
                            VStack(spacing: 8) {
                                suggestionChip("Solve derivative of sin(x)*e^(2x)")
                                suggestionChip("Integrate x^2 / (1 + x^3) dx")
                                suggestionChip("Find roots of 3x^2 - 12x + 9 = 0")
                                suggestionChip("Calculate moon gravitational escape velocity")
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.horizontal, 14)
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
                TextField("Ask math question or formula...", text: $promptText)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
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
                        
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(isProcessing || (promptText.isEmpty && selectedImage == nil))
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
        isProcessing = true
        SoundAndHapticManager.shared.triggerHaptic(.medium)
        
        let query = promptText
        let img = selectedImage
        promptText = ""
        
        Task {
            do {
                if img != nil {
                    let result = try await geminiService.solveMath(image: img, expressionText: query)
                    await MainActor.run {
                        self.mathResult = result
                        self.aiResponse = ""
                        self.isProcessing = false
                        self.selectedImage = nil
                        SoundAndHapticManager.shared.triggerHaptic(.success)
                        SoundAndHapticManager.shared.playSuccessSound()
                    }
                } else {
                    let response = try await geminiService.askMathTutor(prompt: query)
                    await MainActor.run {
                        self.aiResponse = response
                        self.mathResult = nil
                        self.isProcessing = false
                        SoundAndHapticManager.shared.triggerHaptic(.success)
                    }
                }
            } catch {
                await MainActor.run {
                    self.aiResponse = "Error connecting to Gemini AI: \(error.localizedDescription)"
                    self.isProcessing = false
                    SoundAndHapticManager.shared.triggerHaptic(.error)
                }
            }
        }
    }
}
