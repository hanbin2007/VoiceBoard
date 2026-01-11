//
//  PhotoCaptureService.swift
//  VoiceBoard
//
//  Service for capturing photos and copying to clipboard
//

#if os(iOS)
import UIKit
import AVFoundation
import Combine
import SwiftUI

/// Service for managing photo capture and clipboard operations
@MainActor
class PhotoCaptureService: ObservableObject {
    
    static let shared = PhotoCaptureService()
    
    /// Array of captured photos
    @Published var capturedPhotos: [UIImage] = []
    
    /// Camera permission status
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    
    private init() {
        checkCameraPermission()
    }
    
    // MARK: - Permission Management
    
    /// Check current camera permission status
    func checkCameraPermission() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    /// Request camera permission
    func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            cameraPermissionStatus = .authorized
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermissionStatus = granted ? .authorized : .denied
            return granted
        case .denied, .restricted:
            cameraPermissionStatus = status
            return false
        @unknown default:
            return false
        }
    }
    
    // MARK: - Photo Management
    
    /// Add a captured photo
    func addPhoto(_ image: UIImage) {
        capturedPhotos.append(image)
    }
    
    /// Remove a photo at specific index
    func removePhoto(at index: Int) {
        guard index >= 0 && index < capturedPhotos.count else { return }
        capturedPhotos.remove(at: index)
    }
    
    /// Clear all captured photos
    func clearPhotos() {
        capturedPhotos.removeAll()
    }
    
    // MARK: - Clipboard Operations
    
    /// Copy all captured photos to system clipboard
    /// - Returns: Number of photos copied, 0 if failed
    func copyPhotosToClipboard() -> Int {
        guard !capturedPhotos.isEmpty else { return 0 }
        
        let pasteboard = UIPasteboard.general
        pasteboard.images = capturedPhotos
        
        return capturedPhotos.count
    }
    
    /// Copy a single photo to clipboard
    func copyPhotoToClipboard(at index: Int) -> Bool {
        guard index >= 0 && index < capturedPhotos.count else { return false }
        
        let pasteboard = UIPasteboard.general
        pasteboard.image = capturedPhotos[index]
        
        return true
    }
}
#endif
