//
//  CommandHandler.swift
//  VoiceBoard
//
//  Handles incoming commands on macOS - separates command processing from connection management
//

#if os(macOS)
import AppKit
import Foundation

// MARK: - Protocol Definition

/// Protocol for command handling - enables strategy pattern and testing
protocol CommandHandlerProtocol {
    func handle(_ command: VoiceBoardCommand, context: CommandContext)
}

/// Context passed to command handlers
struct CommandContext {
    let hasAccessibilityPermission: Bool
    let performClickIfEnabled: () -> Void
    let sendResponse: (VoiceBoardCommand) -> Void
    let log: (String) -> Void
}

// MARK: - Command Handler Implementation

/// Handles all VoiceBoardCommands on macOS
final class CommandHandler: CommandHandlerProtocol {
    
    // MARK: - Singleton
    
    static let shared = CommandHandler()
    
    private init() {}
    
    // MARK: - Handle Command
    
    func handle(_ command: VoiceBoardCommand, context: CommandContext) {
        print("CommandHandler: 处理命令 \(command)")
        
        switch command {
        case .text(let text):
            handleText(text, context: context)
            
        case .insert(let text):
            handleInsert(text, context: context)
            
        case .insertAndEnter(let text):
            handleInsertAndEnter(text, context: context)
            
        case .enter:
            handleEnter(context: context)
            
        case .clear:
            handleClear(context: context)
            
        case .paste:
            handlePaste(context: context)
            
        case .delete:
            handleDelete(context: context)
            
        case .selectAll:
            handleSelectAll(context: context)
            
        case .copy:
            handleCopy(context: context)
            
        case .cut:
            handleCut(context: context)
            
        case .setClickBeforeInput(let enabled):
            handleSetClickBeforeInput(enabled, context: context)
            
        case .clickBeforeInputState:
            // Ignored on macOS - only for iOS
            break
            
        case .willPasteImages(let count):
            handleWillPasteImages(count, context: context)
            
        case .pasteImages(let imageDataArray):
            handlePasteImages(imageDataArray, context: context)
            
        case .willTransferResource(let fileName, let index, let total):
            handleWillTransferResource(fileName: fileName, index: index, total: total, context: context)
            
        case .resourceTransferComplete(let count):
            handleResourceTransferComplete(count: count, context: context)
        }
    }
    
    // MARK: - Individual Handlers
    
    private func handleText(_ text: String, context: CommandContext) {
        // Text preview only - handled by ConnectionViewModel directly
    }
    
    private func handleInsert(_ text: String, context: CommandContext) {
        guard context.hasAccessibilityPermission else {
            context.log("未授权辅助功能")
            return
        }
        
        DispatchQueue.global(qos: .userInteractive).async {
            context.performClickIfEnabled()
            KeyboardSimulator.shared.typeText(text)
        }
    }
    
    private func handleInsertAndEnter(_ text: String, context: CommandContext) {
        guard context.hasAccessibilityPermission else { return }
        
        DispatchQueue.global(qos: .userInteractive).async {
            context.performClickIfEnabled()
            KeyboardSimulator.shared.insertTextAndEnter(text)
        }
    }
    
    private func handleEnter(context: CommandContext) {
        guard context.hasAccessibilityPermission else { return }
        
        DispatchQueue.global(qos: .userInteractive).async {
            KeyboardSimulator.shared.pressEnter()
        }
    }
    
    private func handleClear(context: CommandContext) {
        guard context.hasAccessibilityPermission else { return }
        
        DispatchQueue.global(qos: .userInteractive).async {
            context.performClickIfEnabled()
            KeyboardSimulator.shared.clearInputField()
        }
    }
    
    private func handlePaste(context: CommandContext) {
        guard context.hasAccessibilityPermission else { return }
        
        DispatchQueue.global(qos: .userInteractive).async {
            context.performClickIfEnabled()
            KeyboardSimulator.shared.paste()
        }
    }
    
    private func handleDelete(context: CommandContext) {
        guard context.hasAccessibilityPermission else { return }
        
        DispatchQueue.global(qos: .userInteractive).async {
            KeyboardSimulator.shared.pressDelete()
        }
    }
    
    private func handleSelectAll(context: CommandContext) {
        guard context.hasAccessibilityPermission else { return }
        
        DispatchQueue.global(qos: .userInteractive).async {
            context.performClickIfEnabled()
            KeyboardSimulator.shared.selectAll()
        }
    }
    
    private func handleCopy(context: CommandContext) {
        guard context.hasAccessibilityPermission else { return }
        
        DispatchQueue.global(qos: .userInteractive).async {
            KeyboardSimulator.shared.copy()
        }
    }
    
    private func handleCut(context: CommandContext) {
        guard context.hasAccessibilityPermission else { return }
        
        DispatchQueue.global(qos: .userInteractive).async {
            KeyboardSimulator.shared.cut()
        }
    }
    
    private func handleSetClickBeforeInput(_ enabled: Bool, context: CommandContext) {
        ClickPositionManager.shared.isEnabled = enabled
        context.log("输入前点击已\(enabled ? "启用" : "禁用")")
        context.sendResponse(.clickBeforeInputState(enabled))
    }
    
    private func handleWillPasteImages(_ count: Int, context: CommandContext) {
        // Immediately show receiving state when we get the preview command
        // This ensures the progress toast appears before we start receiving actual image data
        Task { @MainActor in
            ImageTransferToastManager.shared.show(state: .receiving(count: count))
        }
    }
    
    private func handlePasteImages(_ imageDataArray: [Data], context: CommandContext) {
        let totalCount = imageDataArray.count
        
        guard context.hasAccessibilityPermission else {
            context.log("未授权辅助功能，无法粘贴图片")
            Task { @MainActor in
                ImageTransferToastManager.shared.show(state: .failed(message: "需要辅助功能权限"))
            }
            return
        }
        
        // Process images in background
        // Note: receiving state is already shown by handleWillPasteImages
        Task { @MainActor in
            
            // Now dispatch background processing after window is created
            DispatchQueue.global(qos: .userInteractive).async {
                context.performClickIfEnabled()
                
                // Convert data to images and save to temp files
                // Using file URLs instead of NSImage objects to ensure all images are pasted
                // (Many apps only read the first NSImage from pasteboard)
                var tempURLs: [URL] = []
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("VoiceBoard", isDirectory: true)
                
                // Create temp directory if needed
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                
                for (index, data) in imageDataArray.enumerated() {
                    // Update processing progress
                    Task { @MainActor in
                        ImageTransferToastManager.shared.show(
                            state: .processing(current: index + 1, total: totalCount)
                        )
                    }
                    
                    // Verify it's valid image data
                    guard NSImage(data: data) != nil else {
                        continue
                    }
                    
                    // Save to temp file
                    let fileName = "image_\(UUID().uuidString).jpg"
                    let fileURL = tempDir.appendingPathComponent(fileName)
                    
                    do {
                        try data.write(to: fileURL)
                        tempURLs.append(fileURL)
                    } catch {
                        print("CommandHandler: 保存临时文件失败: \(error)")
                    }
                    
                    // Small delay for UI update visibility
                    usleep(50000) // 50ms
                }
                
                guard !tempURLs.isEmpty else {
                    print("CommandHandler: 无有效图片数据")
                    Task { @MainActor in
                        ImageTransferToastManager.shared.show(state: .failed(message: "图片数据无效"))
                    }
                    return
                }
                
                // Show pasting state
                Task { @MainActor in
                    ImageTransferToastManager.shared.show(state: .pasting)
                }
                
                // Write file URLs to pasteboard (enables multi-image paste in most apps)
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects(tempURLs as [NSURL])
                
                // Small delay before paste
                usleep(100000) // 100ms
                
                // Simulate paste
                KeyboardSimulator.shared.paste()
                
                // Show completed state
                let count = tempURLs.count
                Task { @MainActor in
                    ImageTransferToastManager.shared.show(state: .completed(count: count))
                }
                
                print("CommandHandler: 已粘贴 \(count) 张图片")
                
                // Clean up temp files after delay (give apps time to read them)
                DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                    for url in tempURLs {
                        try? FileManager.default.removeItem(at: url)
                    }
                    // Try to remove the directory if empty
                    try? FileManager.default.removeItem(at: tempDir)
                }
            }
        }
    }
    
    // MARK: - Resource Transfer Handlers (sendResource-based)
    
    private func handleWillTransferResource(fileName: String, index: Int, total: Int, context: CommandContext) {
        // Show receiving state with progress info
        // The actual file will come via sendResource delegate
        Task { @MainActor in
            ImageTransferToastManager.shared.show(state: .receiving(count: total))
        }
        context.log("准备接收资源 \(index)/\(total): \(fileName)")
    }
    
    private func handleResourceTransferComplete(count: Int, context: CommandContext) {
        // All resources have been sent
        // Note: The actual paste happens in ConnectionViewModel.didFinishReceivingResourceWithName
        context.log("资源传输完成，共 \(count) 个文件")
    }
}
#endif
