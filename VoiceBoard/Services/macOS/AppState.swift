//
//  AppState.swift
//  VoiceBoard
//
//  Manages macOS window state (macOS only)
//

#if os(macOS)
import Foundation
import AppKit
import Combine

/// Manages the main window visibility state for macOS
class AppState: ObservableObject {
    @Published var isWindowVisible: Bool = true
    
    func hideWindow() {
        if let window = NSApplication.shared.windows.first(where: { $0.title.contains("VoiceBoard") || $0.isKeyWindow }) {
            window.orderOut(nil)
            isWindowVisible = false
        }
    }
    
    func showWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            isWindowVisible = true
        }
    }
}
#endif
