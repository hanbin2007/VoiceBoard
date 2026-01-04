//
//  MenuBarView.swift
//  VoiceBoard
//
//  Menu bar extra view for macOS with connection management
//

#if os(macOS)
import SwiftUI

/// Menu bar dropdown view with connection management
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: ConnectionViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("VoiceBoard")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            Divider()
            
            // Status Section
            VStack(alignment: .leading, spacing: 4) {
                // My Device
                HStack(spacing: 6) {
                    Image(systemName: "desktopcomputer")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(viewModel.myDeviceName)
                        .lineLimit(1)
                }
                .font(.caption)
                
                // Connection Status
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                        .frame(width: 16)
                    Text(viewModel.connectionState.rawValue)
                    
                    if viewModel.isConnected {
                        Text("→ \(viewModel.connectedPeerName)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Discovered Devices Section
            VStack(alignment: .leading, spacing: 0) {
                Text("发现的设备")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                
                if viewModel.availablePeers.isEmpty {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 16, height: 16)
                        Text("搜索中...")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                } else {
                    ForEach(viewModel.availablePeers, id: \.displayName) { peer in
                        DeviceRowButton(
                            peer: peer,
                            isConnected: viewModel.connectedPeerName == peer.displayName,
                            onConnect: {
                                viewModel.connectToPeer(peer)
                            }
                        )
                    }
                }
            }
            .padding(.bottom, 8)
            
            Divider()
            
            // Actions
            VStack(spacing: 0) {
                MenuButton(
                    title: "重新搜索",
                    icon: "arrow.clockwise",
                    action: { viewModel.restart() }
                )
                
                MenuButton(
                    title: "显示主窗口",
                    icon: "macwindow",
                    action: { appState.showWindow() }
                )
            }
            
            Divider()
            
            MenuButton(
                title: "退出",
                icon: "power",
                action: { NSApplication.shared.terminate(nil) }
            )
        }
        .frame(width: 220)
    }
}

// MARK: - Device Row Button

private struct DeviceRowButton: View {
    let peer: MCPeerID
    let isConnected: Bool
    let onConnect: () -> Void
    
    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: 8) {
                Image(systemName: "iphone")
                    .foregroundStyle(.blue)
                    .frame(width: 16)
                
                Text(peer.displayName)
                    .lineLimit(1)
                
                Spacer()
                
                if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("连接")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isConnected)
    }
}

// MARK: - Menu Button

private struct MenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(title)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// Need to import MultipeerConnectivity for MCPeerID
import MultipeerConnectivity
#endif
