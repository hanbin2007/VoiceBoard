//
//  ImageTransferToastManager.swift
//  VoiceBoard
//
//  Manages floating toast window for image transfer progress on macOS
//  Shows progress near the current input cursor position
//

#if os(macOS)
import SwiftUI
import AppKit
import Combine

// MARK: - Image Receive State

/// Represents the current state of image receiving on macOS
enum ImageReceiveState: Equatable {
    case idle
    case receiving(count: Int, progress: Double? = nil)  // Receiving N images, optional progress 0-1
    case processing(current: Int, total: Int)            // Processing image N of total
    case pasting                                         // Writing to clipboard and pasting
    case completed(count: Int)                           // Successfully pasted N images
    case failed(message: String)                         // Failed with error message
    
    var isActive: Bool {
        switch self {
        case .idle:
            return false
        default:
            return true
        }
    }
}

// MARK: - Toast Manager

/// Manages the floating toast window for image transfer progress
@MainActor
final class ImageTransferToastManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ImageTransferToastManager()
    
    // MARK: - Published State
    
    @Published private(set) var currentState: ImageReceiveState = .idle
    
    // MARK: - Private Properties
    
    private var toastWindow: NSPanel?
    private var dismissTask: Task<Void, Never>?
    
    /// Toast window size
    private let toastWidth: CGFloat = 280
    private let toastHeight: CGFloat = 70
    
    /// Margin between toast and anchor point
    private let anchorMargin: CGFloat = 20
    
    /// Screen edge margin
    private let screenEdgeMargin: CGFloat = 10
    
    /// Cached anchor position (to avoid frequent Accessibility API calls)
    private var cachedAnchorPosition: CGPoint?
    private var anchorPositionCacheTime: Date?
    private let cacheValidDuration: TimeInterval = 0.5  // Cache valid for 0.5 seconds
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Show or update toast with new state
    /// - Parameter state: The new state to display
    func show(state: ImageReceiveState) {
        currentState = state
        
        // Create window if needed (position is set only once when created)
        if toastWindow == nil {
            createWindow()
            updateWindowPosition()  // Only update position when first showing
        }
        
        // Handle auto-dismiss for terminal states
        handleAutoDismiss(for: state)
    }
    
    /// Dismiss the toast window
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        
        // Clear cached position
        cachedAnchorPosition = nil
        anchorPositionCacheTime = nil
        
        // Close window directly (animation handled separately)
        if let window = toastWindow {
            // Use weak self to avoid retain cycle
            let windowToClose = window
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                windowToClose.animator().alphaValue = 0
            } completionHandler: {
                Task { @MainActor [weak self] in
                    self?.toastWindow?.close()
                    self?.toastWindow = nil
                }
            }
        }
        
        currentState = .idle
    }
    
    // MARK: - Private Methods
    
    private func createWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: toastWidth, height: toastHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Configure panel appearance
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.alphaValue = 0
        
        // Set SwiftUI content
        let hostingView = NSHostingView(
            rootView: ImageTransferToastView(manager: self)
        )
        panel.contentView = hostingView
        
        toastWindow = panel
        panel.orderFront(nil)
        
        // Animate in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }
    }
    
    private func updateWindowPosition() {
        guard let window = toastWindow else { return }
        
        // Get anchor point (caret position or mouse position as fallback)
        let anchorPoint = getCaretPosition() ?? NSEvent.mouseLocation
        
        // Get the screen containing the anchor point
        let screen = NSScreen.screens.first { 
            NSMouseInRect(anchorPoint, $0.frame, false) 
        } ?? NSScreen.main ?? NSScreen.screens.first!
        
        // Calculate smart position
        let position = calculateSmartPosition(
            anchor: anchorPoint,
            toastSize: window.frame.size,
            screen: screen
        )
        
        window.setFrameOrigin(position)
    }
    
    /// Calculate toast position with smart adjustment for screen edges
    private func calculateSmartPosition(
        anchor: CGPoint,
        toastSize: CGSize,
        screen: NSScreen
    ) -> CGPoint {
        let screenFrame = screen.visibleFrame
        
        // Calculate space above and below anchor
        let spaceAbove = screenFrame.maxY - anchor.y
        let spaceBelow = anchor.y - screenFrame.minY
        let requiredSpace = toastSize.height + anchorMargin
        
        var x = anchor.x - toastSize.width / 2
        var y: CGFloat
        
        // Decide whether to show above or below
        if spaceAbove >= requiredSpace {
            // Show above anchor
            y = anchor.y + anchorMargin
        } else if spaceBelow >= requiredSpace {
            // Show below anchor
            y = anchor.y - toastSize.height - anchorMargin
        } else {
            // Not enough space either way, prefer above but clamp to screen
            y = anchor.y + anchorMargin
        }
        
        // Clamp X to screen bounds
        x = max(screenFrame.minX + screenEdgeMargin, x)
        x = min(screenFrame.maxX - toastSize.width - screenEdgeMargin, x)
        
        // Clamp Y to screen bounds
        y = max(screenFrame.minY + screenEdgeMargin, y)
        y = min(screenFrame.maxY - toastSize.height - screenEdgeMargin, y)
        
        return CGPoint(x: x, y: y)
    }
    
    /// Get current input caret position using Accessibility API
    /// Returns nil if caret position cannot be determined (will fallback to mouse position)
    private func getCaretPosition() -> CGPoint? {
        // Use cached position if still valid (to reduce Accessibility API calls)
        if let cached = cachedAnchorPosition,
           let cacheTime = anchorPositionCacheTime,
           Date().timeIntervalSince(cacheTime) < cacheValidDuration {
            return cached
        }
        
        // Get system-wide accessibility element
        let systemWide = AXUIElementCreateSystemWide()
        
        // Get focused element
        var focusedElementRef: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )
        
        guard focusResult == .success, let focusedElement = focusedElementRef else {
            return nil
        }
        
        // Safely cast to AXUIElement
        let element = focusedElement as! AXUIElement
        
        // Get selected text range (caret position)
        var selectedRangeRef: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeRef
        )
        
        guard rangeResult == .success, let selectedRange = selectedRangeRef else {
            return nil
        }
        
        // Check if selectedRange is a valid AXValue
        guard CFGetTypeID(selectedRange as CFTypeRef) == AXValueGetTypeID() else {
            return nil
        }
        
        // Get bounds for the selected range (caret bounds)
        var caretBoundsRef: AnyObject?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            selectedRange,
            &caretBoundsRef
        )
        
        guard boundsResult == .success, let caretBounds = caretBoundsRef else {
            return nil
        }
        
        // Check if caretBounds is a valid AXValue of type CGRect
        guard CFGetTypeID(caretBounds as CFTypeRef) == AXValueGetTypeID() else {
            return nil
        }
        
        let axValue = caretBounds as! AXValue
        
        // Verify it's a CGRect type
        guard AXValueGetType(axValue) == .cgRect else {
            return nil
        }
        
        // Extract CGRect from AXValue
        var rect = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &rect) else {
            return nil
        }
        
        // Validate rect values (avoid bad ranges)
        guard rect.width >= 0, rect.height >= 0,
              rect.origin.x.isFinite, rect.origin.y.isFinite,
              rect.size.width.isFinite, rect.size.height.isFinite else {
            return nil
        }
        
        // Convert from screen coordinates (top-left origin) to NSScreen coordinates (bottom-left origin)
        guard let primaryScreen = NSScreen.screens.first else {
            return nil
        }
        
        let primaryHeight = primaryScreen.frame.height
        
        // Return top-center of caret rect, converted to NSScreen coordinates
        let screenY = primaryHeight - rect.minY
        let position = CGPoint(x: rect.midX, y: screenY)
        
        // Cache the position
        cachedAnchorPosition = position
        anchorPositionCacheTime = Date()
        
        return position
    }
    
    private func handleAutoDismiss(for state: ImageReceiveState) {
        dismissTask?.cancel()
        dismissTask = nil
        
        switch state {
        case .completed:
            // Auto dismiss after 2 seconds
            dismissTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.dismiss()
            }
            
        case .failed:
            // Auto dismiss after 3 seconds
            dismissTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.dismiss()
            }
            
        default:
            break
        }
    }
}
#endif
