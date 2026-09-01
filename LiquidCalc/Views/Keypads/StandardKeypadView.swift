//
//  StandardKeypadView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct StandardKeypadView: View {
    @Bindable var viewModel: CalculatorViewModel
    
    public init(viewModel: CalculatorViewModel) {
        self.viewModel = viewModel
    }
    
    private var rows: [[KeypadButton]] {
        [
            [
                KeypadButton(label: viewModel.expression.isEmpty ? "AC" : "C", type: viewModel.expression.isEmpty ? .allClear : .clear),
                KeypadButton(label: "⁺∕₋", type: .signToggle),
                KeypadButton(label: "%", type: .percent),
                KeypadButton(label: "÷", type: .operation("/"))
            ],
            [
                KeypadButton(label: "7", type: .digit("7")),
                KeypadButton(label: "8", type: .digit("8")),
                KeypadButton(label: "9", type: .digit("9")),
                KeypadButton(label: "×", type: .operation("*"))
            ],
            [
                KeypadButton(label: "4", type: .digit("4")),
                KeypadButton(label: "5", type: .digit("5")),
                KeypadButton(label: "6", type: .digit("6")),
                KeypadButton(label: "−", type: .operation("-"))
            ],
            [
                KeypadButton(label: "1", type: .digit("1")),
                KeypadButton(label: "2", type: .digit("2")),
                KeypadButton(label: "3", type: .digit("3")),
                KeypadButton(label: "+", type: .operation("+"))
            ],
            [
                KeypadButton(label: "0", type: .digit("0")),
                KeypadButton(label: ".", type: .decimal),
                KeypadButton(label: "⌫", type: .delete),
                KeypadButton(label: "=", type: .equals)
            ]
        ]
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 12) {
                    ForEach(rows[rowIndex]) { button in
                        KeypadButtonView(button: button) {
                            viewModel.handleButtonPress(button)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
    }
}
