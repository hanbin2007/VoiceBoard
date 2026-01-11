//
//  PhotoThumbnailView.swift
//  VoiceBoard
//

import SwiftUI

struct PhotoThumbnailView: View {
    let image: UIImage
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture(perform: onTap)
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.red))
            }
            .padding(8)
        }
    }
}
