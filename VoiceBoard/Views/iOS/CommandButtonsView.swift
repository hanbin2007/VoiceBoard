//
//  CommandButtonsView.swift
//  VoiceBoard
//
//  iOS control buttons for sending commands to Mac
//

#if os(iOS)
import SwiftUI

// MARK: - Command Button Component

/// A styled button for sending commands
struct CommandButton: View {
    let title: String
    let icon: String
    let color: Color
    let disabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(disabled ? Color(.systemGray5) : color.opacity(0.15))
            .foregroundStyle(disabled ? .secondary : color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(disabled)
    }
}

// MARK: - Control Buttons Panel

/// Panel containing all control buttons for iOS
struct ControlButtonsPanel: View {
    @ObservedObject var viewModel: ConnectionViewModel
    @Binding var transcript: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Primary Actions Row
            HStack(spacing: 12) {
                // Insert Text Button
                CommandButton(
                    title: "插入",
                    icon: "text.cursor",
                    color: .blue,
                    disabled: !viewModel.isConnected || transcript.isEmpty
                ) {
                    viewModel.sendCommand(.insert(transcript))
                }
                
                // Insert + Enter Button
                CommandButton(
                    title: "发送",
                    icon: "paperplane.fill",
                    color: .green,
                    disabled: !viewModel.isConnected || transcript.isEmpty
                ) {
                    viewModel.sendCommand(.insertAndEnter(transcript))
                    transcript = ""
                }
            }
            
            // Secondary Actions Row
            HStack(spacing: 12) {
                // Clear Input Field
                CommandButton(
                    title: "清空",
                    icon: "trash",
                    color: .orange,
                    disabled: !viewModel.isConnected
                ) {
                    viewModel.sendCommand(.clear)
                }
                
                // Enter Key
                CommandButton(
                    title: "回车",
                    icon: "return",
                    color: .purple,
                    disabled: !viewModel.isConnected
                ) {
                    viewModel.sendCommand(.enter)
                }
                
                // Paste
                CommandButton(
                    title: "粘贴",
                    icon: "doc.on.clipboard",
                    color: .teal,
                    disabled: !viewModel.isConnected
                ) {
                    viewModel.sendCommand(.paste)
                }
                
                // Delete
                CommandButton(
                    title: "删除",
                    icon: "delete.left",
                    color: .red,
                    disabled: !viewModel.isConnected
                ) {
                    viewModel.sendCommand(.delete)
                }
            }
        }
    }
}
#endif
