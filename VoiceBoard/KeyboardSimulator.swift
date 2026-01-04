//
//  KeyboardSimulator.swift
//  VoiceBoard
//
//  Simulates keyboard input using CGEvent (macOS only)
//

#if os(macOS)
import Foundation
import Carbon
import AppKit

/// Simulates keyboard input on macOS using CGEvent
class KeyboardSimulator {
    
    static let shared = KeyboardSimulator()
    
    private init() {}
    
    // MARK: - Permission Check
    
    /// Check if accessibility permissions are granted
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    /// Request accessibility permission (shows system dialog)
    func requestAccessibilityPermission() {
        // First try the standard way
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        // If not trusted, open System Settings directly
        if !isTrusted {
            openAccessibilitySettings()
        }
    }
    
    /// Open System Settings to Accessibility > Privacy
    func openAccessibilitySettings() {
        // macOS Ventura and later use different URL scheme
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Text Input
    
    /// Type text character by character (simulates keyboard input)
    func typeText(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Method 1: Use CGEvent with Unicode string
        let source = CGEventSource(stateID: .hidSystemState)
        
        for character in text {
            let string = String(character)
            
            // Create key down event
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                keyDown.keyboardSetUnicodeString(stringLength: string.count, unicodeString: Array(string.utf16))
                keyDown.post(tap: .cghidEventTap)
            }
            
            // Create key up event
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                keyUp.keyboardSetUnicodeString(stringLength: string.count, unicodeString: Array(string.utf16))
                keyUp.post(tap: .cghidEventTap)
            }
            
            // Small delay between characters for stability
            usleep(1000) // 1ms
        }
    }
    
    // MARK: - Special Keys
    
    /// Press Enter key
    func pressEnter() {
        pressKey(keyCode: kVK_Return)
    }
    
    /// Press Delete/Backspace key
    func pressDelete() {
        pressKey(keyCode: kVK_Delete)
    }
    
    /// Press Tab key
    func pressTab() {
        pressKey(keyCode: kVK_Tab)
    }
    
    /// Press Escape key
    func pressEscape() {
        pressKey(keyCode: kVK_Escape)
    }
    
    // MARK: - Keyboard Shortcuts
    
    /// Select All (⌘A)
    func selectAll() {
        pressKeyWithCommand(keyCode: kVK_ANSI_A)
    }
    
    /// Copy (⌘C)
    func copy() {
        pressKeyWithCommand(keyCode: kVK_ANSI_C)
    }
    
    /// Paste (⌘V)
    func paste() {
        pressKeyWithCommand(keyCode: kVK_ANSI_V)
    }
    
    /// Cut (⌘X)
    func cut() {
        pressKeyWithCommand(keyCode: kVK_ANSI_X)
    }
    
    /// Undo (⌘Z)
    func undo() {
        pressKeyWithCommand(keyCode: kVK_ANSI_Z)
    }
    
    // MARK: - Clear Input Field
    
    /// Clear the current input field (⌘A then Delete)
    func clearInputField() {
        selectAll()
        usleep(50000) // 50ms delay
        pressDelete()
    }
    
    // MARK: - Combined Actions
    
    /// Insert text and press Enter
    func insertTextAndEnter(_ text: String) {
        typeText(text)
        usleep(10000) // 10ms delay
        pressEnter()
    }
    
    /// Clear field and insert new text
    func replaceText(_ text: String) {
        clearInputField()
        usleep(50000) // 50ms delay
        typeText(text)
    }
    
    // MARK: - Private Helpers
    
    private func pressKey(keyCode: Int) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true) {
            keyDown.post(tap: .cghidEventTap)
        }
        
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false) {
            keyUp.post(tap: .cghidEventTap)
        }
    }
    
    private func pressKeyWithCommand(keyCode: Int) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
#endif
