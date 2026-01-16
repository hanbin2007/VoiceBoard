//
//  PhotoCaptureService.swift
//  VoiceBoard
//
//  Service layer for photo capture and storage - manages camera permissions and photo collection
//

#if os(iOS)
import UIKit
import AVFoundation
import Combine

// MARK: - Protocol Definition

/// Protocol for photo capture operations - enables dependency injection and testing
protocol PhotoCaptureServiceProtocol: AnyObject {
    /// Array of captured photos
    var capturedPhotos: [UIImage] { get }
    var capturedPhotosPublisher: Published<[UIImage]>.Publisher { get }
    
    /// Camera permission status
    var cameraPermissionStatus: AVAuthorizationStatus { get }
    
    /// Check current camera permission
    func checkCameraPermission()
    
    /// Request camera permission
    func requestCameraPermission() async -> Bool
    
    /// Add a photo to the collection
    func addPhoto(_ image: UIImage)
    
    /// Remove a photo at specific index
    func removePhoto(at index: Int)
    
    /// Clear all photos
    func clearPhotos()
    
    /// Copy all photos to system clipboard
    func copyPhotosToClipboard() -> Int
}

// MARK: - Implementation

/// Service for managing photo capture and clipboard operations
@MainActor
final class PhotoCaptureService: ObservableObject, PhotoCaptureServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = PhotoCaptureService()
    
    // MARK: - Published Properties
    
    @Published private(set) var capturedPhotos: [UIImage] = []
    
    var capturedPhotosPublisher: Published<[UIImage]>.Publisher {
        $capturedPhotos
    }
    
    @Published private(set) var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    
    // MARK: - Initialization
    
    init() {
        checkCameraPermission()
    }
    
    // MARK: - Permission Management
    
    func checkCameraPermission() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
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
    
    func addPhoto(_ image: UIImage) {
        capturedPhotos.append(image)
    }
    
    func removePhoto(at index: Int) {
        guard index >= 0 && index < capturedPhotos.count else { return }
        capturedPhotos.remove(at: index)
    }
    
    func clearPhotos() {
        capturedPhotos.removeAll()
    }
    
    // MARK: - Clipboard Operations
    
    func copyPhotosToClipboard() -> Int {
        guard !capturedPhotos.isEmpty else { return 0 }
        
        let pasteboard = UIPasteboard.general
        pasteboard.images = capturedPhotos
        
        return capturedPhotos.count
    }
}
#endif
