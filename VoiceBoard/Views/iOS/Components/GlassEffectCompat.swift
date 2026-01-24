//
//  GlassEffectCompat.swift
//  VoiceBoard
//
//  iOS 26 Liquid Glass compatibility layer
//  Falls back to traditional styling on iOS 25 and earlier
//

#if os(iOS)
import SwiftUI

// MARK: - Glass Effect Compatibility Extension

extension View {
    /// Applies Liquid Glass effect on iOS 26+, falls back to traditional styling on earlier versions
    /// - Parameters:
    ///   - tintColor: The tint color for the glass effect
    ///   - cornerRadius: Corner radius for the shape
    ///   - fallbackColor: Background color to use on iOS 25 and earlier
    /// - Returns: Modified view with appropriate styling
    @ViewBuilder
    func compatGlassEffect(
        tint tintColor: Color = .clear,
        cornerRadius: CGFloat = 10,
        fallbackColor: Color = Color(.systemGray6)
    ) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tintColor), in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(fallbackColor)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
    
    /// Applies Liquid Glass capsule effect on iOS 26+, falls back to material on earlier versions
    /// - Parameter tintColor: The tint color for the glass effect
    /// - Returns: Modified view with appropriate styling
    @ViewBuilder
    func compatGlassCapsule(tint tintColor: Color = .clear) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tintColor), in: .capsule)
        } else {
            self
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Styled Button with Glass Effect

/// A styled button that uses Liquid Glass on iOS 26+ with native bouncy feel
/// Falls back to traditional styling on earlier versions
struct GlassButton: View {
    let title: String
    let icon: String
    let color: Color
    let disabled: Bool
    let action: () -> Void
    
    var body: some View {
        if #available(iOS 26.0, *) {
            // iOS 26: Use native Button with glassEffect for built-in bouncy feel
            Button(action: action) {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .frame(height: 24)
                    Text(title)
                        .font(.caption2)
                        .frame(height: 14)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(disabled ? .secondary : .primary)
            }
            .buttonStyle(.glassProminent)
            .tint(disabled ? .gray : color)
            .disabled(disabled)
        } else {
            // iOS 18-25: Fallback to traditional styling
            Button(action: action) {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .frame(height: 24)
                    Text(title)
                        .font(.caption2)
                        .frame(height: 14)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(disabled ? .secondary : color)
                .background(disabled ? Color(.systemGray5) : color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(disabled)
        }
    }
}

// MARK: - Glass Action Button (for PhotoPicker style buttons)

/// Full-width action button with native glass styling on iOS 26+
struct GlassActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let disabled: Bool
    let action: () -> Void
    
    init(
        title: String,
        icon: String,
        color: Color,
        isLoading: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isLoading = isLoading
        self.disabled = disabled
        self.action = action
    }
    
    var body: some View {
        if #available(iOS 26.0, *) {
            // iOS 26: Native glass button with built-in bouncy feel
            Button(action: action) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: icon)
                    }
                    Text(title)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.glassProminent)
            .tint(disabled ? .gray : color)
            .disabled(disabled)
        } else {
            // iOS 18-25: Traditional styling
            Button(action: action) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: icon)
                    }
                    Text(title)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(.white)
                .background(disabled ? .gray : color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(disabled)
        }
    }
}

#endif
