//
//  UnitConverterView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct UnitConverterView: View {
    @Bindable var viewModel: UnitConverterViewModel
    @State private var swapRotation: Double = 0
    
    public init(viewModel: UnitConverterViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Category Selector Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(UnitCategory.allCases) { category in
                        Button(action: {
                            SoundAndHapticManager.shared.playDigitClick()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.selectedCategory = category
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: category.iconName)
                                    .font(.system(size: 12))
                                Text(category.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedCategory == category ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08))
                            )
                            .foregroundColor(viewModel.selectedCategory == category ? .cyan : .white.opacity(0.7))
                            .overlay(
                                Capsule()
                                    .stroke(viewModel.selectedCategory == category ? Color.cyan.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Conversion Display Cards
            VStack(spacing: 8) {
                // Source Unit Card
                conversionCard(
                    title: "FROM",
                    value: viewModel.inputString,
                    selectedUnit: viewModel.sourceUnit,
                    units: viewModel.selectedCategory.units
                ) { newUnit in
                    viewModel.sourceUnit = newUnit
                    viewModel.recalculate()
                }
                
                // Swap Units Button
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        swapRotation += 180
                        viewModel.swapUnits()
                    }
                }) {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.cyan)
                        .rotationEffect(.degrees(swapRotation))
                        .padding(4)
                }
                .buttonStyle(.plain)
                
                // Target Unit Card
                conversionCard(
                    title: "TO",
                    value: viewModel.outputString,
                    selectedUnit: viewModel.targetUnit,
                    units: viewModel.selectedCategory.units
                ) { newUnit in
                    viewModel.targetUnit = newUnit
                    viewModel.recalculate()
                }
            }
            .padding(.horizontal, 12)
            
            // Numeric Input Pad for Converter
            converterNumericPad
        }
    }
    
    @ViewBuilder
    private func conversionCard(
        title: String,
        value: String,
        selectedUnit: UnitItem,
        units: [UnitItem],
        onUnitChanged: @escaping (UnitItem) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                
                Spacer()
                
                Menu {
                    ForEach(units) { unit in
                        Button(action: { onUnitChanged(unit) }) {
                            HStack {
                                Text("\(unit.name) (\(unit.symbol))")
                                if unit.id == selectedUnit.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(selectedUnit.name) (\(selectedUnit.symbol))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.cyan)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.cyan.opacity(0.8))
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.cyan.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            
            Text(value)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.12, opacity: 0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
    
    private var converterNumericPad: some View {
        let grid = [
            ["7", "8", "9"],
            ["4", "5", "6"],
            ["1", "2", "3"],
            [".", "0", "⌫"]
        ]
        
        return VStack(spacing: 8) {
            ForEach(0..<grid.count, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(grid[row], id: \.self) { item in
                        Button(action: {
                            SoundAndHapticManager.shared.playDigitClick()
                            if item == "⌫" {
                                viewModel.deleteBackward()
                            } else if item == "." {
                                viewModel.appendDecimal()
                            } else {
                                viewModel.appendDigit(item)
                            }
                        }) {
                            Text(item)
                                .font(.system(size: 22, weight: .medium, design: .rounded))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(white: 0.18, opacity: 0.6))
                                )
                                .foregroundColor(.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Clear All Button
            Button(action: {
                SoundAndHapticManager.shared.playOperatorBurst()
                viewModel.clear()
            }) {
                Text("Clear")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.orange.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.orange.opacity(0.4), lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
    }
}
