//
//  FunctionGrapherView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Interactive 2D Real-Time Cartesian Function Grapher
//

import SwiftUI

public struct FunctionGrapherView: View {
    @State private var formulaInput: String = "x^2 - 4"
    @State private var xMin: Double = -10.0
    @State private var xMax: Double = 10.0
    @State private var yMin: Double = -10.0
    @State private var yMax: Double = 10.0
    
    // Gestures
    @State private var dragOffset: CGSize = .zero
    @State private var previousDragOffset: CGSize = .zero
    @State private var zoomScale: CGFloat = 1.0
    @State private var previousZoomScale: CGFloat = 1.0
    
    private let evaluator = MathEvaluator()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            // Function Expression Formula Bar
            HStack(spacing: 8) {
                Text("f(x) =")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                TextField("Enter formula (e.g. sin(x), x^2-4)", text: $formulaInput)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                
                // Quick Formula Presets
                Menu {
                    Button("x² - 4") { formulaInput = "x^2 - 4"; resetView() }
                    Button("sin(x)") { formulaInput = "sin(x)"; resetView() }
                    Button("cos(x) * e^(-0.2*x)") { formulaInput = "cos(x) * 2.718^(-0.2*x)"; resetView() }
                    Button("1 / x") { formulaInput = "1 / x"; resetView() }
                    Button("x³ - 3x") { formulaInput = "x^3 - 3*x"; resetView() }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.cyan)
                }
            }
            .padding(.horizontal, 14)
            
            // 2D Canvas Plotter
            ZStack {
                Canvas { context, size in
                    drawGrid(context: context, size: size)
                    drawAxes(context: context, size: size)
                    drawFunctionCurve(context: context, size: size)
                }
                .gesture(
                    SimultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                let dx = Double(value.translation.width - dragOffset.width)
                                let dy = Double(value.translation.height - dragOffset.height)
                                dragOffset = value.translation
                                
                                let spanX = xMax - xMin
                                let spanY = yMax - yMin
                                let shiftX = -dx * (spanX / 300.0)
                                let shiftY = dy * (spanY / 300.0)
                                
                                xMin += shiftX
                                xMax += shiftX
                                yMin += shiftY
                                yMax += shiftY
                            }
                            .onEnded { _ in
                                dragOffset = .zero
                            },
                        MagnificationGesture()
                            .onChanged { scale in
                                let delta = scale / zoomScale
                                zoomScale = scale
                                
                                let midX = (xMin + xMax) / 2.0
                                let midY = (yMin + yMax) / 2.0
                                let halfSpanX = ((xMax - xMin) / 2.0) / Double(delta)
                                let halfSpanY = ((yMax - yMin) / 2.0) / Double(delta)
                                
                                xMin = midX - halfSpanX
                                xMax = midX + halfSpanX
                                yMin = midY - halfSpanY
                                yMax = midY + halfSpanY
                            }
                            .onEnded { _ in
                                zoomScale = 1.0
                            }
                    )
                )
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.45)))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.cyan.opacity(0.35), lineWidth: 1.5)
                )
                
                // Controls overlay (Reset Zoom, Range badge)
                VStack {
                    HStack {
                        Text(String(format: "X: [%.1f, %.1f]  Y: [%.1f, %.1f]", xMin, xMax, yMin, yMax))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(6)
                            .background(Capsule().fill(Color.black.opacity(0.6)))
                        
                        Spacer()
                        
                        Button(action: resetView) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.cyan.opacity(0.15)))
                        }
                    }
                    .padding(10)
                    
                    Spacer()
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 12)
        }
    }
    
    private func resetView() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            xMin = -10.0
            xMax = 10.0
            yMin = -10.0
            yMax = 10.0
            dragOffset = .zero
            zoomScale = 1.0
        }
    }
    
    // MARK: - Drawing Helpers
    
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridStep = calculateGridStep(range: xMax - xMin)
        var path = Path()
        
        var x = (xMin / gridStep).rounded(.down) * gridStep
        while x <= xMax {
            let screenX = mapX(x, size: size)
            path.move(to: CGPoint(x: screenX, y: 0))
            path.addLine(to: CGPoint(x: screenX, y: size.height))
            x += gridStep
        }
        
        var y = (yMin / gridStep).rounded(.down) * gridStep
        while y <= yMax {
            let screenY = mapY(y, size: size)
            path.move(to: CGPoint(x: 0, y: screenY))
            path.addLine(to: CGPoint(x: size.width, y: screenY))
            y += gridStep
        }
        
        context.stroke(path, with: .color(Color.white.opacity(0.08)), lineWidth: 1)
    }
    
    private func drawAxes(context: GraphicsContext, size: CGSize) {
        var path = Path()
        
        // Y-axis (where x = 0)
        let originX = mapX(0, size: size)
        path.move(to: CGPoint(x: originX, y: 0))
        path.addLine(to: CGPoint(x: originX, y: size.height))
        
        // X-axis (where y = 0)
        let originY = mapY(0, size: size)
        path.move(to: CGPoint(x: 0, y: originY))
        path.addLine(to: CGPoint(x: size.width, y: originY))
        
        context.stroke(path, with: .color(Color.cyan.opacity(0.6)), lineWidth: 1.5)
    }
    
    private func drawFunctionCurve(context: GraphicsContext, size: CGSize) {
        let pointsCount = Int(size.width)
        guard pointsCount > 2 else { return }
        
        var path = Path()
        var hasStarted = false
        
        let dx = (xMax - xMin) / Double(pointsCount)
        
        for i in 0...pointsCount {
            let mathX = xMin + Double(i) * dx
            let mathY = evaluateExpression(at: mathX)
            
            if mathY.isFinite && !mathY.isNaN {
                let screenX = mapX(mathX, size: size)
                let screenY = mapY(mathY, size: size)
                
                if screenY >= -size.height && screenY <= 2 * size.height {
                    if !hasStarted {
                        path.move(to: CGPoint(x: screenX, y: screenY))
                        hasStarted = true
                    } else {
                        path.addLine(to: CGPoint(x: screenX, y: screenY))
                    }
                } else {
                    hasStarted = false
                }
            } else {
                hasStarted = false
            }
        }
        
        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [.cyan, .blue, .purple]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: size.height)
            ),
            lineWidth: 2.5
        )
    }
    
    private func mapX(_ x: Double, size: CGSize) -> CGFloat {
        let span = xMax - xMin
        guard span > 0 else { return 0 }
        return CGFloat((x - xMin) / span) * size.width
    }
    
    private func mapY(_ y: Double, size: CGSize) -> CGFloat {
        let span = yMax - yMin
        guard span > 0 else { return 0 }
        return CGFloat((yMax - y) / span) * size.height
    }
    
    private func calculateGridStep(range: Double) -> Double {
        let rawStep = range / 8.0
        let mag = pow(10.0, floor(log10(rawStep)))
        let norm = rawStep / mag
        if norm < 2 { return 1 * mag }
        if norm < 5 { return 2 * mag }
        return 5 * mag
    }
    
    private func evaluateExpression(at x: Double) -> Double {
        let expr = formulaInput
            .replacingOccurrences(of: "x", with: "(\(String(format: "%.8f", x)))")
            .replacingOccurrences(of: "X", with: "(\(String(format: "%.8f", x)))")
        
        do {
            return try evaluator.evaluate(expression: expr)
        } catch {
            return .nan
        }
    }
}
