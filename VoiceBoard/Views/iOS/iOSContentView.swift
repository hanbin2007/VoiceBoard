//
//  iOSContentView.swift
//  VoiceBoard
//
//  Main content view for iOS
//

#if os(iOS)
import SwiftUI

/// Main iOS content view
struct iOSContentView: View {
    @ObservedObject var viewModel: ConnectionViewModel
    @Binding var showConnectionSheet: Bool
    @FocusState private var isTextEditorFocused: Bool
    @State private var showSettingsSheet: Bool = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            // Connection Status (small text)
                            connectionStatusText
                            
                            // Transcript Display
                            transcriptView
                                .frame(minHeight: isTextEditorFocused ? 120 : max(geometry.size.height * 0.35, 150))
                            
                            // Control Buttons Panel
                            ControlButtonsPanel(
                                viewModel: viewModel,
                                transcript: $viewModel.transcript
                            )
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle("VoiceBoard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showSettingsSheet = true }) {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showConnectionSheet = true }) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("完成") {
                            isTextEditorFocused = false
                        }
                    }
                }
            }
            .sheet(isPresented: $showConnectionSheet) {
                ConnectionManagementView(viewModel: viewModel)
            }
            .sheet(isPresented: $showSettingsSheet) {
                iOSSettingsView()
            }
            .onAppear {
                // Apply idle timer setting from preferences
                iOSSettings.shared.updateIdleTimer()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var connectionStatusText: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            
            if viewModel.isConnected {
                Text("已连接: \(viewModel.connectedPeerName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(viewModel.connectionState.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("输入内容")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !viewModel.transcript.isEmpty {
                    Button(action: {
                        viewModel.transcript = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            TextEditor(text: $viewModel.transcript)
                .font(.title3)
                .scrollContentBackground(.hidden)
                .padding(8)
                .focused($isTextEditorFocused)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    Group {
                        if viewModel.transcript.isEmpty {
                            Text("输入文字或使用系统键盘语音输入...")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .padding(16)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
        }
    }
}
#endif
