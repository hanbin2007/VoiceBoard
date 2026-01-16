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
                    .frame(height: 24)
                Text(title)
                    .font(.caption2)
                    .frame(height: 14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
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
            // Click Before Input Toggle
            HStack {
                Image(systemName: "cursorarrow.click.2")
                    .foregroundStyle(.blue)
                Text("输入前点击")
                    .font(.subheadline)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.clickBeforeInputEnabled },
                    set: { newValue in
                        viewModel.clickBeforeInputEnabled = newValue
                        viewModel.sendCommand(.setClickBeforeInput(newValue))
                    }
                ))
                    .labelsHidden()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .disabled(!viewModel.isConnected)
            .opacity(viewModel.isConnected ? 1.0 : 0.5)
            
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
                    viewModel.addToHistory(transcript)
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
