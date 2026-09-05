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
        VStack(spacing: 6) {
            // Multi-Radix Overview Box
            VStack(spacing: 3) {
                radixRow(title: "HEX", value: viewModel.hexDisplay, base: .hex)
                radixRow(title: "DEC", value: viewModel.decDisplay, base: .dec)
                radixRow(title: "OCT", value: viewModel.octDisplay, base: .oct)
                radixRow(title: "BIN", value: viewModel.binDisplay, base: .bin)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(white: 0.12, opacity: 0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
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
                    SoundAndHapticManager.shared.triggerHaptic(.selection)
                    viewModel.isSigned.toggle()
                }) {
                    Text(viewModel.isSigned ? "SIGNED" : "UNSIGNED")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
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
            .padding(.horizontal, 2)
            
            // Interactive Bit Visualizer
            BitVisualizerView(viewModel: viewModel)
            
            // Programmer Keypad Grid
            programmerKeypadGrid
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private func radixRow(title: String, value: String, base: RadixBase) -> some View {
        let isSelected = viewModel.activeBase == base
        
        Button(action: {
            SoundAndHapticManager.shared.triggerHaptic(.selection)
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.activeBase = base
            }
        }) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? .cyan : .white.opacity(0.45))
                    .frame(width: 32, alignment: .leading)
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .monospaced))
                    .foregroundColor(isSelected ? .cyan : .white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.cyan.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var programmerKeypadGrid: some View {
        let isHex = viewModel.activeBase == .hex
        let isOct = viewModel.activeBase == .oct
        let isBin = viewModel.activeBase == .bin
        
        return VStack(spacing: 5) {
            // Row 1: Bitwise AND, OR, XOR, NOT, Clear
            HStack(spacing: 5) {
                opButton(label: "AND", op: "AND")
                opButton(label: "OR", op: "OR")
                opButton(label: "XOR", op: "XOR")
                opButton(label: "NOT", op: "NOT")
                actionButton(label: "C", type: .clear)
            }
            
            // Row 2: <<, >>, MOD, ±, ÷
            HStack(spacing: 5) {
                opButton(label: "<<", op: "LSH")
                opButton(label: ">>", op: "RSH")
                opButton(label: "MOD", op: "MOD")
                actionButton(label: "±", type: .signToggle)
                opButton(label: "÷", op: "÷")
            }
            
            // Row 3: A, B, 7, 8, 9, ×
            HStack(spacing: 5) {
                hexButton("A", enabled: isHex)
                hexButton("B", enabled: isHex)
                digitButton("7", enabled: !isBin)
                digitButton("8", enabled: !isBin && !isOct)
                digitButton("9", enabled: !isBin && !isOct)
                opButton(label: "×", op: "×")
            }
            
            // Row 4: C, D, 4, 5, 6, -
            HStack(spacing: 5) {
                hexButton("C", enabled: isHex)
                hexButton("D", enabled: isHex)
                digitButton("4", enabled: !isBin)
                digitButton("5", enabled: !isBin)
                digitButton("6", enabled: !isBin)
                opButton(label: "-", op: "-")
            }
            
            // Row 5: E, F, 1, 2, 3, +
            HStack(spacing: 5) {
                hexButton("E", enabled: isHex)
                hexButton("F", enabled: isHex)
                digitButton("1", enabled: true)
                digitButton("2", enabled: !isBin)
                digitButton("3", enabled: !isBin)
                opButton(label: "+", op: "+")
            }
            
            // Row 6: 0, ⌫, =
            HStack(spacing: 5) {
                digitButton("0", enabled: true)
                    .frame(maxWidth: .infinity)
                actionButton(label: "⌫", type: .delete)
                    .frame(maxWidth: .infinity)
                actionButton(label: "=", type: .equals)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    @ViewBuilder
    private func opButton(label: String, op: String) -> some View {
        let btn = KeypadButton(label: label, type: .bitwise(op))
        KeypadButtonView(button: btn) {
            viewModel.handleButtonPress(btn)
        }
    }
    
    @ViewBuilder
    private func actionButton(label: String, type: KeypadButtonType) -> some View {
        let btn = KeypadButton(label: label, type: type)
        KeypadButtonView(button: btn) {
            viewModel.handleButtonPress(btn)
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
        .opacity(enabled ? 1.0 : 0.25)
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
        .opacity(enabled ? 1.0 : 0.25)
        .disabled(!enabled)
    }
}
