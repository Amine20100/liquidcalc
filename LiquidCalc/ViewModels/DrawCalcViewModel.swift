//
//  DrawCalcViewModel.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  ViewModel for Draw Calc (Math Notes & Finger/Stylus Handwriting Math)
//

import SwiftUI

@Observable
public final class DrawCalcViewModel {
    public var strokes: [DrawingStroke] = []
    public var currentStroke: DrawingStroke? = nil
    public var undoStack: [[DrawingStroke]] = []
    
    // Tools & Styling
    public var selectedTool: DrawingTool = .glowPen
    public var selectedColor: Color = .cyan
    public var strokeWidth: CGFloat = 4.0
    
    // Recognition & Motion FX
    public var isRecognizing: Bool = false
    public var recognizedExpression: String = ""
    public var solvedResult: String? = nil
    public var isRevealingResult: Bool = false
    public var revealProgress: CGFloat = 0.0
    public var lastResultPosition: CGPoint = CGPoint(x: 200, y: 150)
    
    private let recognizer = HandwritingMathRecognizer.shared
    private var recognitionTimer: Timer? = nil
    
    public init() {}
    
    // MARK: - Touch & Stroke Handling
    
    public func startStroke(at point: CGPoint, force: CGFloat = 1.0) {
        if selectedTool == .eraser {
            eraseStrokes(near: point)
            return
        }
        
        let initialPoint = StrokePoint(point: point, force: force)
        currentStroke = DrawingStroke(
            points: [initialPoint],
            color: selectedColor,
            lineWidth: strokeWidth,
            tool: selectedTool
        )
    }
    
    public func appendPoint(_ point: CGPoint, force: CGFloat = 1.0) {
        if selectedTool == .eraser {
            eraseStrokes(near: point)
            return
        }
        
        guard currentStroke != nil else { return }
        currentStroke?.points.append(StrokePoint(point: point, force: force))
    }
    
    public func finishStroke(canvasSize: CGSize) {
        if let stroke = currentStroke, stroke.points.count > 1 {
            undoStack.append(strokes)
            strokes.append(stroke)
            currentStroke = nil
            
            // Trigger haptic feedback for stroke completion
            SoundAndHapticManager.shared.playDigitClick()
            
            // Auto-schedule recognition after drawing pause (600ms)
            scheduleRecognition(canvasSize: canvasSize)
        } else {
            currentStroke = nil
        }
    }
    
    private func eraseStrokes(near point: CGPoint, radius: CGFloat = 24.0) {
        let beforeCount = strokes.count
        strokes.removeAll { stroke in
            stroke.points.contains { p in
                hypot(p.point.x - point.x, p.point.y - point.y) < radius
            }
        }
        if strokes.count < beforeCount {
            SoundAndHapticManager.shared.playDigitClick()
        }
    }
    
    // MARK: - Recognition & Motion Solve
    
    public func scheduleRecognition(canvasSize: CGSize) {
        recognitionTimer?.invalidate()
        recognitionTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            self?.performRecognition(canvasSize: canvasSize)
        }
    }
    
    public func performRecognition(canvasSize: CGSize) {
        guard !strokes.isEmpty else { return }
        isRecognizing = true
        
        #if canImport(UIKit)
        recognizer.recognizeStrokes(strokes, canvasSize: canvasSize) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRecognizing = false
                
                guard let res = result else { return }
                
                self.recognizedExpression = res.sanitizedExpression
                
                if let solved = res.solvedResult {
                    self.solvedResult = solved
                    
                    // Position the solved text at the end of the last drawn stroke
                    if let lastPoint = self.strokes.last?.points.last?.point {
                        self.lastResultPosition = CGPoint(x: min(canvasSize.width - 90, lastPoint.x + 30), y: lastPoint.y)
                    }
                    
                    // Trigger fluid neon ink reveal animation
                    self.animateSolveReveal()
                }
            }
        }
        #endif
    }
    
    private func animateSolveReveal() {
        SoundAndHapticManager.shared.triggerHaptic(.success)
        SoundAndHapticManager.shared.playSuccessSound()
        
        revealProgress = 0.0
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
            self.isRevealingResult = true
            self.revealProgress = 1.0
        }
        
        // Add to calculation history tape
        if let sol = solvedResult, !recognizedExpression.isEmpty {
            HistoryManager.shared.addItem(expression: recognizedExpression, result: sol, mode: "Draw")
        }
    }
    
    // MARK: - Actions
    
    public func undo() {
        guard let prev = undoStack.popLast() else { return }
        SoundAndHapticManager.shared.playDigitClick()
        strokes = prev
        if strokes.isEmpty {
            recognizedExpression = ""
            solvedResult = nil
            isRevealingResult = false
        }
    }
    
    public func clearCanvas() {
        SoundAndHapticManager.shared.triggerHaptic(.medium)
        withAnimation(.easeInOut(duration: 0.25)) {
            undoStack.append(strokes)
            strokes.removeAll()
            currentStroke = nil
            recognizedExpression = ""
            solvedResult = nil
            isRevealingResult = false
        }
    }
}
