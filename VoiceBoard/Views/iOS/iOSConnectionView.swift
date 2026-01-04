//
//  iOSConnectionView.swift
//  VoiceBoard
//
//  iOS connection management sheet view
//

#if os(iOS)
import SwiftUI
import MultipeerConnectivity

/// Connection management view for iOS
struct ConnectionManagementView: View {
    @ObservedObject var viewModel: ConnectionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showLogs = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("我的设备") {
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundStyle(.blue)
                        Text(viewModel.myDeviceName)
                        Spacer()
                        Text(viewModel.connectionState.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("可用设备") {
                    if viewModel.availablePeers.isEmpty {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("搜索中...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(viewModel.availablePeers, id: \.displayName) { peer in
                            Button(action: {
                                viewModel.connectToPeer(peer)
                            }) {
                                HStack {
                                    Image(systemName: "desktopcomputer")
                                        .foregroundStyle(.purple)
                                    Text(peer.displayName)
                                    Spacer()
                                    
                                    if viewModel.connectedPeerName == peer.displayName {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    } else if viewModel.connectionState == .connecting {
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
                        viewModel.restart()
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
                LogsView(viewModel: viewModel)
            }
        }
    }
}
#endif
