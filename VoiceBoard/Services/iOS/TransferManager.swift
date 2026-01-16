//
//  TransferManager.swift
//  VoiceBoard
//
//  Global singleton for managing image transfers that survives view lifecycle
//  Ensures transfers continue even when PhotoPickerView is dismissed
//

#if os(iOS)
import SwiftUI
import UIKit
import Combine

/// Global singleton that manages image transfer lifecycle independently of any ViewModel
/// This ensures transfers continue even when the user dismisses PhotoPickerView
@MainActor
final class TransferManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = TransferManager()
    
    // MARK: - Published State
    
    /// Current transfer state - observed by views for progress display
    @Published private(set) var transferState: PhotoTransferState = .idle
    
    /// Toast message to display
    @Published private(set) var toastMessage: String?
    
    // MARK: - Dependencies
    
    private let transferService: PhotoTransferServiceProtocol
    
    // MARK: - Private State
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init(transferService: PhotoTransferServiceProtocol = PhotoTransferService.shared) {
        self.transferService = transferService
        
        // Bind transfer state from service
        transferService.transferStatePublisher
            .receive(on: RunLoop.main)
            .assign(to: &$transferState)
    }
    
    // MARK: - Public API
    
    /// Start transferring photos to Mac
    /// This runs in a detached task that survives view lifecycle changes
    /// - Parameters:
    ///   - photos: The photos to transfer
    ///   - connectionVM: The connection view model (captured strongly for the duration of transfer)
    func startTransfer(photos: [UIImage], connectionVM: ConnectionViewModel) {
        guard !photos.isEmpty else { return }
        guard connectionVM.isConnected else {
            showToast("连接已断开")
            return
        }
        
        showToast("后台传输 \(photos.count) 张照片...")
        
        // Capture strong references for the detached task
        let service = self.transferService
        
        // Run in completely detached task that won't be cancelled when views are dismissed
        Task.detached(priority: .userInitiated) {
            await self.performTransfer(
                photos: photos,
                connectionVM: connectionVM,
                service: service
            )
        }
    }
    
    // MARK: - Private Methods
    
    /// Perform the actual transfer - runs in background
    private func performTransfer(
        photos: [UIImage],
        connectionVM: ConnectionViewModel,
        service: PhotoTransferServiceProtocol
    ) async {
        // Prepare images as temp files for sendResource
        let fileURLs = await service.prepareImagesAsFiles(photos, quality: 0.7)
        
        guard !fileURLs.isEmpty else {
            await MainActor.run { self.showToast("照片压缩失败") }
            return
        }
        
        let total = fileURLs.count
        var successCount = 0
        
        // Send each file using sendResource
        for (index, fileURL) in fileURLs.enumerated() {
            let fileName = fileURL.lastPathComponent
            let resourceName = "image_\(index + 1)_of_\(total)_\(fileName)"
            
            // Notify Mac that a resource is coming
            await connectionVM.sendCommand(.willTransferResource(fileName: resourceName, index: index + 1, total: total))
            
            // Send the resource file
            if let progress = await connectionVM.sendImageResource(at: fileURL, resourceName: resourceName) {
                // Update initial progress
                await service.updateTransferProgress(current: index + 1, total: total, progress: 0)
                
                // Wait for transfer to complete using fractionCompleted
                // Also observe isCancelled to detect when transfer is cancelled
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    var hasResumed = false
                    var fractionObservation: NSKeyValueObservation?
                    var cancelledObservation: NSKeyValueObservation?
                    
                    // Helper to clean up and resume
                    let cleanup = {
                        guard !hasResumed else { return }
                        hasResumed = true
                        fractionObservation?.invalidate()
                        cancelledObservation?.invalidate()
                        continuation.resume()
                    }
                    
                    // Observe fractionCompleted for progress updates
                    fractionObservation = progress.observe(\.fractionCompleted, options: [.new]) { [weak service] prog, _ in
                        // Update progress UI
                        Task { @MainActor in
                            service?.updateTransferProgress(
                                current: index + 1,
                                total: total,
                                progress: prog.fractionCompleted
                            )
                        }
                        
                        // Check if transfer completed (fractionCompleted >= 1.0)
                        if prog.fractionCompleted >= 1.0 {
                            cleanup()
                        }
                    }
                    
                    // Observe isCancelled to detect when transfer is cancelled
                    cancelledObservation = progress.observe(\.isCancelled, options: [.new]) { prog, _ in
                        if prog.isCancelled {
                            cleanup()
                        }
                    }
                    
                    // Store to prevent deallocation
                    objc_setAssociatedObject(progress, "kvoFraction", fractionObservation, .OBJC_ASSOCIATION_RETAIN)
                    objc_setAssociatedObject(progress, "kvoCancelled", cancelledObservation, .OBJC_ASSOCIATION_RETAIN)
                    
                    // Check immediately in case already cancelled or completed
                    if progress.isCancelled || progress.fractionCompleted >= 1.0 {
                        cleanup()
                    }
                    
                    // Safety timeout: resume after 60 seconds even if not complete
                    Task {
                        try? await Task.sleep(nanoseconds: 60_000_000_000)
                        cleanup()
                    }
                }
                
                // Only count as success if transfer actually completed (not cancelled)
                if progress.fractionCompleted >= 1.0 && !progress.isCancelled {
                    successCount += 1
                }
            }
        }
        
        // Notify Mac that transfer is complete
        if successCount > 0 {
            await connectionVM.sendCommand(.resourceTransferComplete(count: successCount))
            
            // Update state to completed
            await MainActor.run {
                self.transferState = .completed(count: successCount)
                self.showToast("已发送 \(successCount) 张照片")
            }
            
            // Reset to idle after delay
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if case .completed = self.transferState {
                    self.transferState = .idle
                }
            }
        } else {
            await MainActor.run {
                self.transferState = .idle
                self.showToast("传输失败")
            }
        }
        
        // Clean up temp files after delay
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            for fileURL in fileURLs {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
    
    /// Show toast message with auto-dismiss (MainActor - synchronous)
    private func showToast(_ message: String) {
        self.toastMessage = message
        
        // Auto dismiss after delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
    }
    
    /// Reset state to idle (called when user wants to cancel or clear)
    func resetState() {
        transferService.resetState()
        toastMessage = nil
    }
}
#endif

