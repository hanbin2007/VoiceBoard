//
//  CommandButtonsView.swift
//  VoiceBoard
//
//  iOS control buttons for sending commands to Mac
//

#if os(iOS)
import SwiftUI

// MARK: - Command Button Component
// Note: Using GlassButton from GlassEffectCompat.swift for iOS 26 Liquid Glass support

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
            .compatGlassEffect(
                tint: .blue.opacity(0.1),
                cornerRadius: 10,
                fallbackColor: Color(.systemGray6)
            )
            .disabled(!viewModel.isConnected)
            .opacity(viewModel.isConnected ? 1.0 : 0.5)
            
            // Primary Actions Row
            HStack(spacing: 12) {
                // Insert Text Button
                GlassButton(
                    title: "插入",
                    icon: "text.cursor",
                    color: .blue,
                    disabled: !viewModel.isConnected || transcript.isEmpty
                ) {
                    viewModel.sendCommand(.insert(transcript))
                }
                
                // Insert + Enter Button
                GlassButton(
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
                GlassButton(
                    title: "清空",
                    icon: "trash",
                    color: .orange,
                    disabled: !viewModel.isConnected
                ) {
                    viewModel.sendCommand(.clear)
                }
                
                // Enter Key
                GlassButton(
                    title: "回车",
                    icon: "return",
                    color: .purple,
                    disabled: !viewModel.isConnected
                ) {
                    viewModel.sendCommand(.enter)
                }
                
                // Paste
                GlassButton(
                    title: "粘贴",
                    icon: "doc.on.clipboard",
                    color: .teal,
                    disabled: !viewModel.isConnected
                ) {
                    viewModel.sendCommand(.paste)
                }
                
                // Delete
                GlassButton(
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
