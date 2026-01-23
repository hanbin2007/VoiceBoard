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
    
    /// Whether a transfer has started (first file sending) - used for view dismiss control
    @Published private(set) var hasTransferStarted: Bool = false
    
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
    
    /// Start transferring photos to Mac (async version)
    /// Returns after the first file starts transferring successfully
    /// - Parameters:
    ///   - photos: The photos to transfer
    ///   - connectionVM: The connection view model (captured strongly for the duration of transfer)
    /// - Returns: true if transfer started successfully, false otherwise
    func startTransfer(photos: [UIImage], connectionVM: ConnectionViewModel) async -> Bool {
        guard !photos.isEmpty else { return false }
        guard connectionVM.isConnected else {
            showToast("连接已断开")
            return false
        }
        
        // Reset state
        hasTransferStarted = false
        
        // Prepare images as temp files for sendResource
        let fileURLs = await transferService.prepareImagesAsFiles(photos, quality: 0.7)
        
        guard !fileURLs.isEmpty else {
            showToast("照片压缩失败")
            return false
        }
        
        // Generate resource names
        let total = fileURLs.count
        let resourceNames = fileURLs.enumerated().map { index, url in
            "batch_\(index + 1)_of_\(total)_\(url.lastPathComponent)"
        }
        
        // Send willTransferBatch command to notify macOS to create batch session
        await connectionVM.sendCommand(.willTransferBatch(fileNames: resourceNames))
        
        showToast("传输 \(total) 张照片...")
        
        // Capture strong references for the detached task
        let service = self.transferService
        
        // Start the first file transfer and wait for it to begin
        guard let firstFileURL = fileURLs.first else { return false }
        let firstName = resourceNames[0]
        
        // Notify Mac about first file
        await connectionVM.sendCommand(.batchFileTransferring(fileName: firstName, index: 1, total: total))
        
        // Start sending first file
        guard let firstProgress = await connectionVM.sendImageResource(at: firstFileURL, resourceName: firstName) else {
            showToast("传输启动失败")
            return false
        }
        
        // Mark transfer as started
        hasTransferStarted = true
        
        // Update initial progress
        await service.updateTransferProgress(current: 1, total: total, progress: 0)
        
        // Continue the rest of the transfer in background
        Task.detached(priority: .userInitiated) {
            await self.continueTransfer(
                fileURLs: fileURLs,
                resourceNames: resourceNames,
                firstProgress: firstProgress,
                connectionVM: connectionVM,
                service: service
            )
        }
        
        return true
    }
    
    // MARK: - Private Methods
    
    /// Continue the batch transfer after first file has started
    private func continueTransfer(
        fileURLs: [URL],
        resourceNames: [String],
        firstProgress: Progress,
        connectionVM: ConnectionViewModel,
        service: PhotoTransferServiceProtocol
    ) async {
        let total = fileURLs.count
        var successCount = 0
        
        // Wait for first file to complete
        let firstSuccess = await waitForProgress(firstProgress, index: 1, total: total, service: service)
        if firstSuccess { successCount += 1 }
        
        // Send remaining files (starting from index 1)
        for i in 1..<fileURLs.count {
            let fileURL = fileURLs[i]
            let resourceName = resourceNames[i]
            
            // Notify Mac about this file
            await connectionVM.sendCommand(.batchFileTransferring(fileName: resourceName, index: i + 1, total: total))
            
            // Send the resource file
            if let progress = await connectionVM.sendImageResource(at: fileURL, resourceName: resourceName) {
                // Update initial progress
                await service.updateTransferProgress(current: i + 1, total: total, progress: 0)
                
                // Wait for completion
                let success = await waitForProgress(progress, index: i + 1, total: total, service: service)
                if success { successCount += 1 }
            }
        }
        
        // Notify Mac that batch transfer is complete
        await connectionVM.sendCommand(.batchTransferComplete)
        
        // Update final state
        if successCount > 0 {
            await MainActor.run {
                self.transferState = .completed(count: successCount)
                self.showToast("已发送 \(successCount) 张照片")
                self.hasTransferStarted = false
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
                self.hasTransferStarted = false
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
    
    /// Wait for a Progress object to complete
    /// Returns true if completed successfully, false if cancelled or timed out
    private func waitForProgress(_ progress: Progress, index: Int, total: Int, service: PhotoTransferServiceProtocol) async -> Bool {
        // Use a class to hold observations - ensures they stay alive
        class ObservationHolder {
            var observations: [NSKeyValueObservation] = []
            func invalidateAll() {
                for obs in observations {
                    obs.invalidate()
                }
                observations.removeAll()
            }
        }
        
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            var hasResumed = false
            let holder = ObservationHolder()
            
            // Helper to clean up and resume
            let cleanup = { (success: Bool) in
                guard !hasResumed else { return }
                hasResumed = true
                holder.invalidateAll()
                continuation.resume(returning: success)
            }
            
            // Observe fractionCompleted for progress updates
            let fractionObservation = progress.observe(\.fractionCompleted, options: [.new]) { [weak service] prog, _ in
                // Update progress UI
                Task { @MainActor in
                    service?.updateTransferProgress(
                        current: index,
                        total: total,
                        progress: prog.fractionCompleted
                    )
                }
                
                // Check if transfer completed
                if prog.fractionCompleted >= 1.0 {
                    cleanup(true)
                }
            }
            holder.observations.append(fractionObservation)
            
            // Observe isCancelled
            let cancelledObservation = progress.observe(\.isCancelled, options: [.new]) { prog, _ in
                if prog.isCancelled {
                    cleanup(false)
                }
            }
            holder.observations.append(cancelledObservation)
            
            // Check immediately in case already completed or cancelled
            if progress.fractionCompleted >= 1.0 {
                cleanup(true)
                return
            } else if progress.isCancelled {
                cleanup(false)
                return
            }
            
            // Safety timeout: resume after 60 seconds
            Task { [holder] in
                _ = holder // Keep holder alive
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                cleanup(false)
            }
        }
    }
    
    /// Show toast message with auto-dismiss
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
        hasTransferStarted = false
    }
}
#endif


