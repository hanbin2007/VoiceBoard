//
//  MultipeerManager.swift
//  VoiceBoard
//
//  Handles device discovery and communication via MultipeerConnectivity
//

import Foundation
import MultipeerConnectivity
import Combine

/// Connection state for UI display
enum ConnectionState: String {
    case idle = "未启动"
    case browsing = "搜索中"
    case connecting = "连接中"
    case connected = "已连接"
    case failed = "连接失败"
}

/// Manages peer-to-peer connectivity between iOS and Mac devices
@MainActor
class MultipeerManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// The text received from peer device
    @Published var receivedText: String = ""
    
    /// Current connection state
    @Published var connectionState: ConnectionState = .idle
    
    /// Whether connected to a peer
    @Published var isConnected: Bool = false
    
    /// Connected peer's display name
    @Published var connectedPeerName: String = ""
    
    /// Available peers for connection
    @Published var availablePeers: [MCPeerID] = []
    
    /// Log messages for debugging
    @Published var logMessages: [String] = []
    
    /// My device name
    @Published var myDeviceName: String = ""
    
    #if os(macOS)
    /// Accessibility permission status
    @Published var hasAccessibilityPermission: Bool = false
    
    /// Whether auto-reconnect is enabled
    @Published var autoReconnectEnabled: Bool = true
    
    /// Whether currently attempting to auto-reconnect
    @Published var isAutoReconnecting: Bool = false
    #endif
    
    // MARK: - Private Properties
    
    // Service type must be 1-15 characters, lowercase, letters/numbers/hyphens only
    private let serviceType = "vboard"
    private let myPeerID: MCPeerID
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    
    #if os(iOS)
    private let deviceRole = "ios"
    #else
    private let deviceRole = "mac"
    private var reconnectTask: Task<Void, Never>?
    private let reconnectDelay: TimeInterval = 3.0
    private let lastConnectedPeerKey = "LastConnectedPeerName"
    #endif
    
    // MARK: - Initialization
    
    override init() {
        #if os(iOS)
        let deviceName = UIDevice.current.name
        myPeerID = MCPeerID(displayName: deviceName)
        #else
        let deviceName = Host.current().localizedName ?? "Mac"
        myPeerID = MCPeerID(displayName: deviceName)
        #endif
        
        super.init()
        
        myDeviceName = myPeerID.displayName
        log("初始化设备: \(myDeviceName)")
        log("角色: \(deviceRole)")
        
        #if os(macOS)
        checkAccessibilityPermission()
        #endif
        
        setupSession()
        startServices()
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"
        logMessages.append(logEntry)
        print("MultipeerManager: \(message)")
        
        // Keep only last 50 messages
        if logMessages.count > 50 {
            logMessages.removeFirst()
        }
    }
    
    // MARK: - Setup
    
    private func setupSession() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        log("会话已创建")
    }
    
    private func startServices() {
        // Start advertising (so others can find us)
        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: ["role": deviceRole],
            serviceType: serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        log("开始广播服务 (serviceType: \(serviceType))")
        
        // Start browsing (to find others)
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        log("开始搜索设备")
        
        connectionState = .browsing
    }
    
    // MARK: - Public Methods
    
    /// Restart all services
    func restart() {
        log("重启服务...")
        
        // Stop existing services
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        
        availablePeers.removeAll()
        isConnected = false
        connectedPeerName = ""
        connectionState = .idle
        
        // Recreate session and restart
        setupSession()
        startServices()
    }
    
    /// Send text to connected peer (legacy, for preview)
    func sendText(_ text: String) {
        sendCommand(.text(text))
    }
    
    /// Send a command to connected peer
    func sendCommand(_ command: VoiceBoardCommand) {
        guard !session.connectedPeers.isEmpty else { return }
        
        if let data = command.encode() {
            do {
                try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            } catch {
                log("发送命令失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// Connect to a specific peer
    func connectToPeer(_ peerID: MCPeerID) {
        log("尝试连接: \(peerID.displayName)")
        connectionState = .connecting
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }
    
    /// Clear logs
    func clearLogs() {
        logMessages.removeAll()
    }
    
    #if os(macOS)
    // MARK: - Auto Reconnection (macOS only)
    
    /// The name of the last connected peer
    var lastConnectedPeerName: String? {
        get { UserDefaults.standard.string(forKey: lastConnectedPeerKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastConnectedPeerKey) }
    }
    
    /// Save the peer info when successfully connected
    private func saveLastConnectedPeer(_ peerID: MCPeerID) {
        lastConnectedPeerName = peerID.displayName
        log("💾 已保存最后连接的设备: \(peerID.displayName)")
    }
    
    /// Cancel any ongoing auto-reconnect attempts
    func cancelAutoReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        isAutoReconnecting = false
        log("🛑 已取消自动重连")
    }
    
    /// Toggle auto-reconnect feature
    func toggleAutoReconnect(_ enabled: Bool) {
        autoReconnectEnabled = enabled
        if !enabled {
            cancelAutoReconnect()
        }
        log("自动重连: \(enabled ? "已启用" : "已禁用")")
    }
    
    /// Start auto-reconnect process
    private func startAutoReconnect(disconnectedPeerName: String) {
        guard autoReconnectEnabled else {
            log("自动重连已禁用，跳过")
            return
        }
        
        guard !isConnected else {
            log("已连接，跳过自动重连")
            return
        }
        
        // Cancel any existing reconnect task
        reconnectTask?.cancel()
        isAutoReconnecting = true
        
        log("🔄 开始自动重连: \(disconnectedPeerName)")
        
        reconnectTask = Task { [weak self] in
            guard let self = self else { return }
            var attemptCount = 0
            
            while !Task.isCancelled {
                attemptCount += 1
                
                await MainActor.run {
                    self.log("尝试重连 (第\(attemptCount)次)...")
                }
                
                // Check if the peer is in available peers list
                let foundPeer = await MainActor.run { () -> MCPeerID? in
                    return self.availablePeers.first { $0.displayName == disconnectedPeerName }
                }
                
                if let peerID = foundPeer {
                    await MainActor.run {
                        self.log("✅ 找到设备，尝试连接: \(peerID.displayName)")
                        self.connectToPeer(peerID)
                    }
                    
                    // Wait a bit and check if connected
                    try? await Task.sleep(nanoseconds: UInt64(3 * 1_000_000_000))
                    
                    let connected = await self.isConnected
                    if connected {
                        await MainActor.run {
                            self.log("✅ 自动重连成功")
                            self.isAutoReconnecting = false
                        }
                        return
                    }
                } else {
                    await MainActor.run {
                        self.log("⏳ 等待设备出现: \(disconnectedPeerName)")
                    }
                }
                
                // Wait before next attempt
                try? await Task.sleep(nanoseconds: UInt64(self.reconnectDelay * 1_000_000_000))
                
                // Check if we got connected during the wait
                let connected = await self.isConnected
                if connected {
                    await MainActor.run {
                        self.isAutoReconnecting = false
                    }
                    return
                }
            }
            
            // Only reaches here if task was cancelled
            await MainActor.run {
                self.log("🛑 自动重连已停止")
                self.isAutoReconnecting = false
            }
        }
    }
    #endif
    
    // MARK: - macOS Accessibility
    
    #if os(macOS)
    func checkAccessibilityPermission() {
        hasAccessibilityPermission = KeyboardSimulator.shared.checkAccessibilityPermission()
        log("辅助功能权限: \(hasAccessibilityPermission ? "已授权" : "未授权")")
    }
    
    func requestAccessibilityPermission() {
        KeyboardSimulator.shared.requestAccessibilityPermission()
        // Check again after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }
    
    private func handleCommand(_ command: VoiceBoardCommand) {
        log("收到命令: \(command)")
        
        switch command {
        case .text(let text):
            receivedText = text
            
        case .insert(let text):
            if hasAccessibilityPermission {
                DispatchQueue.global(qos: .userInteractive).async {
                    KeyboardSimulator.shared.typeText(text)
                }
            } else {
                log("⚠️ 未授权辅助功能")
            }
            
        case .insertAndEnter(let text):
            if hasAccessibilityPermission {
                DispatchQueue.global(qos: .userInteractive).async {
                    KeyboardSimulator.shared.insertTextAndEnter(text)
                }
            }
            
        case .enter:
            if hasAccessibilityPermission {
                DispatchQueue.global(qos: .userInteractive).async {
                    KeyboardSimulator.shared.pressEnter()
                }
            }
            
        case .clear:
            if hasAccessibilityPermission {
                DispatchQueue.global(qos: .userInteractive).async {
                    KeyboardSimulator.shared.clearInputField()
                }
            }
            
        case .paste:
            if hasAccessibilityPermission {
                DispatchQueue.global(qos: .userInteractive).async {
                    KeyboardSimulator.shared.paste()
                }
            }
            
        case .delete:
            if hasAccessibilityPermission {
                DispatchQueue.global(qos: .userInteractive).async {
                    KeyboardSimulator.shared.pressDelete()
                }
            }
            
        case .selectAll:
            if hasAccessibilityPermission {
                DispatchQueue.global(qos: .userInteractive).async {
                    KeyboardSimulator.shared.selectAll()
                }
            }
            
        case .copy:
            if hasAccessibilityPermission {
                DispatchQueue.global(qos: .userInteractive).async {
                    KeyboardSimulator.shared.copy()
                }
            }
            
        case .cut:
            if hasAccessibilityPermission {
                DispatchQueue.global(qos: .userInteractive).async {
                    KeyboardSimulator.shared.cut()
                }
            }
        }
    }
    #endif
}

// MARK: - MCSessionDelegate

extension MultipeerManager: MCSessionDelegate {
    
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.isConnected = true
                self.connectedPeerName = peerID.displayName
                self.connectionState = .connected
                self.log("✅ 已连接: \(peerID.displayName)")
                #if os(macOS)
                // Cancel any reconnect attempts and save the connected peer
                self.cancelAutoReconnect()
                self.saveLastConnectedPeer(peerID)
                #endif
            case .notConnected:
                let disconnectedPeerName = peerID.displayName
                self.isConnected = false
                self.connectedPeerName = ""
                self.connectionState = .browsing
                self.log("❌ 断开连接: \(disconnectedPeerName)")
                #if os(macOS)
                // Start auto-reconnect on Mac
                self.startAutoReconnect(disconnectedPeerName: disconnectedPeerName)
                #endif
            case .connecting:
                self.connectionState = .connecting
                self.log("🔄 正在连接: \(peerID.displayName)")
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            // Try to decode as command first
            if let command = VoiceBoardCommand.decode(from: data) {
                #if os(macOS)
                self.handleCommand(command)
                #endif
            } else if let text = String(data: data, encoding: .utf8) {
                // Fallback to plain text
                self.receivedText = text
                self.log("收到文字: \(text.prefix(50))...")
            }
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            self.log("📨 收到连接邀请: \(peerID.displayName)")
            // Auto-accept invitations
            invitationHandler(true, self.session)
            self.log("已接受邀请")
        }
    }
    
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            self.log("⚠️ 广播失败: \(error.localizedDescription)")
            self.connectionState = .failed
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        Task { @MainActor in
            let role = info?["role"] ?? "unknown"
            self.log("🔍 发现设备: \(peerID.displayName) (角色: \(role))")
            
            // Add all discovered peers (both roles can connect to each other)
            if !self.availablePeers.contains(peerID) {
                self.availablePeers.append(peerID)
            }
        }
    }
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.log("设备离线: \(peerID.displayName)")
            self.availablePeers.removeAll { $0 == peerID }
        }
    }
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            self.log("⚠️ 搜索失败: \(error.localizedDescription)")
            self.connectionState = .failed
        }
    }
}
