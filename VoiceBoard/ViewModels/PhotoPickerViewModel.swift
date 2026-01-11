//
//  PhotoPickerViewModel.swift
//  VoiceBoard
//
//  ViewModel for PhotoPickerView
//

import SwiftUI
import Combine

@MainActor
class PhotoPickerViewModel: ObservableObject {
    // MARK: - Dependencies
    
    private let photoService = PhotoCaptureService.shared
    private let connectionViewModel: ConnectionViewModel
    
    // MARK: - Published Properties
    
    @Published var capturedPhotos: [UIImage] = []
    @Published var showCamera = false
    @Published var showPermissionAlert = false
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var selectedImageIndex: Int? = nil
    
    // MARK: - Initialization
    
    init(connectionViewModel: ConnectionViewModel) {
        self.connectionViewModel = connectionViewModel
        
        // Bind to photo service
        photoService.$capturedPhotos
            .receive(on: RunLoop.main)
            .assign(to: &$capturedPhotos)
    }
    
    // MARK: - Actions
    
    func checkCameraPermission() {
        Task {
            let hasPermission = await photoService.requestCameraPermission()
            if hasPermission {
                showCamera = true
            } else {
                showPermissionAlert = true
            }
        }
    }
    
    func addPhoto(_ image: UIImage) {
        photoService.addPhoto(image)
    }
    
    func removePhoto(at index: Int) {
        photoService.removePhoto(at: index)
    }
    
    func clearPhotos() {
        photoService.clearPhotos()
    }
    
    func copyAndSend() {
        let count = photoService.copyPhotosToClipboard()
        if count > 0 {
            // Provide haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            if connectionViewModel.isConnected {
                showToast(message: "已复制 \(count) 张照片，即将粘贴...")
                
                // Wait 1 second before sending paste command
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.connectionViewModel.sendCommand(.paste)
                }
            } else {
                showToast(message: "已复制 \(count) 张照片")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func showToast(message: String) {
        withAnimation(.spring()) {
            self.toastMessage = message
            self.showToast = true
        }
        
        // Hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            withAnimation(.easeOut(duration: 0.2)) {
                self?.showToast = false
            }
        }
    }
}
