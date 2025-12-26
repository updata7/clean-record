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
        // Create a clear window that ignores mouse events but draws a border
        // We need to match screen coordinates.
        // For MVP we assume rect is in screen coordinates (bottom-left origin for NSWindow).
        
        let overlayWindow = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        overlayWindow.isReleasedWhenClosed = false
        overlayWindow.backgroundColor = .clear
        overlayWindow.level = .floating
        overlayWindow.ignoresMouseEvents = true // Pass through clicks
        
        // Custom view to draw the border
        let borderView = BorderView(frame: NSRect(x: 0, y: 0, width: rect.width, height: rect.height))
        overlayWindow.contentView = borderView
        
        self.window = overlayWindow
    }
}

class BorderView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        dirtyRect.fill()
        
        let path = NSBezierPath(rect: bounds)
        path.lineWidth = 4
        NSColor.red.setStroke()
        path.stroke()
        
        // Dashed line or simple red line? CleanShot uses simple line or dashed. Red is standard.
    }
}
