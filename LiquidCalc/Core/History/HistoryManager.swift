//
//  HistoryManager.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation
import SwiftUI

@Observable
public final class HistoryManager {
    public static let shared = HistoryManager()
    
    public var items: [HistoryItem] = []
    private let storageKey = "LiquidCalc_History_Storage_v1"
    private let maxCapacity = 200
    
    public init() {
        loadHistory()
    }
    
    public func addItem(expression: String, result: String, mode: String) {
        let trimmedExpr = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRes = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExpr.isEmpty, !trimmedRes.isEmpty, trimmedRes != "Error" else { return }
        
        let newItem = HistoryItem(expression: trimmedExpr, result: trimmedRes, mode: mode)
        items.insert(newItem, at: 0)
        
        if items.count > maxCapacity {
            items = Array(items.prefix(maxCapacity))
        }
        
        saveHistory()
    }
    
    public func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        saveHistory()
    }
    
    public func clearAll() {
        items.removeAll()
        saveHistory()
    }
    
    public func clearHistory() {
        clearAll()
    }
    
    public func exportAsText() -> String {
        return items.map { "\($0.formattedDate) \($0.formattedTime): \($0.expression) = \($0.result)" }
            .joined(separator: "\n")
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) else {
            return
        }
        self.items = decoded
    }
}
