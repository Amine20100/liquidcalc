//
//  GeminiService.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Google Gemini 2.5 / 1.5 Flash Multimodal AI Math & Receipt Engine
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
    
    public var apiKey: String = "AIzaSyBlX0R6vRJ6LOwrxblV4weneOu9rBLmxTc"
    public var selectedModel: String = "gemini-1.5-flash"
    public var isAnalyzing: Bool = false
    public var lastError: String? = nil
    
    private let userDefaultsApiKey = "LiquidCalc_GeminiApiKey"
    
    public init() {
        if let customKey = UserDefaults.standard.string(forKey: userDefaultsApiKey), !customKey.isEmpty {
            self.apiKey = customKey
        }
    }
    
    public func updateApiKey(_ newKey: String) {
        self.apiKey = newKey
        UserDefaults.standard.set(newKey, forKey: userDefaultsApiKey)
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
        Solve the mathematical equation or problem shown in the image or text.
        Return ONLY a valid JSON object matching this exact schema:
        {
          "expression": "the clean sanitized mathematical equation",
          "result": "the precise numerical or algebraic answer",
          "steps": ["step 1 description", "step 2 description", "step 3 description"],
          "explanation": "brief concise summary of how this was calculated"
        }
        Do NOT wrap in markdown backticks or text outside JSON.
        """
        
        let rawResponse = try await executeGeminiRequest(prompt: prompt, image: image, additionalText: expressionText)
        let cleanJson = extractCleanJSON(from: rawResponse)
        
        guard let data = cleanJson.data(using: .utf8) else {
            throw NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format from Gemini"])
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
        Ignore address lines, dates, order numbers, payment card numbers (e.g. Visa/5544), and cashier names.
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
        Do NOT include any markdown formatting like ```json.
        """
        
        let rawResponse = try await executeGeminiRequest(prompt: prompt, image: image)
        let cleanJson = extractCleanJSON(from: rawResponse)
        
        guard let data = cleanJson.data(using: .utf8) else {
            throw NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid receipt JSON format"])
        }
        
        return try JSONDecoder().decode(GeminiReceiptResponse.self, from: data)
    }
    
    // MARK: - Ask AI Math Tutor Question
    
    public func askMathTutor(prompt: String, contextImage: UIImage? = nil) async throws -> String {
        await MainActor.run {
            self.isAnalyzing = true
            self.lastError = nil
        }
        
        defer {
            Task { @MainActor in
                self.isAnalyzing = false
            }
        }
        
        let systemPrompt = """
        You are LiquidCalc AI, a brilliant, friendly, and concise mathematical tutor.
        Help the user solve formulas, understand calculus, linear algebra, unit conversions, physics formulas, or geometry.
        Keep answers clear, visually structured, and highlight key results.
        """
        
        return try await executeGeminiRequest(prompt: "\(systemPrompt)\n\nUser Question: \(prompt)", image: contextImage)
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
            "contents": [
                [
                    "parts": parts
                ]
            ],
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
