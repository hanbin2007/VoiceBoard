//
//  Command.swift
//  VoiceBoard
//
//  Defines command types for iOS → Mac communication
//

import Foundation

/// Commands that can be sent from iOS to Mac
enum VoiceBoardCommand: Codable {
    /// Display text in real-time (preview only)
    case text(String)
    
    /// Insert text at current cursor position
    case insert(String)
    
    /// Insert text and press Enter
    case insertAndEnter(String)
    
    /// Press Enter key
    case enter
    
    /// Clear the current input field (⌘A + Delete)
    case clear
    
    /// Paste from clipboard (⌘V)
    case paste
    
    /// Delete one character (Backspace)
    case delete
    
    /// Select all (⌘A)
    case selectAll
    
    /// Copy selected text (⌘C)
    case copy
    
    /// Cut selected text (⌘X)
    case cut
    
    /// Set click-before-input enabled state on Mac
    case setClickBeforeInput(Bool)
    
    /// Sync click-before-input state from Mac to iOS (for display purposes)
    case clickBeforeInputState(Bool)
    
    /// Notify Mac that images are about to be sent (sent before actual image data)
    /// @deprecated Use willTransferResource for new resource-based transfers
    case willPasteImages(count: Int)
    
    /// Paste multiple images (sent as Data)
    /// @deprecated Use sendResource-based transfer for better memory efficiency
    case pasteImages([Data])
    
    /// Notify Mac that a resource file transfer is starting (for sendResource-based transfer)
    /// - Parameters:
    ///   - fileName: Name of the resource file being transferred
    ///   - index: Current image index (1-based)
    ///   - total: Total number of images being transferred
    /// @deprecated Use willTransferBatch for batch transfers
    case willTransferResource(fileName: String, index: Int, total: Int)
    
    /// Notify Mac that all resource transfers are complete
    case resourceTransferComplete(count: Int)
    
    // MARK: - Batch Transfer Commands
    
    /// Notify Mac that a batch transfer is starting with file names list
    /// macOS should create a batch receive session and wait for all files
    /// - Parameter fileNames: List of resource names that will be sent
    case willTransferBatch(fileNames: [String])
    
    /// Notify Mac that a specific file in batch is being transferred
    /// - Parameters:
    ///   - fileName: Name of the resource file being transferred
    ///   - index: Current file index (1-based)
    ///   - total: Total number of files in batch
    case batchFileTransferring(fileName: String, index: Int, total: Int)
    
    /// Notify Mac that all batch files have been sent
    case batchTransferComplete
    
    // MARK: - Encoding
    
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> VoiceBoardCommand? {
        try? JSONDecoder().decode(VoiceBoardCommand.self, from: data)
    }
}
