//
//  ReceiptSplitterView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct ReceiptSplitterView: View {
    @Bindable var viewModel: VisionViewModel
    
    public init(viewModel: VisionViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Per Person Summary Card
            VStack(spacing: 6) {
                Text("PER PERSON")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
                
                Text(String(format: "$%.2f", viewModel.receiptPerPerson))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(0.4), radius: 10)
                
                HStack(spacing: 16) {
                    Text("Total: \(String(format: "$%.2f", viewModel.receiptTotal))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Split \(viewModel.splitCount) ways")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(white: 0.12, opacity: 0.5))
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
            
            // Tip & Split Controls
            VStack(spacing: 10) {
                // Tip Segmented Selector
                HStack {
                    Text("Tip:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        ForEach([15.0, 18.0, 20.0, 25.0], id: \.self) { tip in
                            Button(action: {
                                SoundAndHapticManager.shared.triggerHaptic(.selection)
                                viewModel.tipPercentage = tip
                            }) {
                                Text("\(Int(tip))%")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
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
                                .font(.system(size: 24))
                                .foregroundColor(.cyan)
                        }
                        .buttonStyle(.plain)
                        
                        Text("\(viewModel.splitCount)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .frame(minWidth: 28)
                        
                        Button(action: {
                            if viewModel.splitCount < 30 {
                                SoundAndHapticManager.shared.triggerHaptic(.light)
                                viewModel.splitCount += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.cyan)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
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
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                                Text(String(format: "$%.2f", item.amount))
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxHeight: 160)
            }
        }
    }
}
