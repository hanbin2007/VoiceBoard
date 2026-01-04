//
//  macOSContentView.swift
//  VoiceBoard
//
//  Main content view for macOS
//

#if os(macOS)
import SwiftUI
import MultipeerConnectivity

/// Main macOS content view with split panel layout
struct macOSContentView: View {
    @ObservedObject var viewModel: ConnectionViewModel
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
    
    // MARK: - Connection Panel
    
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
                    Text(viewModel.myDeviceName)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            
            // Accessibility Status
            GroupBox("辅助功能") {
                HStack {
                    Circle()
                        .fill(viewModel.hasAccessibilityPermission ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(viewModel.hasAccessibilityPermission ? "已授权" : "未授权")
                    Spacer()
                    if !viewModel.hasAccessibilityPermission {
                        Button("授权") {
                            viewModel.requestAccessibilityPermission()
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
                        .fill(viewModel.isConnected ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(viewModel.connectionState.rawValue)
                    Spacer()
                    
                    if viewModel.isAutoReconnecting {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("重连中...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Available Devices
            GroupBox("发现的设备") {
                if viewModel.availablePeers.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("搜索中...")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.availablePeers, id: \.displayName) { peer in
                            HStack {
                                Image(systemName: "iphone")
                                    .foregroundStyle(.blue)
                                Text(peer.displayName)
                                    .lineLimit(1)
                                Spacer()
                                
                                if viewModel.connectedPeerName == peer.displayName {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Button("连接") {
                                        viewModel.connectToPeer(peer)
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
                    viewModel.restart()
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
                            ForEach(viewModel.logMessages.suffix(20), id: \.self) { log in
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
    
    // MARK: - Received Text Panel
    
    private var receivedTextPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("VoiceBoard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                if viewModel.isConnected {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text(viewModel.connectedPeerName)
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
                    Text(viewModel.receivedText.isEmpty ? "等待语音输入..." : viewModel.receivedText)
                        .font(.system(size: 28))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(viewModel.receivedText.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(Color(.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Status hint
            if !viewModel.hasAccessibilityPermission {
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
