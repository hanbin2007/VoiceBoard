//
//  ClickPositionManager.swift
//  VoiceBoard
//
//  Manages click positions per application window (macOS only)
//

#if os(macOS)
import Foundation
import AppKit
import Combine

/// Manages click positions bound to application bundle identifiers
class ClickPositionManager: ObservableObject {
    
    static let shared = ClickPositionManager()
    
    // MARK: - Published Properties
    
    /// Dictionary of bundleID → click position
    @Published private(set) var clickPositions: [String: CGPoint] = [:]
    
    /// Whether click-before-input feature is enabled
    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
        }
    }
    
    /// Whether to use global position (ignore app binding)
    @Published var useGlobalPosition: Bool = false {
        didSet {
            UserDefaults.standard.set(useGlobalPosition, forKey: globalModeKey)
        }
    }
    
    /// Last set position (used when useGlobalPosition is true)
    @Published var lastSetPosition: CGPoint? = nil {
        didSet {
            if let pos = lastSetPosition {
                UserDefaults.standard.set(["x": pos.x, "y": pos.y], forKey: lastPositionKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastPositionKey)
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let positionsKey = "VoiceBoard.ClickPositions"
    private let enabledKey = "VoiceBoard.ClickBeforeInputEnabled"
    private let globalModeKey = "VoiceBoard.UseGlobalClickPosition"
    private let lastPositionKey = "VoiceBoard.LastClickPosition"
    
    // MARK: - Initialization
    
    private init() {
        loadPositions()
        loadLastPosition()
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        useGlobalPosition = UserDefaults.standard.bool(forKey: globalModeKey)
    }
    
    // MARK: - Public Methods
    
    /// Get the frontmost application's bundle identifier
    func getFrontmostAppBundleID() -> String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
    
    /// Get the frontmost application's name
    func getFrontmostAppName() -> String? {
        return NSWorkspace.shared.frontmostApplication?.localizedName
    }
    
    /// Get click position for a specific app
    /// - Parameter bundleID: Application bundle identifier
    /// - Returns: Click position or nil if not set
    func getClickPosition(for bundleID: String) -> CGPoint? {
        return clickPositions[bundleID]
    }
    
    /// Get click position for the current frontmost app (or global position if enabled)
    func getClickPositionForFrontmostApp() -> CGPoint? {
        // If global mode is enabled, use last set position
        if useGlobalPosition {
            return lastSetPosition
        }
        // Otherwise use per-app position
        guard let bundleID = getFrontmostAppBundleID() else { return nil }
        return getClickPosition(for: bundleID)
    }
    
    /// Set click position for a specific app
    /// - Parameters:
    ///   - position: Screen coordinate for clicking
    ///   - bundleID: Application bundle identifier
    func setClickPosition(_ position: CGPoint, for bundleID: String) {
        clickPositions[bundleID] = position
        savePositions()
    }
    
    /// Set click position for the current frontmost app
    /// - Parameter position: Screen coordinate for clicking
    /// - Returns: The bundle ID that was set, or nil if failed
    @discardableResult
    func setClickPositionForFrontmostApp(_ position: CGPoint) -> String? {
        // Always update lastSetPosition for global mode
        lastSetPosition = position
        
        guard let bundleID = getFrontmostAppBundleID() else { return nil }
        setClickPosition(position, for: bundleID)
        return bundleID
    }
    
    /// Remove click position for a specific app
    /// - Parameter bundleID: Application bundle identifier
    func removeClickPosition(for bundleID: String) {
        clickPositions.removeValue(forKey: bundleID)
        savePositions()
    }
    
    /// Clear all saved click positions
    func clearAllPositions() {
        clickPositions.removeAll()
        savePositions()
    }
    
    /// Get application name for a bundle ID
    func getAppName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleID.components(separatedBy: ".").last ?? bundleID
    }
    
    /// Get all saved positions with app names
    func getAllPositionsWithNames() -> [(bundleID: String, appName: String, position: CGPoint)] {
        return clickPositions.map { (bundleID, position) in
            (bundleID: bundleID, appName: getAppName(for: bundleID), position: position)
        }.sorted { $0.appName < $1.appName }
    }
    
    // MARK: - Persistence
    
    private func savePositions() {
        // Convert CGPoint to serializable format
        var serializable: [String: [String: CGFloat]] = [:]
        for (bundleID, point) in clickPositions {
            serializable[bundleID] = ["x": point.x, "y": point.y]
        }
        UserDefaults.standard.set(serializable, forKey: positionsKey)
    }
    
    private func loadPositions() {
        guard let data = UserDefaults.standard.dictionary(forKey: positionsKey) as? [String: [String: CGFloat]] else {
            return
        }
        
        var loaded: [String: CGPoint] = [:]
        for (bundleID, pointDict) in data {
            if let x = pointDict["x"], let y = pointDict["y"] {
                loaded[bundleID] = CGPoint(x: x, y: y)
            }
        }
        clickPositions = loaded
    }
    
    private func loadLastPosition() {
        guard let data = UserDefaults.standard.dictionary(forKey: lastPositionKey) as? [String: CGFloat],
              let x = data["x"],
              let y = data["y"] else {
            return
        }
        lastSetPosition = CGPoint(x: x, y: y)
    }
}
#endif
