//
//  PhotoTransferService.swift
//  VoiceBoard
//
//  Service layer for photo transfer operations - handles image compression and transfer
//

#if os(iOS)
import UIKit
import Combine

// MARK: - Transfer State

/// Represents the current state of photo transfer
enum PhotoTransferState: Equatable {
    case idle
    case compressing(progress: Double)
    case sending
    case transferring(current: Int, total: Int, progress: Double) // Real-time transfer progress
    case completed(count: Int)
    case failed(message: String)
    
    var isInProgress: Bool {
        switch self {
        case .compressing, .sending, .transferring:
            return true
        default:
            return false
        }
    }
}

// MARK: - Protocol Definition

/// Protocol for photo transfer operations - enables dependency injection and testing
/// Conforms to AnyObject to allow weak references
protocol PhotoTransferServiceProtocol: AnyObject {
    /// Current transfer state
    var transferState: PhotoTransferState { get }
    
    /// Publisher for transfer state changes (for Combine bindings)
    var transferStatePublisher: Published<PhotoTransferState>.Publisher { get }
    
    /// Compress images for transfer
    func compressImages(_ images: [UIImage], quality: CGFloat) async -> [Data]
    
    /// Prepare images as temporary files for sendResource-based transfer
    /// Returns file URLs that can be used with MCSession.sendResource
    func prepareImagesAsFiles(_ images: [UIImage], quality: CGFloat) async -> [URL]
    
    /// Update transfer state for progress tracking (called from ConnectionViewModel)
    func updateTransferProgress(current: Int, total: Int, progress: Double)
    
    /// Mark transfer as complete
    func markTransferComplete(count: Int)
    
    /// Reset transfer state to idle
    func resetState()
}

// MARK: - Error Types

/// Errors that can occur during photo transfer
enum PhotoTransferError: LocalizedError {
    case noImages
    case compressionFailed
    case transferFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noImages:
            return "没有可传输的照片"
        case .compressionFailed:
            return "照片压缩失败"
        case .transferFailed(let reason):
            return "传输失败: \(reason)"
        }
    }
}

// MARK: - Implementation

/// Default implementation of PhotoTransferService
@MainActor
final class PhotoTransferService: ObservableObject, PhotoTransferServiceProtocol {
    
    // MARK: - Published State
    
    @Published private(set) var transferState: PhotoTransferState = .idle
    
    /// Publisher for transfer state (required by protocol)
    var transferStatePublisher: Published<PhotoTransferState>.Publisher {
        $transferState
    }
    
    // MARK: - Configuration
    
    struct Configuration {
        /// Default JPEG compression quality (0.0 - 1.0)
        var defaultQuality: CGFloat = 0.7
        
        /// Maximum image dimension (width or height)
        var maxDimension: CGFloat = 1920
        
        /// Whether to resize images before compression
        var resizeBeforeCompression: Bool = true
    }
    
    private let configuration: Configuration
    
    // MARK: - Initialization
    
    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// Compress images for transfer with optional resizing
    func compressImages(_ images: [UIImage], quality: CGFloat) async -> [Data] {
        var compressedData: [Data] = []
        let total = images.count
        
        for (index, image) in images.enumerated() {
            // Update progress
            let progress = Double(index) / Double(total)
            transferState = .compressing(progress: progress)
            
            // Resize if needed
            let processedImage: UIImage
            if configuration.resizeBeforeCompression {
                processedImage = resizeImageIfNeeded(image)
            } else {
                processedImage = image
            }
            
            // Compress to JPEG
            if let data = processedImage.jpegData(compressionQuality: quality) {
                compressedData.append(data)
            }
            
            // Yield to avoid blocking main thread too long
            await Task.yield()
        }
        
        return compressedData
    }
    
    /// Reset transfer state to idle
    func resetState() {
        transferState = .idle
    }
    
    /// Prepare images as temporary files for sendResource-based transfer
    /// This method saves compressed images to temp files that can be streamed via sendResource
    func prepareImagesAsFiles(_ images: [UIImage], quality: CGFloat) async -> [URL] {
        var fileURLs: [URL] = []
        let total = images.count
        
        // Create temp directory for images
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceBoardTransfer", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Clean up old files first
        if let oldFiles = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for oldFile in oldFiles {
                try? FileManager.default.removeItem(at: oldFile)
            }
        }
        
        for (index, image) in images.enumerated() {
            // Update compression progress
            let progress = Double(index) / Double(total)
            transferState = .compressing(progress: progress)
            
            // Resize if needed
            let processedImage: UIImage
            if configuration.resizeBeforeCompression {
                processedImage = resizeImageIfNeeded(image)
            } else {
                processedImage = image
            }
            
            // Compress to JPEG
            guard let data = processedImage.jpegData(compressionQuality: quality) else {
                continue
            }
            
            // Save to temp file with unique name
            let fileName = "image_\(index + 1)_\(UUID().uuidString.prefix(8)).jpg"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            do {
                try data.write(to: fileURL)
                fileURLs.append(fileURL)
            } catch {
                print("PhotoTransferService: Failed to save temp file: \(error)")
            }
            
            // Yield to avoid blocking main thread
            await Task.yield()
        }
        
        // Mark compressing complete, now waiting for transfer
        if !fileURLs.isEmpty {
            transferState = .sending
        }
        
        return fileURLs
    }
    
    /// Update transfer state for progress tracking (called from ConnectionViewModel)
    func updateTransferProgress(current: Int, total: Int, progress: Double) {
        transferState = .transferring(current: current, total: total, progress: progress)
    }
    
    /// Mark transfer as complete and auto-reset to idle after delay
    func markTransferComplete(count: Int) {
        transferState = .completed(count: count)
        
        // Auto-reset to idle after delay so the floating view dismisses
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
            if case .completed = self.transferState {
                self.transferState = .idle
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Resize image if it exceeds maximum dimensions
    private func resizeImageIfNeeded(_ image: UIImage) -> UIImage {
        let maxDimension = configuration.maxDimension
        let size = image.size
        
        // Check if resizing is needed
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // Render resized image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Shared Instance

extension PhotoTransferService {
    /// Shared instance for convenience (can still use DI for testing)
    static let shared = PhotoTransferService()
}
#endif
