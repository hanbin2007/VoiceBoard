//
//  ContentView.swift
//  VoiceBoard
//
//  Main UI for iOS (voice input) and macOS (text display)
//

import SwiftUI
import MultipeerConnectivity

struct ContentView: View {
    @StateObject private var multipeerManager = MultipeerManager()
    
    #if os(iOS)
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var showConnectionSheet = false
    #endif
    
    var body: some View {
        #if os(iOS)
        iOSContentView(
            multipeerManager: multipeerManager,
            speechRecognizer: speechRecognizer,
            showConnectionSheet: $showConnectionSheet
        )
        #else
        macOSContentView(multipeerManager: multipeerManager)
        #endif
    }
}

// MARK: - iOS View

#if os(iOS)
struct iOSContentView: View {
    @ObservedObject var multipeerManager: MultipeerManager
    @ObservedObject var speechRecognizer: SpeechRecognizer
    @Binding var showConnectionSheet: Bool
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            // Connection Status Card (tappable)
                            connectionCard
                                .onTapGesture {
                                    showConnectionSheet = true
                                }
                            
                            // Transcript Display (fixed height when keyboard is shown)
                            transcriptView
                                .frame(minHeight: isTextEditorFocused ? 120 : max(geometry.size.height * 0.35, 150))
                            
                            // Control Buttons Panel
                            controlButtonsPanel
                            
                            // Record Button
                            recordButton
                                .id("recordButton")
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: isTextEditorFocused) { _, focused in
                        if focused {
                            withAnimation {
                                scrollProxy.scrollTo("recordButton", anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .navigationTitle("VoiceBoard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                ConnectionManagementView(multipeerManager: multipeerManager)
            }
            .onChange(of: speechRecognizer.transcript) { _, newValue in
                multipeerManager.sendCommand(.text(newValue))
            }
        }
    }
    
    private var connectionCard: some View {
        HStack {
            Circle()
                .fill(multipeerManager.isConnected ? Color.green : Color.orange)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                if multipeerManager.isConnected {
                    Text("已连接: \(multipeerManager.connectedPeerName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else {
                    Text(multipeerManager.connectionState.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("识别结果")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text("(可编辑)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                if !speechRecognizer.transcript.isEmpty {
                    Button(action: {
                        speechRecognizer.transcript = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            TextEditor(text: $speechRecognizer.transcript)
                .font(.title3)
                .scrollContentBackground(.hidden)
                .padding(8)
                .focused($isTextEditorFocused)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    Group {
                        if speechRecognizer.transcript.isEmpty {
                            Text("点击下方按钮开始说话，或直接输入文字...")
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
    
    // MARK: - Control Buttons Panel
    
    private var controlButtonsPanel: some View {
        VStack(spacing: 12) {
            // Primary Actions Row
            HStack(spacing: 12) {
                // Insert Text Button
                CommandButton(
                    title: "插入",
                    icon: "text.cursor",
                    color: .blue,
                    disabled: !multipeerManager.isConnected || speechRecognizer.transcript.isEmpty
                ) {
                    multipeerManager.sendCommand(.insert(speechRecognizer.transcript))
                }
                
                // Insert + Enter Button
                CommandButton(
                    title: "发送",
                    icon: "paperplane.fill",
                    color: .green,
                    disabled: !multipeerManager.isConnected || speechRecognizer.transcript.isEmpty
                ) {
                    multipeerManager.sendCommand(.insertAndEnter(speechRecognizer.transcript))
                    speechRecognizer.transcript = ""
                }
            }
            
            // Secondary Actions Row
            HStack(spacing: 12) {
                // Clear Input Field
                CommandButton(
                    title: "清空",
                    icon: "trash",
                    color: .orange,
                    disabled: !multipeerManager.isConnected
                ) {
                    multipeerManager.sendCommand(.clear)
                }
                
                // Enter Key
                CommandButton(
                    title: "回车",
                    icon: "return",
                    color: .purple,
                    disabled: !multipeerManager.isConnected
                ) {
                    multipeerManager.sendCommand(.enter)
                }
                
                // Paste
                CommandButton(
                    title: "粘贴",
                    icon: "doc.on.clipboard",
                    color: .teal,
                    disabled: !multipeerManager.isConnected
                ) {
                    multipeerManager.sendCommand(.paste)
                }
                
                // Delete
                CommandButton(
                    title: "删除",
                    icon: "delete.left",
                    color: .red,
                    disabled: !multipeerManager.isConnected
                ) {
                    multipeerManager.sendCommand(.delete)
                }
            }
        }
    }
    
    private var recordButton: some View {
        VStack(spacing: 8) {
            Button(action: {
                speechRecognizer.toggleRecording()
            }) {
                ZStack {
                    Circle()
                        .fill(speechRecognizer.isRecording ? Color.red : Color.blue)
                        .frame(width: 70, height: 70)
                        .shadow(radius: 4)
                    
                    Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                }
            }
            .disabled(!speechRecognizer.isAuthorized)
            .scaleEffect(speechRecognizer.isRecording ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: speechRecognizer.isRecording)
            
            Text(speechRecognizer.isRecording ? "录音中..." : "点击录音")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let error = speechRecognizer.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.bottom, 16)
    }
}

// MARK: - Command Button Component

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

// MARK: - Connection Management View (iOS)

struct ConnectionManagementView: View {
    @ObservedObject var multipeerManager: MultipeerManager
    @Environment(\.dismiss) private var dismiss
    @State private var showLogs = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("我的设备") {
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundStyle(.blue)
                        Text(multipeerManager.myDeviceName)
                        Spacer()
                        Text(multipeerManager.connectionState.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("可用设备") {
                    if multipeerManager.availablePeers.isEmpty {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("搜索中...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(multipeerManager.availablePeers, id: \.displayName) { peer in
                            Button(action: {
                                multipeerManager.connectToPeer(peer)
                            }) {
                                HStack {
                                    Image(systemName: "desktopcomputer")
                                        .foregroundStyle(.purple)
                                    Text(peer.displayName)
                                    Spacer()
                                    
                                    if multipeerManager.connectedPeerName == peer.displayName {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    } else if multipeerManager.connectionState == .connecting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("点击连接")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        multipeerManager.restart()
                    }) {
                        Label("重新搜索", systemImage: "arrow.clockwise")
                    }
                    
                    Button(action: {
                        showLogs = true
                    }) {
                        Label("查看日志", systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle("连接管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showLogs) {
                LogsView(multipeerManager: multipeerManager)
            }
        }
    }
}

// MARK: - Logs View (iOS)

struct LogsView: View {
    @ObservedObject var multipeerManager: MultipeerManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(multipeerManager.logMessages, id: \.self) { log in
                    Text(log)
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .navigationTitle("日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("清除") {
                        multipeerManager.clearLogs()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
#endif

// MARK: - macOS View

#if os(macOS)
struct macOSContentView: View {
    @ObservedObject var multipeerManager: MultipeerManager
    @EnvironmentObject var appState: AppState
    @State private var showLogs = false
    
    var body: some View {
        HSplitView {
            // Left: Connection Panel
            connectionPanel
                .frame(minWidth: 250, maxWidth: 300)
            
            // Right: Received Text
            receivedTextPanel
        }
        .frame(minWidth: 700, minHeight: 500)
    }
    
    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("连接管理")
                    .font(.headline)
                Spacer()
                Button(action: {
                    appState.hideWindow()
                }) {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("隐藏到菜单栏")
            }
            
            // My Device
            GroupBox("我的设备") {
                HStack {
                    Image(systemName: "desktopcomputer")
                        .foregroundStyle(.purple)
                    Text(multipeerManager.myDeviceName)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            
            // Accessibility Status
            GroupBox("辅助功能") {
                HStack {
                    Circle()
                        .fill(multipeerManager.hasAccessibilityPermission ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(multipeerManager.hasAccessibilityPermission ? "已授权" : "未授权")
                    Spacer()
                    if !multipeerManager.hasAccessibilityPermission {
                        Button("授权") {
                            multipeerManager.requestAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Connection Status
            GroupBox("连接状态") {
                HStack {
                    Circle()
                        .fill(multipeerManager.isConnected ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(multipeerManager.connectionState.rawValue)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            
            // Available Devices
            GroupBox("发现的设备") {
                if multipeerManager.availablePeers.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("搜索中...")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(multipeerManager.availablePeers, id: \.displayName) { peer in
                            HStack {
                                Image(systemName: "iphone")
                                    .foregroundStyle(.blue)
                                Text(peer.displayName)
                                    .lineLimit(1)
                                Spacer()
                                
                                if multipeerManager.connectedPeerName == peer.displayName {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Button("连接") {
                                        multipeerManager.connectToPeer(peer)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            
            HStack {
                Button(action: {
                    multipeerManager.restart()
                }) {
                    Label("重新搜索", systemImage: "arrow.clockwise")
                }
                
                Spacer()
                
                Button(action: {
                    showLogs.toggle()
                }) {
                    Label("日志", systemImage: "doc.text")
                }
            }
            
            if showLogs {
                GroupBox("日志") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(multipeerManager.logMessages.suffix(20), id: \.self) { log in
                                Text(log)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(height: 120)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var receivedTextPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("VoiceBoard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                if multipeerManager.isConnected {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text(multipeerManager.connectedPeerName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("接收的文字")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                ScrollView {
                    Text(multipeerManager.receivedText.isEmpty ? "等待语音输入..." : multipeerManager.receivedText)
                        .font(.system(size: 28))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(multipeerManager.receivedText.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(Color(.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Status hint
            if !multipeerManager.hasAccessibilityPermission {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("请在左侧面板授权辅助功能以启用键盘模拟")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
    }
}
#endif

#Preview {
    ContentView()
}
