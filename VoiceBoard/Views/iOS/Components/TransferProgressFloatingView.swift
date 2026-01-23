//
//  TransferProgressFloatingView.swift
//  VoiceBoard
//
//  Floating progress indicator that shows at the bottom of the main iOS view
//  during background image transfers
//

#if os(iOS)
import SwiftUI

/// Floating progress view shown at the bottom of iOSContentView during transfers
struct TransferProgressFloatingView: View {
    let state: PhotoTransferState
    
    var body: some View {
        HStack(spacing: 12) {
            // Progress indicator
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.9)
            
            VStack(alignment: .leading, spacing: 2) {
                // Status text
                Text(statusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                
                // Progress bar for compression or sending
                if let progress = progressValue {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(0.3))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white)
                                .frame(width: max(0, geometry.size.width * progress), height: 4)
                                .animation(.easeInOut(duration: 0.2), value: progress)
                        }
                    }
                    .frame(height: 4)
                }
            }
            
            Spacer()
            
            // Percentage text
            if let progress = progressValue {
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.blue), in: .rect(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        switch state {
        case .idle:
            return "准备中..."
        case .compressing(let progress):
            return "压缩照片中..."
        case .sending:
            return "发送中..."
        case .transferring(let current, let total, let progress):
            return "传输 \(current)/\(total)"
        case .completed(let count):
            return "已完成 \(count) 张"
        case .failed(let message):
            return "失败: \(message)"
        }
    }
    
    private var progressValue: Double? {
        switch state {
        case .compressing(let progress):
            return progress
        case .transferring(_, _, let progress):
            return progress
        default:
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        TransferProgressFloatingView(state: .compressing(progress: 0.45))
        TransferProgressFloatingView(state: .transferring(current: 2, total: 5, progress: 0.7))
        TransferProgressFloatingView(state: .sending)
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
#endif
