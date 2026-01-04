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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Connection Status Card (tappable)
                connectionCard
                    .onTapGesture {
                        showConnectionSheet = true
                    }
                
                Divider()
                
                // Transcript Display
                transcriptView
                
                Spacer()
                
                // Record Button
                recordButton
            }
            .padding()
            .navigationTitle("VoiceBoard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showConnectionSheet = true }) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                }
            }
            .sheet(isPresented: $showConnectionSheet) {
                ConnectionManagementView(multipeerManager: multipeerManager)
            }
            .onChange(of: speechRecognizer.transcript) { _, newValue in
                multipeerManager.sendText(newValue)
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
                    
                    if !multipeerManager.availablePeers.isEmpty {
                        Text("发现 \(multipeerManager.availablePeers.count) 台设备")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
            Text("识别结果")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            ScrollView {
                Text(speechRecognizer.transcript.isEmpty ? "点击下方按钮开始说话..." : speechRecognizer.transcript)
                    .font(.title3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(speechRecognizer.transcript.isEmpty ? .secondary : .primary)
            }
            .frame(maxHeight: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var recordButton: some View {
        VStack(spacing: 12) {
            Button(action: {
                speechRecognizer.toggleRecording()
            }) {
                ZStack {
                    Circle()
                        .fill(speechRecognizer.isRecording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                        .shadow(radius: 4)
                    
                    Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                }
            }
            .disabled(!speechRecognizer.isAuthorized || !multipeerManager.isConnected)
            .opacity(multipeerManager.isConnected ? 1.0 : 0.5)
            .scaleEffect(speechRecognizer.isRecording ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: speechRecognizer.isRecording)
            
            if !multipeerManager.isConnected {
                Text("请先连接Mac")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text(speechRecognizer.isRecording ? "点击停止" : "点击开始录音")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let error = speechRecognizer.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.bottom, 32)
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
                // My Device Section
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
                
                // Available Devices Section
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
                
                // Actions Section
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
                
                // Tips Section
                Section("提示") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 确保iPhone和Mac在同一WiFi网络")
                        Text("• Mac上也需要运行VoiceBoard应用")
                        Text("• 如果搜不到设备，尝试重新搜索")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                if multipeerManager.logMessages.isEmpty {
                    Text("暂无日志")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(multipeerManager.logMessages, id: \.self) { log in
                        Text(log)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
            .navigationTitle("连接日志")
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
            // Header
            Text("连接管理")
                .font(.headline)
            
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
            
            // Connection Status
            GroupBox("状态") {
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
            
            // Actions
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
                    .frame(height: 150)
                }
            }
            
            Spacer()
            
            // Tips
            VStack(alignment: .leading, spacing: 4) {
                Text("提示:")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("• iPhone和Mac需在同一WiFi")
                Text("• iPhone运行VoiceBoard并连接")
                Text("• 连接后说话，文字将同步到此处")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    private var receivedTextPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
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
            
            // Received Text
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
        }
        .padding()
    }
}
#endif

#Preview {
    ContentView()
}
