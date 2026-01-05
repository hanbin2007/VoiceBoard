//
//  ClickSimulator.swift
//  VoiceBoard
//
//  Simulates mouse clicks using CGEvent (macOS only)
//

#if os(macOS)
import Foundation
import AppKit

/// Simulates mouse clicks on macOS using CGEvent
class ClickSimulator {
    
    static let shared = ClickSimulator()
    
    private init() {}
    
    // MARK: - Mouse Click Simulation
    
    /// Simulate a left mouse click at the specified screen coordinate
    /// - Parameter point: Screen coordinate (origin at top-left of main screen)
    func simulateClick(at point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Mouse down event - clear all modifier flags to avoid Command+Click etc.
        if let mouseDown = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        ) {
            // Clear any lingering modifier key states
            mouseDown.flags = []
            mouseDown.post(tap: .cghidEventTap)
        }
        
        // Small delay between down and up
        usleep(10000) // 10ms
        
        // Mouse up event
        if let mouseUp = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        ) {
            // Clear any lingering modifier key states
            mouseUp.flags = []
            mouseUp.post(tap: .cghidEventTap)
        }
    }
    
    /// Simulate a click at the specified point, then wait for the UI to respond
    /// - Parameters:
    ///   - point: Screen coordinate to click
    ///   - delay: Delay in milliseconds after clicking (default 50ms)
    func simulateClickAndWait(at point: CGPoint, delay: UInt32 = 50000) {
        simulateClick(at: point)
        usleep(delay)
    }
    
    /// Move mouse cursor to specified position without clicking
    /// - Parameter point: Target screen coordinate
    func moveMouse(to point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        if let moveEvent = CGEvent(
            mouseEventSource: source,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) {
            moveEvent.post(tap: .cghidEventTap)
        }
    }
    
    /// Get current mouse cursor position
    func currentMousePosition() -> CGPoint {
        return NSEvent.mouseLocation
    }
    
    /// Convert from NSEvent coordinate system (origin bottom-left) to CGEvent (origin top-left)
    func convertToScreenCoordinate(_ nsPoint: CGPoint) -> CGPoint {
        guard let mainScreen = NSScreen.main else {
            return nsPoint
        }
        // NSEvent uses bottom-left origin, CGEvent uses top-left
        return CGPoint(x: nsPoint.x, y: mainScreen.frame.height - nsPoint.y)
    }
}
#endif
