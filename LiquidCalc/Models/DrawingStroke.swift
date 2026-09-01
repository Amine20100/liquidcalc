//
//  DrawingStroke.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Data model for finger & Apple Pencil handwriting math canvas strokes
//

import SwiftUI

public enum DrawingTool: String, CaseIterable, Identifiable, Sendable {
    case pen = "Pen"
    case glowPen = "Neon Glow"
    case highlighter = "Highlighter"
    case eraser = "Eraser"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .pen: return "pencil.tip"
        case .glowPen: return "sparkles"
        case .highlighter: return "highlighter"
        case .eraser: return "eraser.fill"
        }
    }
}

public struct StrokePoint: Equatable, Sendable {
    public var point: CGPoint
    public var force: CGFloat
    public var timestamp: TimeInterval
    
    public init(point: CGPoint, force: CGFloat = 1.0, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.point = point
        self.force = force
        self.timestamp = timestamp
    }
}

public struct DrawingStroke: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var points: [StrokePoint]
    public var color: Color
    public var lineWidth: CGFloat
    public var tool: DrawingTool
    
    public init(
        id: UUID = UUID(),
        points: [StrokePoint] = [],
        color: Color = .cyan,
        lineWidth: CGFloat = 3.5,
        tool: DrawingTool = .glowPen
    ) {
        self.id = id
        self.points = points
        self.color = color
        self.lineWidth = lineWidth
        self.tool = tool
    }
    
    public var path: Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first.point)
        
        for p in points.dropFirst() {
            path.addLine(to: p.point)
        }
        return path
    }
}
