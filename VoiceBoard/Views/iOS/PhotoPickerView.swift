//
//  PhotoPickerView.swift
//  VoiceBoard
//
//  View for capturing multiple photos and sending to Mac
//  Follows MVVM pattern - View only handles UI, delegates logic to ViewModel
//

#if os(iOS)
import SwiftUI
import PhotosUI

/// View for capturing and managing multiple photos
struct PhotoPickerView: View {
    @StateObject var viewModel: PhotoPickerViewModel
    @ObservedObject private var transferManager = TransferManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // Grid layout
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 16) {
                    headerView
                    photoGridView
                    Spacer()
                    actionButtonsView
                }
                
                toastView
            }
            .navigationTitle("拍照")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCamera) {
                ImagePickerView(
                    sourceType: .camera,
                    onImagePicked: { image in
                        withAnimation(.easeOut(duration: 0.1)) {
                            viewModel.addPhoto(image)
                        }
                    }
                )
            }
            .fullScreenCover(item: Binding(
                get: { viewModel.selectedImageIndex.map { IdentifiableInt(id: $0) } },
                set: { viewModel.selectedImageIndex = $0?.id }
            )) { item in
                PhotoPreviewView(
                    images: viewModel.capturedPhotos,
                    initialIndex: item.id,
                    onClose: { viewModel.selectedImageIndex = nil }
                )
            }
            .alert("需要相机权限", isPresented: $viewModel.showPermissionAlert) {
                Button("取消", role: .cancel) {}
                Button("去设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("请在设置中允许访问相机以拍摄照片")
            }
            .onChange(of: viewModel.hapticEvent) { _, event in
                guard let event = event else { return }
                let generator = UINotificationFeedbackGenerator()
                switch event {
                case .success:
                    generator.notificationOccurred(.success)
                case .error:
                    generator.notificationOccurred(.error)
                case .warning:
                    generator.notificationOccurred(.warning)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        Group {
            if !viewModel.capturedPhotos.isEmpty {
                HStack {
                    Image(systemName: "photo.stack")
                        .foregroundStyle(.blue)
                    Text("已拍摄 \(viewModel.capturedPhotos.count) 张照片")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var photoGridView: some View {
        Group {
            if viewModel.capturedPhotos.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(viewModel.capturedPhotos.enumerated()), id: \.offset) { index, image in
                            PhotoThumbnailView(
                                image: image,
                                onTap: {
                                    viewModel.selectedImageIndex = index
                                },
                                onDelete: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        viewModel.removePhoto(at: index)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            // Take Photo Button
            Button(action: {
                viewModel.checkCameraPermission()
            }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("拍照")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Copy and Send Button
            if !viewModel.capturedPhotos.isEmpty {
                Button(action: {
                    viewModel.copyAndSend()
                }) {
                    HStack {
                        Image(systemName: "doc.on.clipboard.fill")
                        Text("复制并发送")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(transferManager.transferState.isInProgress)
            }
            
            // Clear All Button
            if !viewModel.capturedPhotos.isEmpty {
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        viewModel.clearPhotos()
                    }
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("清空全部")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
    }
    
    private var toastView: some View {
        Group {
            if viewModel.toastState.isVisible {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(viewModel.toastState.message)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 5)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 100)
                }
                .zIndex(100)
            }
        }
        .animation(.spring(), value: viewModel.toastState.isVisible)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            Text("还没有照片")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("点击下方按钮开始拍摄")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
}

// MARK: - Helper Types

/// Wrapper for Int to make it Identifiable
struct IdentifiableInt: Identifiable {
    let id: Int
}
#endif
