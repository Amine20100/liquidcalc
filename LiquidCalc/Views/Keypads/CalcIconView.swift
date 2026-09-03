//
//  CalcIconView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Custom Glowing Glass Icons for Calculator Keys & Mathematical Operators
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct CalcIconView: View {
    public let label: String
    public let type: KeypadButtonType
    public let foregroundColor: Color
    public let isPressed: Bool
    public let size: CGFloat
    
    public init(
        label: String,
        type: KeypadButtonType,
        foregroundColor: Color = .white,
        isPressed: Bool = false,
        size: CGFloat = 22
    ) {
        self.label = label
        self.type = type
        self.foregroundColor = foregroundColor
        self.isPressed = isPressed
        self.size = size
    }
    
    public var body: some View {
        Group {
            switch label {
            case "+":
                plusIcon
            case "-", "−":
                minusIcon
            case "×", "*":
                multiplyIcon
            case "÷", "/":
                divideIcon
            case "=":
                equalsIcon
            case "%":
                percentIcon
            case "±":
                plusMinusIcon
            case "⌫", "DEL", "del":
                deleteIcon
            case "AC", "C":
                clearIcon
            case "√":
                sqrtIcon
            case "π":
                piIcon
            case "∫":
                integralIcon
            case "x²":
                powerIcon(exponent: "2")
            case "x³":
                powerIcon(exponent: "3")
            case "xʸ", "x^y":
                powerIcon(exponent: "y")
            case "(":
                parenthesisIcon(isOpening: true)
            case ")":
                parenthesisIcon(isOpening: false)
            default:
                defaultTextLabel
            }
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.65), value: isPressed)
    }
    
    // MARK: - 1. Plus Icon (+)
    
    private var plusIcon: some View {
        ZStack {
            // Horizontal bar
            Capsule()
                .fill(iconGradient)
                .frame(width: size * 0.9, height: size * 0.22)
            
            // Vertical bar
            Capsule()
                .fill(iconGradient)
                .frame(width: size * 0.22, height: size * 0.9)
        }
        .frame(width: size, height: size)
        .shadow(color: foregroundColor.opacity(isPressed ? 0.6 : 0.2), radius: isPressed ? 6 : 2)
    }
    
    // MARK: - 2. Minus Icon (-)
    
    private var minusIcon: some View {
        Capsule()
            .fill(iconGradient)
            .frame(width: size * 0.85, height: size * 0.22)
            .frame(width: size, height: size)
            .shadow(color: foregroundColor.opacity(isPressed ? 0.6 : 0.2), radius: isPressed ? 6 : 2)
    }
    
    // MARK: - 3. Multiply Icon (×)
    
    private var multiplyIcon: some View {
        ZStack {
            Capsule()
                .fill(iconGradient)
                .frame(width: size * 0.85, height: size * 0.22)
                .rotationEffect(.degrees(45))
            
            Capsule()
                .fill(iconGradient)
                .frame(width: size * 0.85, height: size * 0.22)
                .rotationEffect(.degrees(-45))
        }
        .frame(width: size, height: size)
        .shadow(color: foregroundColor.opacity(isPressed ? 0.6 : 0.2), radius: isPressed ? 6 : 2)
    }
    
    // MARK: - 4. Divide Icon (÷)
    
    private var divideIcon: some View {
        VStack(spacing: size * 0.16) {
            // Top dot
            Circle()
                .fill(iconGradient)
                .frame(width: size * 0.22, height: size * 0.22)
            
            // Middle bar
            Capsule()
                .fill(iconGradient)
                .frame(width: size * 0.85, height: size * 0.20)
            
            // Bottom dot
            Circle()
                .fill(iconGradient)
                .frame(width: size * 0.22, height: size * 0.22)
        }
        .frame(width: size, height: size)
        .shadow(color: foregroundColor.opacity(isPressed ? 0.6 : 0.2), radius: isPressed ? 6 : 2)
    }
    
    // MARK: - 5. Equals Icon (=)
    
    private var equalsIcon: some View {
        VStack(spacing: size * 0.20) {
            Capsule()
                .fill(iconGradient)
                .frame(width: size * 0.85, height: size * 0.22)
            
            Capsule()
                .fill(iconGradient)
                .frame(width: size * 0.85, height: size * 0.22)
        }
        .frame(width: size, height: size)
        .shadow(color: foregroundColor.opacity(isPressed ? 0.7 : 0.3), radius: isPressed ? 8 : 3)
    }
    
    // MARK: - 6. Percent Icon (%)
    
    private var percentIcon: some View {
        ZStack {
            // Diagonal slash
            Capsule()
                .fill(iconGradient)
                .frame(width: size * 0.95, height: size * 0.18)
                .rotationEffect(.degrees(-45))
            
            // Top-left circle
            Circle()
                .stroke(foregroundColor, lineWidth: size * 0.14)
                .frame(width: size * 0.32, height: size * 0.32)
                .offset(x: -size * 0.28, y: -size * 0.26)
            
            // Bottom-right circle
            Circle()
                .stroke(foregroundColor, lineWidth: size * 0.14)
                .frame(width: size * 0.32, height: size * 0.32)
                .offset(x: size * 0.28, y: size * 0.26)
        }
        .frame(width: size, height: size)
    }
    
    // MARK: - 7. Plus/Minus Icon (±)
    
    private var plusMinusIcon: some View {
        VStack(spacing: 2) {
            ZStack {
                Capsule()
                    .fill(iconGradient)
                    .frame(width: size * 0.65, height: size * 0.18)
                Capsule()
                    .fill(iconGradient)
                    .frame(width: size * 0.18, height: size * 0.65)
            }
            Capsule()
                .fill(iconGradient)
                .frame(width: size * 0.65, height: size * 0.18)
        }
        .frame(width: size, height: size)
    }
    
    // MARK: - 8. Delete / Backspace Icon (⌫)
    
    private var deleteIcon: some View {
        Image(systemName: "delete.left.fill")
            .font(.system(size: size * 0.85, weight: .medium))
            .foregroundStyle(iconGradient)
            .shadow(color: foregroundColor.opacity(isPressed ? 0.5 : 0.15), radius: 4)
    }
    
    // MARK: - 9. Clear Icon (AC / C)
    
    private var clearIcon: some View {
        Text(label)
            .font(.system(size: size * 0.9, weight: .bold, design: .rounded))
            .foregroundStyle(iconGradient)
            .shadow(color: foregroundColor.opacity(isPressed ? 0.5 : 0.15), radius: 3)
    }
    
    // MARK: - 10. Square Root Icon (√)
    
    private var sqrtIcon: some View {
        HStack(alignment: .top, spacing: 0) {
            Image(systemName: "x.squareroot")
                .font(.system(size: size * 0.95, weight: .medium))
                .foregroundStyle(iconGradient)
        }
    }
    
    // MARK: - 11. Pi Icon (π)
    
    private var piIcon: some View {
        Text("π")
            .font(.system(size: size * 1.1, weight: .medium, design: .serif))
            .foregroundStyle(iconGradient)
            .offset(y: -1)
    }
    
    // MARK: - 12. Integral Icon (∫)
    
    private var integralIcon: some View {
        Text("∫")
            .font(.system(size: size * 1.3, weight: .light, design: .serif))
            .foregroundStyle(iconGradient)
    }
    
    // MARK: - 13. Power Icon (x², xʸ)
    
    private func powerIcon(exponent: String) -> some View {
        HStack(alignment: .top, spacing: 1) {
            Text("x")
                .font(.system(size: size * 0.9, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(foregroundColor)
            
            Text(exponent)
                .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
                .foregroundColor(foregroundColor.opacity(0.9))
                .offset(y: -size * 0.2)
        }
    }
    
    // MARK: - 14. Parenthesis Icon
    
    private func parenthesisIcon(isOpening: Bool) -> some View {
        Text(isOpening ? "(" : ")")
            .font(.system(size: size * 1.05, weight: .medium, design: .rounded))
            .foregroundStyle(iconGradient)
    }
    
    // MARK: - Fallback / Standard Digits
    
    private var defaultTextLabel: some View {
        Text(label)
            .font(.system(size: size * 0.95, weight: isPressed ? .bold : .regular, design: .rounded))
            .foregroundColor(foregroundColor)
    }
    
    // MARK: - Gradients
    
    private var iconGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: foregroundColor, location: 0.0),
                .init(color: foregroundColor.opacity(0.85), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
