//
//  HistoryItem.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation

public struct HistoryItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let expression: String
    public let result: String
    public let mode: String
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), expression: String, result: String, mode: String) {
        self.id = id
        self.timestamp = timestamp
        self.expression = expression
        self.result = result
        self.mode = mode
    }
    
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: timestamp)
    }
}
