//
//  ScientificKeypadView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct ScientificKeypadView: View {
    @Bindable var viewModel: CalculatorViewModel
    @State private var isSecondary = false
    
    public init(viewModel: CalculatorViewModel) {
        self.viewModel = viewModel
    }
    
    private var rows: [[KeypadButton]] {
        [
            // Row 1: Function toggles & parens
            [
                KeypadButton(label: isSecondary ? "1st" : "2nd", type: .scientific("toggle2nd")),
                KeypadButton(label: viewModel.angleUnit == .radians ? "Deg" : "Rad", type: .scientific("toggleAngle")),
                KeypadButton(label: "(", type: .parenthesis("(")),
                KeypadButton(label: ")", type: .parenthesis(")")),
                KeypadButton(label: "C", type: .clear)
            ],
            // Row 2: Trig functions & power
            [
                KeypadButton(label: isSecondary ? "asin" : "sin", type: .scientific(isSecondary ? "asin" : "sin")),
                KeypadButton(label: isSecondary ? "acos" : "cos", type: .scientific(isSecondary ? "acos" : "cos")),
                KeypadButton(label: isSecondary ? "atan" : "tan", type: .scientific(isSecondary ? "atan" : "tan")),
                KeypadButton(label: "xʸ", type: .scientific("xʸ")),
                KeypadButton(label: "÷", type: .operation("/"))
            ],
            // Row 3: Logarithms, roots, multiply
            [
                KeypadButton(label: isSecondary ? "eˣ" : "ln", type: .scientific(isSecondary ? "eˣ" : "ln")),
                KeypadButton(label: isSecondary ? "10ˣ" : "log", type: .scientific(isSecondary ? "10ˣ" : "log")),
                KeypadButton(label: isSecondary ? "∛" : "√", type: .scientific(isSecondary ? "cbrt" : "sqrt")),
                KeypadButton(label: "%", type: .percent),
                KeypadButton(label: "×", type: .operation("*"))
            ],
            // Row 4: Digits 7-9, factorial, subtract
            [
                KeypadButton(label: "7", type: .digit("7")),
                KeypadButton(label: "8", type: .digit("8")),
                KeypadButton(label: "9", type: .digit("9")),
                KeypadButton(label: "x!", type: .scientific("x!")),
                KeypadButton(label: "−", type: .operation("-"))
            ],
            // Row 5: Digits 4-6, reciprocal, add
            [
                KeypadButton(label: "4", type: .digit("4")),
                KeypadButton(label: "5", type: .digit("5")),
                KeypadButton(label: "6", type: .digit("6")),
                KeypadButton(label: "1/x", type: .scientific("1/x")),
                KeypadButton(label: "+", type: .operation("+"))
            ],
            // Row 6: Digits 1-3, constants
            [
                KeypadButton(label: "1", type: .digit("1")),
                KeypadButton(label: "2", type: .digit("2")),
                KeypadButton(label: "3", type: .digit("3")),
                KeypadButton(label: "π", type: .constant("π")),
                KeypadButton(label: "e", type: .constant("e"))
            ],
            // Row 7: 0, decimal, backspace, equals
            [
                KeypadButton(label: "0", type: .digit("0")),
                KeypadButton(label: ".", type: .decimal),
                KeypadButton(label: "⁺∕₋", type: .signToggle),
                KeypadButton(label: "⌫", type: .delete),
                KeypadButton(label: "=", type: .equals)
            ]
        ]
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(rows[rowIndex]) { button in
                        KeypadButtonView(button: button) {
                            if button.label == "2nd" || button.label == "1st" {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isSecondary.toggle()
                                }
                            } else if button.label == "Rad" || button.label == "Deg" {
                                withAnimation {
                                    viewModel.angleUnit = viewModel.angleUnit == .radians ? .degrees : .radians
                                }
                            } else {
                                viewModel.handleButtonPress(button)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }
}
