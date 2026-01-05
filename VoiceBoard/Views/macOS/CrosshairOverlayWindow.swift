//
//  CrosshairOverlayWindow.swift
//  VoiceBoard
//
//  Transparent overlay window for setting click position (macOS only)
//

#if os(macOS)
import SwiftUI
import AppKit

/// Manager for showing crosshair overlay window
class CrosshairWindowManager {
    
    static let shared = CrosshairWindowManager()
    
    private var overlayWindow: NSPanel?
    private var overlayScreen: NSScreen?
    private var onPositionSelected: ((CGPoint) -> Void)?
    
    private init() {}
    
    /// Show crosshair overlay for position selection
    /// - Parameters:
    ///   - initialPosition: Initial position of crosshair (optional)
    ///   - completion: Called with selected position when user clicks
    func showCrosshair(initialPosition: CGPoint? = nil, completion: @escaping (CGPoint) -> Void) {
        // Close existing window if any
        closeCrosshair()
        
        onPositionSelected = completion
        
        // Get the screen where mouse is located (for multi-monitor support)
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let screen = targetScreen else { return }
        
        overlayScreen = screen
        
        // Create borderless, transparent panel on the target screen
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        panel.ignoresMouseEvents = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Calculate center position relative to this screen
        let centerX = screen.frame.width / 2
        let centerY = screen.frame.height / 2
        let startPosition = initialPosition ?? CGPoint(x: centerX, y: centerY)
        
        // Set up SwiftUI content
        let contentView = NSHostingView(
            rootView: CrosshairOverlayView(
                initialPosition: startPosition,
                screenFrame: screen.frame,
                onPositionConfirmed: { [weak self] position in
                    self?.handlePositionSelected(position)
                },
                onCancel: { [weak self] in
                    self?.closeCrosshair()
                }
            )
        )
        
        panel.contentView = contentView
        panel.setFrame(screen.frame, display: true)
        panel.makeKeyAndOrderFront(nil)
        
        overlayWindow = panel
    }
    
    /// Close crosshair overlay
    func closeCrosshair() {
        overlayWindow?.close()
        overlayWindow = nil
        onPositionSelected = nil
    }
    
    private func handlePositionSelected(_ position: CGPoint) {
        let callback = onPositionSelected
        closeCrosshair()
        callback?(position)
    }
}

// MARK: - SwiftUI Overlay View

struct CrosshairOverlayView: View {
    let initialPosition: CGPoint
    let screenFrame: CGRect
    let onPositionConfirmed: (CGPoint) -> Void
    let onCancel: () -> Void
    
    @State private var crosshairPosition: CGPoint
    @State private var isDragging = false
    
    init(initialPosition: CGPoint, screenFrame: CGRect, onPositionConfirmed: @escaping (CGPoint) -> Void, onCancel: @escaping () -> Void) {
        self.initialPosition = initialPosition
        self.screenFrame = screenFrame
        self.onPositionConfirmed = onPositionConfirmed
        self.onCancel = onCancel
        self._crosshairPosition = State(initialValue: initialPosition)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background - click to cancel
                Color.black.opacity(0.01)
                    .onTapGesture {
                        onCancel()
                    }
                
                // Instructions panel at top
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("拖动准心到目标位置")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("点击空白处取消 | 松开鼠标确认位置")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.7))
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 50)
                
                // Crosshair
                CrosshairShape()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 20, height: 20)
                    )
                    .position(crosshairPosition)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                crosshairPosition = value.location
                            }
                            .onEnded { value in
                                isDragging = false
                                // Convert to global screen coordinates for CGEvent
                                let screenPoint = convertToGlobalScreenCoordinate(value.location)
                                onPositionConfirmed(screenPoint)
                            }
                    )
                
                // Position indicator
                VStack {
                    Spacer()
                    HStack {
                        Text("位置: (\(Int(crosshairPosition.x)), \(Int(crosshairPosition.y)))")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                            )
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .ignoresSafeArea()
    }
    
    /// Convert from overlay-local coordinate to global CGEvent coordinate
    private func convertToGlobalScreenCoordinate(_ localPoint: CGPoint) -> CGPoint {
        // CGEvent uses a coordinate system where:
        // - Origin is at top-left of the PRIMARY screen (main display)
        // - Y increases downward
        
        // Get primary screen height for coordinate conversion
        guard let primaryScreen = NSScreen.screens.first else {
            return localPoint
        }
        
        let primaryHeight = primaryScreen.frame.height
        
        // Convert local Y (top-left origin within overlay) to global coordinates
        // screenFrame.origin gives us the screen's position in global NSScreen coordinates
        // NSScreen uses bottom-left origin, CGEvent uses top-left origin
        
        // Global X = screenFrame.origin.x + localPoint.x
        let globalX = screenFrame.origin.x + localPoint.x
        
        // For Y: In NSScreen, origin is at bottom-left of primary screen
        // screenFrame.origin.y is the bottom of this screen relative to primary bottom
        // We need to convert to CGEvent coordinate (top-left origin, Y down)
        // globalY = primaryHeight - (screenFrame.origin.y + screenFrame.height) + localPoint.y
        let screenTopInNSCoord = screenFrame.origin.y + screenFrame.height
        let globalY = primaryHeight - screenTopInNSCoord + localPoint.y
        
        return CGPoint(x: globalX, y: globalY)
    }
}

// MARK: - Crosshair Shape

struct CrosshairShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * 0.3
        
        // Horizontal line
        path.move(to: CGPoint(x: center.x - radius, y: center.y))
        path.addLine(to: CGPoint(x: center.x - innerRadius, y: center.y))
        path.move(to: CGPoint(x: center.x + innerRadius, y: center.y))
        path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        
        // Vertical line
        path.move(to: CGPoint(x: center.x, y: center.y - radius))
        path.addLine(to: CGPoint(x: center.x, y: center.y - innerRadius))
        path.move(to: CGPoint(x: center.x, y: center.y + innerRadius))
        path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        
        // Center circle
        path.addEllipse(in: CGRect(
            x: center.x - innerRadius,
            y: center.y - innerRadius,
            width: innerRadius * 2,
            height: innerRadius * 2
        ))
        
        return path
    }
}

// MARK: - NSRect Extension

extension NSRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
#endif
