//
//  ReceiptSplitterView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct ReceiptSplitterView: View {
    @Bindable var viewModel: VisionViewModel
    @State private var selectedCurrency: SupportedCurrency = .usd
    
    public init(viewModel: VisionViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Currency Selector Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SupportedCurrency.allCases) { currency in
                        Button(action: {
                            SoundAndHapticManager.shared.triggerHaptic(.selection)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedCurrency = currency
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(currency.flag)
                                Text(currency.code)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedCurrency == currency ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        selectedCurrency == currency ? Color.cyan : Color.white.opacity(0.12),
                                        lineWidth: selectedCurrency == currency ? 1.5 : 1.0
                                    )
                            )
                            .foregroundColor(selectedCurrency == currency ? .cyan : .white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Per Person Summary Card
            VStack(spacing: 6) {
                Text("PER PERSON SHARE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                    .tracking(1.0)
                
                Text(selectedCurrency.format(amount: viewModel.receiptPerPerson))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(0.45), radius: 12)
                    .contentTransition(.numericText())
                
                HStack(spacing: 16) {
                    Text("Total: \(selectedCurrency.format(amount: viewModel.receiptTotal))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text("Split \(viewModel.splitCount) \(viewModel.splitCount == 1 ? "way" : "ways")")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(white: 0.12, opacity: 0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.6), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .padding(.horizontal, 12)
            
            // Subtotal, Tax, Tip Breakdown Pill
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Subtotal")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    Text(selectedCurrency.format(amount: viewModel.receiptSubtotal))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tax (\(String(format: "%.1f", viewModel.taxRate))%)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    Text(selectedCurrency.format(amount: viewModel.receiptTaxAmount))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Tip (\(Int(viewModel.tipPercentage))%)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    Text(selectedCurrency.format(amount: viewModel.receiptTipAmount))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .padding(.horizontal, 12)
            
            // Tip & Split Controls
            VStack(spacing: 10) {
                // Tip Segmented Selector
                HStack {
                    Text("Tip:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    HStack(spacing: 5) {
                        ForEach([0.0, 10.0, 15.0, 18.0, 20.0, 25.0], id: \.self) { tip in
                            Button(action: {
                                SoundAndHapticManager.shared.triggerHaptic(.selection)
                                viewModel.tipPercentage = tip
                            }) {
                                Text("\(Int(tip))%")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(viewModel.tipPercentage == tip ? Color.orange : Color.white.opacity(0.1))
                                    )
                                    .foregroundColor(viewModel.tipPercentage == tip ? .black : .white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Split People Stepper
                HStack {
                    Text("Split Between:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            if viewModel.splitCount > 1 {
                                SoundAndHapticManager.shared.triggerHaptic(.light)
                                viewModel.splitCount -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(viewModel.splitCount > 1 ? .cyan : .white.opacity(0.2))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.splitCount <= 1)
                        
                        Text("\(viewModel.splitCount)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .frame(minWidth: 28)
                            .contentTransition(.numericText())
                        
                        Button(action: {
                            if viewModel.splitCount < 30 {
                                SoundAndHapticManager.shared.triggerHaptic(.light)
                                viewModel.splitCount += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(viewModel.splitCount < 30 ? .cyan : .white.opacity(0.2))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.splitCount >= 30)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.1, opacity: 0.4))
            )
            .padding(.horizontal, 12)
            
            // Scanned Line Items List
            if !viewModel.receiptItems.isEmpty {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(viewModel.receiptItems) { item in
                            HStack {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                                Spacer()
                                Text(selectedCurrency.format(amount: item.amount))
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxHeight: 140)
            }
        }
    }
}
