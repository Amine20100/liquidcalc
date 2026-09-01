//
//  GeminiService.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Google Gemini 2.5 Flash Multimodal AI Engine with Smart SSE Streaming & Haptics
//

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct GeminiReceiptResponse: Codable, Sendable {
    public struct Item: Codable, Sendable {
        public let name: String
        public let price: Double
    }
    public let storeName: String?
    public let currency: String?
    public let items: [Item]
    public let subtotal: Double?
    public let tax: Double?
    public let total: Double?
}

public struct GeminiMathResponse: Codable, Sendable {
    public let expression: String
    public let result: String
    public let steps: [String]
    public let explanation: String
}

@Observable
public final class GeminiService: @unchecked Sendable {
    public static let shared = GeminiService()
    
    private static let defaultKeyB64 = "QVEuQWI4Uk42S1BYOUlQbDAxZVNkYjZsZjJwRW9PdmVKS1JTQm9CRnk4Q2hFdHdSOVM2WkE="
    
    public var apiKey: String
    public var selectedModel: String = "gemini-2.5-flash"
    public var isAnalyzing: Bool = false
    public var isStreaming: Bool = false
    public var lastError: String? = nil
    
    private let userDefaultsApiKey = "LiquidCalc_GeminiApiKey"
    
    public init() {
        if let customKey = UserDefaults.standard.string(forKey: userDefaultsApiKey), !customKey.isEmpty {
            self.apiKey = customKey
        } else if let keyData = Data(base64Encoded: Self.defaultKeyB64),
                  let decoded = String(data: keyData, encoding: .utf8) {
            self.apiKey = decoded
        } else {
            self.apiKey = ""
        }
    }
    
    public func updateApiKey(_ newKey: String) {
        self.apiKey = newKey
        UserDefaults.standard.set(newKey, forKey: userDefaultsApiKey)
    }
    
    // MARK: - Smart SSE Streaming Math Assistant with Haptics
    
    public func streamMathTutor(
        prompt: String,
        image: UIImage? = nil,
        onChunk: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        await MainActor.run {
            self.isStreaming = true
            self.lastError = nil
        }
        
        defer {
            Task { @MainActor in
                self.isStreaming = false
            }
        }
        
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(selectedModel):streamGenerateContent?alt=sse&key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "GeminiService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        
        var parts: [[String: Any]] = []
        let systemPrompt = "You are LiquidCalc AI, an expert and concise math & physics tutor. Solve formulas, explain steps clearly, and highlight the final answer."
        parts.append(["text": "\(systemPrompt)\n\nUser Question: \(prompt)"])
        
        if let img = image, let jpegData = img.jpegData(compressionQuality: 0.8) {
            let base64String = jpegData.base64EncodedString()
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": base64String
                ]
            ])
        }
        
        let payload: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": [
                "temperature": 0.2,
                "maxOutputTokens": 2048
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 45
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GeminiService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No response from Gemini"])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "GeminiService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini Error (HTTP \(httpResponse.statusCode))"])
        }
        
        var fullText = ""
        var tickCounter = 0
        
        for try await line in bytes.lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !jsonString.isEmpty, let data = jsonString.data(using: .utf8) else { continue }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let content = firstCandidate["content"] as? [String: Any],
                   let resParts = content["parts"] as? [[String: Any]],
                   let firstPart = resParts.first,
                   let text = firstPart["text"] as? String {
                    
                    fullText += text
                    onChunk(text)
                    
                    // Trigger rhythmic micro-haptic ticks during streaming
                    tickCounter += 1
                    if tickCounter % 3 == 0 {
                        SoundAndHapticManager.shared.playStreamingTick()
                    }
                }
            }
        }
        
        SoundAndHapticManager.shared.triggerHaptic(.success)
        return fullText
    }
    
    // MARK: - Solve Math from Image or Expression
    
    public func solveMath(image: UIImage?, expressionText: String? = nil) async throws -> GeminiMathResponse {
        await MainActor.run {
            self.isAnalyzing = true
            self.lastError = nil
        }
        
        defer {
            Task { @MainActor in
                self.isAnalyzing = false
            }
        }
        
        let prompt = """
        You are an expert mathematical problem solver.
        Solve the mathematical equation, handwritten formula, calculus problem, or geometry problem shown.
        Return ONLY a valid JSON object matching this schema:
        {
          "expression": "the clean sanitized mathematical equation",
          "result": "the precise numerical or algebraic answer",
          "steps": ["step 1 description", "step 2 description", "step 3 description"],
          "explanation": "brief concise summary of how this was calculated"
        }
        Do NOT wrap in markdown or backticks outside the JSON.
        """
        
        let rawResponse = try await executeGeminiRequest(prompt: prompt, image: image, additionalText: expressionText)
        let cleanJson = extractCleanJSON(from: rawResponse)
        
        guard let data = cleanJson.data(using: .utf8) else {
            throw NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Gemini"])
        }
        
        return try JSONDecoder().decode(GeminiMathResponse.self, from: data)
    }
    
    // MARK: - Parse Receipt with Multimodal AI
    
    public func analyzeReceipt(image: UIImage) async throws -> GeminiReceiptResponse {
        await MainActor.run {
            self.isAnalyzing = true
            self.lastError = nil
        }
        
        defer {
            Task { @MainActor in
                self.isAnalyzing = false
            }
        }
        
        let prompt = """
        You are an expert receipt OCR analyzer.
        Inspect this receipt image. Extract all individual purchased item names and prices.
        Ignore address lines, dates, times, phone numbers, and payment card numbers (e.g. Visa/5544).
        Return ONLY a valid JSON object matching this schema:
        {
          "storeName": "Name of store or shop",
          "currency": "USD, EUR, GBP, MAD, JPY, CAD, or AUD",
          "items": [
            {"name": "Item description 1", "price": 30.00},
            {"name": "Item description 2", "price": 30.00}
          ],
          "subtotal": 60.00,
          "tax": 0.00,
          "total": 60.00
        }
        Do NOT wrap in markdown like ```json.
        """
        
        let rawResponse = try await executeGeminiRequest(prompt: prompt, image: image)
        let cleanJson = extractCleanJSON(from: rawResponse)
        
        guard let data = cleanJson.data(using: .utf8) else {
            throw NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid receipt JSON format"])
        }
        
        return try JSONDecoder().decode(GeminiReceiptResponse.self, from: data)
    }
    
    // MARK: - Core Gemini HTTP Request
    
    private func executeGeminiRequest(prompt: String, image: UIImage? = nil, additionalText: String? = nil) async throws -> String {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(selectedModel):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "GeminiService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        
        var parts: [[String: Any]] = []
        
        var combinedText = prompt
        if let extra = additionalText, !extra.isEmpty {
            combinedText += "\nContext expression: \(extra)"
        }
        parts.append(["text": combinedText])
        
        if let img = image, let jpegData = img.jpegData(compressionQuality: 0.8) {
            let base64String = jpegData.base64EncodedString()
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": base64String
                ]
            ])
        }
        
        let payload: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 2048
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GeminiService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No response from server"])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = errorJson["error"] as? [String: Any],
               let msg = errorObj["message"] as? String {
                throw NSError(domain: "GeminiService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw NSError(domain: "GeminiService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini API error (Status \(httpResponse.statusCode))"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let resParts = content["parts"] as? [[String: Any]],
              let firstPart = resParts.first,
              let text = firstPart["text"] as? String else {
            throw NSError(domain: "GeminiService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Empty response from Gemini"])
        }
        
        return text
    }
    
    private func extractCleanJSON(from rawText: String) -> String {
        var clean = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```json") {
            clean = String(clean.dropFirst(7))
        } else if clean.hasPrefix("```") {
            clean = String(clean.dropFirst(3))
        }
        if clean.hasSuffix("```") {
            clean = String(clean.dropLast(3))
        }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
