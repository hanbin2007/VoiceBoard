//
//  MessageHistoryView.swift
//  VoiceBoard
//
//  View for displaying and managing message history with resend functionality
//

#if os(iOS)
import SwiftUI

/// View for displaying message history with resend functionality
struct MessageHistoryView: View {
    @ObservedObject var viewModel: ConnectionViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.messageHistory.isEmpty {
                    emptyStateView
                } else {
                    historyListView
                }
            }
            .navigationTitle("历史记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                if !viewModel.messageHistory.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            viewModel.clearHistory()
                        } label: {
                            Text("清空")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("暂无历史记录")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("发送的消息将显示在这里")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var historyListView: some View {
        List {
            ForEach(viewModel.messageHistory) { item in
                HistoryItemRow(
                    item: item,
                    isConnected: viewModel.isConnected,
                    onInsert: {
                        viewModel.insertMessage(item)
                        dismiss()
                    },
                    onResend: {
                        viewModel.resendMessage(item)
                        dismiss()
                    }
                )
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let item = viewModel.messageHistory[index]
                    viewModel.deleteHistoryItem(item)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - History Item Row

/// A single row in the history list
struct HistoryItemRow: View {
    let item: MessageHistoryItem
    let isConnected: Bool
    let onInsert: () -> Void
    let onResend: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.content)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundStyle(.primary)
                
                Text(item.formattedTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 8)
            
            // Action Buttons
            HStack(spacing: 12) {
                // Insert Button (without Enter)
                Button(action: onInsert) {
                    Image(systemName: "text.cursor")
                        .font(.title2)
                        .foregroundStyle(isConnected ? .orange : .gray)
                }
                .buttonStyle(.plain)
                .disabled(!isConnected)
                
                // Resend Button (with Enter)
                Button(action: onResend) {
                    Image(systemName: "paperplane.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isConnected ? .green : .gray)
                }
                .buttonStyle(.plain)
                .disabled(!isConnected)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    MessageHistoryView(viewModel: ConnectionViewModel())
}
#endif

