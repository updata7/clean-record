import AppKit
import SwiftUI

@MainActor
class RecordingBorderManager {
    static let shared = RecordingBorderManager()
    public var window: NSWindow?
    
    func showBorder(for rect: CGRect) {
        if window == nil {
            createWindow(rect: rect)
        } else {
            window?.setFrame(rect, display: true)
        }
        window?.makeKeyAndOrderFront(nil)
    }
    
    func hideBorder() {
        window?.close()
        window = nil
    }
    
    private func createWindow(rect: CGRect) {
        let overlayWindow = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        overlayWindow.isReleasedWhenClosed = false
        overlayWindow.backgroundColor = .clear
        overlayWindow.level = .floating
        overlayWindow.ignoresMouseEvents = false // Allow dragging the border
        
        let hostingView = NSHostingView(rootView: MovableBorderView(rect: rect))
        overlayWindow.contentView = hostingView
        
        self.window = overlayWindow
    }
}

struct MovableBorderView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var dragStartingOrigin: CGPoint?
    let rect: CGRect
    
    var body: some View {
        Rectangle()
            .stroke(Color.red, lineWidth: 4)
            .contentShape(Rectangle().stroke(lineWidth: 10)) // Make the edge draggable
            .background(Color.black.opacity(0.001)) // Subtle background for middle-dragging
            .gesture(
                DragGesture()
                    .onChanged { value in
                        moveWindow(translation: value.translation)
                    }
                    .onEnded { _ in
                        dragStartingOrigin = nil
                    }
            )
    }
    
    private func moveWindow(translation: CGSize) {
        guard let window = RecordingBorderManager.shared.window else { return }
        
        if dragStartingOrigin == nil {
            dragStartingOrigin = window.frame.origin
        }
        
        if let start = dragStartingOrigin {
            var newOrigin = start
            newOrigin.x += translation.width
            newOrigin.y -= translation.height
            
            let newFrame = NSRect(origin: newOrigin, size: window.frame.size)
            window.setFrame(newFrame, display: true)
            
            // Sync with settings and recorder
            settings.lastRecordingRect = newFrame
            if RecorderManager.shared.isRecording {
                RecorderManager.shared.updateCaptureRect(newFrame)
            }
            
            // Also move control bar and whiteboard if needed
            ControlBarWindowManager.shared.updatePosition(for: newFrame)
            if settings.whiteboardEnabled {
                WhiteboardWindowManager.shared.showWhiteboard() // This will update position
            }
        }
    }
}
