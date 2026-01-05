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
    
    /// Callback when accessibility permission changes
    var onPermissionChange: ((Bool) -> Void)?
    
    private init() {
        // 监听辅助功能权限变化
        setupPermissionObserver()
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    // MARK: - Permission Observer
    
    private func setupPermissionObserver() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // 延迟检查，因为权限变更需要一点时间生效
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let isGranted = self?.checkAccessibilityPermission(prompt: false) ?? false
                self?.onPermissionChange?(isGranted)
            }
        }
    }
    
    // MARK: - Permission Check
    
    /// Check if accessibility permissions are granted
    /// - Parameter prompt: If true, shows system dialog prompting user to grant access
    /// - Returns: Whether accessibility permission is granted
    func checkAccessibilityPermission(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    /// Request accessibility permission - shows system dialog that guides user to System Settings
    /// This will add the app to the accessibility list automatically
    func requestAccessibilityPermission() {
        // 使用 prompt: true 来触发系统弹窗，这会自动将 App 添加到辅助功能列表中
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        if !isTrusted {
            // 弹窗会自动显示，但如果用户之前拒绝过，直接打开设置
            openAccessibilitySettings()
        }
    }
    
    /// Open System Settings to Accessibility > Privacy directly
    func openAccessibilitySettings() {
        // macOS Ventura (13.0) and later use this URL scheme
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
        
        // Key down with Command modifier
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        
        // Small delay to ensure key press is registered
        usleep(5000) // 5ms
        
        // Key up - clear modifier flag to release Command key
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false) {
            // Important: Post key up WITHOUT the command flag to properly release
            keyUp.flags = []
            keyUp.post(tap: .cghidEventTap)
        }
        
        // Additional delay to let system process the key release
        usleep(10000) // 10ms
    }
}
#endif
