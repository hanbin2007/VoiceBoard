//
//  ImageTransferToastView.swift
//  VoiceBoard
//
//  SwiftUI view for the image transfer progress toast on macOS
//

#if os(macOS)
import SwiftUI

/// Floating toast view showing image transfer progress
struct ImageTransferToastView: View {
    @ObservedObject var manager: ImageTransferToastManager
    
    var body: some View {
        HStack(spacing: 12) {
            // State icon
            stateIcon
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                
                // Progress bar (if applicable)
                if let progressValue = progress {
                    ProgressView(value: progressValue)
                        .progressViewStyle(.linear)
                        .frame(width: 180)
                        .tint(progressTint)
                }
                
                // Subtitle
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .background(backgroundTint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - State Icon
    
    @ViewBuilder
    private var stateIcon: some View {
        switch manager.currentState {
        case .idle:
            EmptyView()
            
        case .receiving, .processing, .pasting:
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 28, height: 28)
            
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
            
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.red)
                .transition(.scale.combined(with: .opacity))
        }
    }
    
    // MARK: - Title
    
    private var title: String {
        switch manager.currentState {
        case .idle:
            return ""
        case .receiving(let count, _):
            return "正在接收 \(count) 张图片..."
        case .processing(let current, let total):
            return "正在处理图片 \(current)/\(total)"
        case .pasting:
            return "正在粘贴图片..."
        case .completed:
            return "图片传输完成"
        case .failed:
            return "传输失败"
        }
    }
    
    // MARK: - Subtitle
    
    private var subtitle: String {
        switch manager.currentState {
        case .idle:
            return ""
        case .receiving(_, let progress):
            if let progress = progress {
                return "已完成 \(Int(progress * 100))%"
            }
            return "请稍候..."
        case .processing(let current, let total):
            return "已处理 \(current)/\(total)"
        case .pasting:
            return "即将完成"
        case .completed(let count):
            return "已粘贴 \(count) 张图片到当前位置"
        case .failed(let message):
            return message
        }
    }
    
    // MARK: - Progress
    
    private var progress: Double? {
        switch manager.currentState {
        case .receiving(_, let progress):
            return progress
        case .processing(let current, let total):
            return Double(current) / Double(max(total, 1))
        default:
            return nil
        }
    }
    
    // MARK: - Colors
    
    private var progressTint: Color {
        switch manager.currentState {
        case .completed:
            return .green
        case .failed:
            return .red
        default:
            return .blue
        }
    }
    
    private var backgroundTint: Color {
        switch manager.currentState {
        case .completed:
            return .green
        case .failed:
            return .red
        default:
            return .clear
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Preview different states
        ImageTransferToastView(manager: {
            let m = ImageTransferToastManager.shared
            return m
        }())
    }
    .padding(40)
    .background(Color.gray.opacity(0.2))
}
#endif
