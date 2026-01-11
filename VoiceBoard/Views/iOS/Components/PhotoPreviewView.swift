//
//  PhotoPreviewView.swift
//  VoiceBoard
//

import SwiftUI

struct PhotoPreviewView: View {
    let images: [UIImage]
    let initialIndex: Int
    let onClose: () -> Void
    
    @State private var currentIndex: Int
    
    init(images: [UIImage], initialIndex: Int, onClose: @escaping () -> Void) {
        self.images = images
        self.initialIndex = initialIndex
        self.onClose = onClose
        _currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.edgesIgnoringSafeArea(.all)
            
            TabView(selection: $currentIndex) {
                ForEach(0..<images.count, id: \.self) { index in
                    Image(uiImage: images[index])
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .tag(index)
                        .pinchToZoom()
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            
            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
                    .padding()
            }
            .padding(.top, 40) // Adjust for status bar
        }
    }
}

// Pinch to zoom helper modifier
struct PinchToZoomModifier: ViewModifier {
    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(currentScale)
            .gesture(
                MagnificationGesture()
                    .onChanged { newScale in
                        currentScale = max(1.0, finalScale * newScale)
                    }
                    .onEnded { scale in
                        finalScale = 1.0
                        withAnimation {
                            currentScale = 1.0
                        }
                    }
            )
    }
}

extension View {
    func pinchToZoom() -> some View {
        modifier(PinchToZoomModifier())
    }
}
