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
    @ObservedObject private var transferManager = TransferManager.shared
    @Binding var showConnectionSheet: Bool
    @FocusState private var isTextEditorFocused: Bool
    @State private var showSettingsSheet: Bool = false
    @State private var showPhotoPickerSheet: Bool = false
    @State private var showHistorySheet: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
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
                        HStack(spacing: 16) {
                            Button(action: { showHistorySheet = true }) {
                                Image(systemName: "clock.arrow.circlepath")
                            }
                            Button(action: { showPhotoPickerSheet = true }) {
                                Image(systemName: "camera.fill")
                            }
                            Button(action: { showConnectionSheet = true }) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                            }
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
                .sheet(isPresented: $showPhotoPickerSheet) {
                    PhotoPickerView(viewModel: PhotoPickerViewModel(connectionViewModel: viewModel))
                }
                .sheet(isPresented: $showHistorySheet) {
                    MessageHistoryView(viewModel: viewModel)
                }
                .onAppear {
                    // Apply idle timer setting from preferences
                    iOSSettings.shared.updateIdleTimer()
                }
            }
            
            // Floating transfer progress overlay
            if transferManager.transferState.isInProgress {
                TransferProgressFloatingView(state: transferManager.transferState)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(duration: 0.3), value: transferManager.transferState.isInProgress)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .compatGlassCapsule(tint: viewModel.isConnected ? .green.opacity(0.1) : .orange.opacity(0.1))
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
                .compatGlassEffect(
                    tint: .gray.opacity(0.1),
                    cornerRadius: 12,
                    fallbackColor: Color(.systemGray6)
                )
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
