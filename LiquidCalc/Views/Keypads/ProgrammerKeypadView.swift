//
//  ProgrammerKeypadView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct ProgrammerKeypadView: View {
    @Bindable var viewModel: ProgrammerViewModel
    
    public init(viewModel: ProgrammerViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Multi-Radix Overview Box
            VStack(spacing: 4) {
                radixRow(title: "HEX", value: viewModel.hexDisplay, base: .hex)
                radixRow(title: "DEC", value: viewModel.decDisplay, base: .dec)
                radixRow(title: "OCT", value: viewModel.octDisplay, base: .oct)
                radixRow(title: "BIN", value: viewModel.binDisplay, base: .bin)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.12, opacity: 0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            
            // Configuration bar: Word Size & Signed/Unsigned
            HStack {
                Picker("Word Size", selection: $viewModel.wordSize) {
                    ForEach(WordSize.allCases) { ws in
                        Text(ws.rawValue).tag(ws)
                    }
                }
                .pickerStyle(.segmented)
                
                Button(action: {
                    viewModel.isSigned.toggle()
                }) {
                    Text(viewModel.isSigned ? "SIGNED" : "UNSIGNED")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(viewModel.isSigned ? Color.orange.opacity(0.25) : Color.white.opacity(0.1))
                        )
                        .foregroundColor(viewModel.isSigned ? .orange : .white.opacity(0.7))
                        .overlay(
                            Capsule()
                                .stroke(viewModel.isSigned ? Color.orange.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            // Interactive Bit Visualizer
            BitVisualizerView(viewModel: viewModel)
            
            // Programmer Keypad Grid
            programmerKeypadGrid
        }
        .padding(.horizontal, 8)
    }
    
    @ViewBuilder
    private func radixRow(title: String, value: String, base: RadixBase) -> some View {
        let isSelected = viewModel.activeBase == base
        
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.activeBase = base
            }
        }) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? .cyan : .white.opacity(0.45))
                    .frame(width: 34, alignment: .leading)
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .monospaced))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.cyan.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var programmerKeypadGrid: some View {
        let isHexActive = viewModel.activeBase == .hex
        let isOctActive = viewModel.activeBase == .oct
        let isBinActive = viewModel.activeBase == .bin
        
        return VStack(spacing: 6) {
            // Row 1: Bitwise AND, OR, XOR, NOT, Clear
            HStack(spacing: 6) {
                KeypadButtonView(button: KeypadButton(label: "AND", type: .bitwise("AND"))) {
                    viewModel.handleButtonPress(KeypadButton(label: "AND", type: .bitwise("AND")))
                }
                KeypadButtonView(button: KeypadButton(label: "OR", type: .bitwise("OR"))) {
                    viewModel.handleButtonPress(KeypadButton(label: "OR", type: .bitwise("OR")))
                }
                KeypadButtonView(button: KeypadButton(label: "XOR", type: .bitwise("XOR"))) {
                    viewModel.handleButtonPress(KeypadButton(label: "XOR", type: .bitwise("XOR")))
                }
                KeypadButtonView(button: KeypadButton(label: "NOT", type: .bitwise("NOT"))) {
                    viewModel.handleButtonPress(KeypadButton(label: "NOT", type: .bitwise("NOT")))
                }
                KeypadButtonView(button: KeypadButton(label: "C", type: .clear)) {
                    viewModel.handleButtonPress(KeypadButton(label: "C", type: .clear))
                }
            }
            
            // Row 2: LSH, RSH, A, B, C
            HStack(spacing: 6) {
                KeypadButtonView(button: KeypadButton(label: "<<", type: .bitwise("LSH"))) {
                    viewModel.handleButtonPress(KeypadButton(label: "LSH", type: .bitwise("LSH")))
                }
                KeypadButtonView(button: KeypadButton(label: ">>", type: .bitwise("RSH"))) {
                    viewModel.handleButtonPress(KeypadButton(label: "RSH", type: .bitwise("RSH")))
                }
                hexButton("A", enabled: isHexActive)
                hexButton("B", enabled: isHexActive)
                hexButton("C", enabled: isHexActive)
            }
            
            // Row 3: 7, 8, 9, D, E
            HStack(spacing: 6) {
                digitButton("7", enabled: !isBinActive)
                digitButton("8", enabled: !isBinActive && !isOctActive)
                digitButton("9", enabled: !isBinActive && !isOctActive)
                hexButton("D", enabled: isHexActive)
                hexButton("E", enabled: isHexActive)
            }
            
            // Row 4: 4, 5, 6, F, ⌫
            HStack(spacing: 6) {
                digitButton("4", enabled: !isBinActive)
                digitButton("5", enabled: !isBinActive)
                digitButton("6", enabled: !isBinActive)
                hexButton("F", enabled: isHexActive)
                KeypadButtonView(button: KeypadButton(label: "⌫", type: .delete)) {
                    viewModel.handleButtonPress(KeypadButton(label: "⌫", type: .delete))
                }
            }
            
            // Row 5: 1, 2, 3, 0, =
            HStack(spacing: 6) {
                digitButton("1", enabled: true)
                digitButton("2", enabled: !isBinActive)
                digitButton("3", enabled: !isBinActive)
                digitButton("0", enabled: true)
                KeypadButtonView(button: KeypadButton(label: "=", type: .equals)) {
                    viewModel.handleButtonPress(KeypadButton(label: "=", type: .equals))
                }
            }
        }
    }
    
    @ViewBuilder
    private func hexButton(_ letter: String, enabled: Bool) -> some View {
        let btn = KeypadButton(label: letter, type: .hexDigit(letter))
        KeypadButtonView(button: btn) {
            if enabled {
                viewModel.handleButtonPress(btn)
            }
        }
        .opacity(enabled ? 1.0 : 0.3)
        .disabled(!enabled)
    }
    
    @ViewBuilder
    private func digitButton(_ digit: String, enabled: Bool) -> some View {
        let btn = KeypadButton(label: digit, type: .digit(digit))
        KeypadButtonView(button: btn) {
            if enabled {
                viewModel.handleButtonPress(btn)
            }
        }
        .opacity(enabled ? 1.0 : 0.3)
        .disabled(!enabled)
    }
}
