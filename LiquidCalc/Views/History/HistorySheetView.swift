//
//  HistorySheetView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import SwiftUI

public struct HistorySheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var calculatorViewModel: CalculatorViewModel
    private let onAskAI: ((WorkspaceContext) -> Void)?
    private let onSaveToNotes: ((WorkspaceContext) -> Void)?
    private var historyManager = HistoryManager.shared
    
    @State private var searchText = ""
    @State private var showClearConfirmation = false
    @State private var copiedItemId: UUID? = nil
    
    public init(calculatorViewModel: CalculatorViewModel, onAskAI: ((WorkspaceContext) -> Void)? = nil, onSaveToNotes: ((WorkspaceContext) -> Void)? = nil) {
        self.calculatorViewModel = calculatorViewModel
        self.onAskAI = onAskAI
        self.onSaveToNotes = onSaveToNotes
    }
    
    private var filteredItems: [HistoryItem] {
        if searchText.isEmpty {
            return historyManager.items
        }
        return historyManager.items.filter {
            $0.expression.localizedCaseInsensitiveContains(searchText) ||
            $0.result.localizedCaseInsensitiveContains(searchText) ||
            $0.mode.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.07, green: 0.08, blue: 0.12)
                    .ignoresSafeArea()
                
                if historyManager.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No Calculations Yet")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        Text("Your calculations will automatically appear here as a tape history.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.35))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            historyCard(for: item)
                                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        historyManager.removeItem(id: item.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "Search history...")
                }
            }
            .navigationTitle("Calculation Tape")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !historyManager.items.isEmpty {
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Text("Clear")
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Clear All History?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("Clear All", role: .destructive) {
                    historyManager.clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    @ViewBuilder
    private func historyCard(for item: HistoryItem) -> some View {
        Button(action: {
            SoundAndHapticManager.shared.playOperatorBurst()
            calculatorViewModel.insertFromHistory(item)
            dismiss()
        }) {
            VStack(alignment: .trailing, spacing: 6) {
                // Header (Date, Time, Mode)
                HStack {
                    Text(item.mode)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.15))
                        .foregroundColor(.cyan)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    Text("\(item.formattedDate) • \(item.formattedTime)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                }
                
                // Expression
                Text(item.expression)
                    .font(.system(size: 15, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(2)
                
                // Result Row + Copy button
                HStack {
                    Button(action: {
                        #if os(iOS)
                        UIPasteboard.general.string = item.result
                        #endif
                        SoundAndHapticManager.shared.playDigitClick()
                        copiedItemId = item.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            if copiedItemId == item.id {
                                copiedItemId = nil
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: copiedItemId == item.id ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                            Text(copiedItemId == item.id ? "Copied" : "Copy")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(copiedItemId == item.id ? .green : .white.opacity(0.6))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onSaveToNotes?(.calculation(expression: item.expression, result: item.result))
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 30, height: 28)
                            .background(Color.green.opacity(0.14))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onAskAI?(.calculation(expression: item.expression, result: item.result))
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 30, height: 28)
                            .background(Color.purple.opacity(0.16))
                            .foregroundColor(.purple)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Text("= \(item.result)")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.13, opacity: 0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
