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
    
    /// Send text to connected peer
    func sendText(_ text: String) {
        guard !session.connectedPeers.isEmpty else {
            return
        }
        
        if let data = text.data(using: .utf8) {
            do {
                try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            } catch {
                log("发送失败: \(error.localizedDescription)")
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
            case .notConnected:
                self.isConnected = false
                self.connectedPeerName = ""
                self.connectionState = .browsing
                self.log("❌ 断开连接: \(peerID.displayName)")
            case .connecting:
                self.connectionState = .connecting
                self.log("🔄 正在连接: \(peerID.displayName)")
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let text = String(data: data, encoding: .utf8) {
            Task { @MainActor in
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
