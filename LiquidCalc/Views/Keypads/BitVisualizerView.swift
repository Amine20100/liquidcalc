//
//  BitVisualizerView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct BitVisualizerView: View {
    @Bindable var viewModel: ProgrammerViewModel
    
    public init(viewModel: ProgrammerViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 6) {
            let totalBits = viewModel.wordSize.bitCount
            let rowsCount = max(1, totalBits / 16)
            
            ForEach((0..<rowsCount).reversed(), id: \.self) { rowIndex in
                let startBit = (rowIndex + 1) * 16 - 1
                let endBit = rowIndex * 16
                
                VStack(spacing: 2) {
                    // Header row showing bit index guides
                    HStack {
                        Text("\(startBit)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                        Spacer()
                        Text("\(startBit - 7)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.25))
                        Spacer()
                        Text("\(endBit)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(.horizontal, 4)
                    
                    // 16 bit buttons in 2 groups of 8
                    HStack(spacing: 8) {
                        // Upper byte
                        HStack(spacing: 3) {
                            ForEach((startBit - 7...startBit).reversed(), id: \.self) { bitIndex in
                                bitButton(at: bitIndex)
                            }
                        }
                        
                        // Lower byte
                        HStack(spacing: 3) {
                            ForEach((endBit...startBit - 8).reversed(), id: \.self) { bitIndex in
                                bitButton(at: bitIndex)
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                )
        )
    }
    
    @ViewBuilder
    private func bitButton(at index: Int) -> some View {
        let isSet = viewModel.isBitSet(at: index)
        
        Button(action: {
            SoundAndHapticManager.shared.playDigitClick()
            viewModel.toggleBit(at: index)
        }) {
            Text(isSet ? "1" : "0")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity, minHeight: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isSet ? Color.cyan.opacity(0.3) : Color.white.opacity(0.04))
                )
                .foregroundColor(isSet ? .cyan : .white.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(isSet ? Color.cyan.opacity(0.7) : Color.white.opacity(0.08), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }
}
