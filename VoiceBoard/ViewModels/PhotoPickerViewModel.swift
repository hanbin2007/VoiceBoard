//
//  PhotoPickerViewModel.swift
//  VoiceBoard
//
//  ViewModel for PhotoPickerView - orchestrates photo capture, transfer and UI state
//  Follows MVVM pattern with dependency injection for testability
//

#if os(iOS)
import SwiftUI
import UIKit
import Combine

/// ViewModel for managing photo capture and transfer workflow
@MainActor
final class PhotoPickerViewModel: ObservableObject {
    
    // MARK: - Dependencies (Injected)
    
    private let captureService: PhotoCaptureServiceProtocol
    private weak var connectionViewModel: ConnectionViewModel?
    
    // MARK: - Published Properties (UI State)
    
    /// Photos captured in current session
    @Published private(set) var capturedPhotos: [UIImage] = []
    
    /// Whether camera sheet is showing
    @Published var showCamera = false
    
    /// Whether permission alert is showing
    @Published var showPermissionAlert = false
    
    /// Selected image index for preview
    @Published var selectedImageIndex: Int? = nil
    
    /// Toast display state (View handles animation)
    @Published private(set) var toastState: ToastState = .hidden
    
    /// Event for triggering haptic feedback (View observes this)
    @Published private(set) var hapticEvent: HapticEventType?
    
    // MARK: - State Types
    
    /// Toast visibility state
    enum ToastState: Equatable {
        case hidden
        case visible(message: String)
        
        var isVisible: Bool {
            if case .visible = self { return true }
            return false
        }
        
        var message: String {
            if case .visible(let msg) = self { return msg }
            return ""
        }
    }
    
    /// Types of haptic feedback that can be triggered
    enum HapticEventType {
        case success
        case error
        case warning
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize with dependencies (supports dependency injection)
    /// - Parameters:
    ///   - connectionViewModel: ViewModel for managing connection (weak reference to avoid retain cycle)
    ///   - captureService: Service for photo capture operations
    init(
        connectionViewModel: ConnectionViewModel,
        captureService: PhotoCaptureServiceProtocol = PhotoCaptureService.shared
    ) {
        self.connectionViewModel = connectionViewModel
        self.captureService = captureService
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind captured photos from service
        captureService.capturedPhotosPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$capturedPhotos)
    }
    
    // MARK: - Public Actions (Intent)
    
    /// Check camera permission and show camera if granted
    func checkCameraPermission() {
        Task {
            let hasPermission = await captureService.requestCameraPermission()
            if hasPermission {
                showCamera = true
            } else {
                showPermissionAlert = true
            }
        }
    }
    
    /// Add a captured photo
    func addPhoto(_ image: UIImage) {
        captureService.addPhoto(image)
    }
    
    /// Remove a photo at index
    func removePhoto(at index: Int) {
        captureService.removePhoto(at: index)
    }
    
    /// Clear all photos
    func clearPhotos() {
        captureService.clearPhotos()
    }
    
    /// Copy photos to clipboard and send to Mac
    func copyAndSend() {
        guard !capturedPhotos.isEmpty else { return }
        guard let connectionVM = connectionViewModel else {
            displayToast(message: "连接已断开")
            return
        }
        
        // Copy to local clipboard
        let clipboardCount = captureService.copyPhotosToClipboard()
        
        // Request haptic feedback (View will handle this)
        triggerHaptic(.success)
        
        // Transfer to Mac if connected - delegate to TransferManager which survives view lifecycle
        if connectionVM.isConnected {
            // Capture photos before clearing
            let photosToTransfer = capturedPhotos
            
            // Show immediate feedback
            displayToast(message: "已复制 \(clipboardCount) 张照片，后台传输中...")
            
            // Delegate to global TransferManager - this survives when PhotoPickerView is dismissed
            TransferManager.shared.startTransfer(photos: photosToTransfer, connectionVM: connectionVM)
        } else {
            displayToast(message: "已复制 \(clipboardCount) 张照片到剪贴板")
        }
    }
    
    // MARK: - Private Methods
    
    /// Display toast message with auto-dismiss
    /// ViewModel only manages state; View handles animation
    private func displayToast(message: String) {
        toastState = .visible(message: message)
        
        // Auto dismiss after delay
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            toastState = .hidden
        }
    }
    
    /// Trigger haptic feedback event (ViewModel signals, View responds)
    private func triggerHaptic(_ type: HapticEventType) {
        hapticEvent = type
        // Reset after brief delay so it can be triggered again
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            hapticEvent = nil
        }
    }
}
#endif
