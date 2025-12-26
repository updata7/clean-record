import AppKit
import SwiftUI

@MainActor
class OverlayWindowManager {
    static let shared = OverlayWindowManager()
    
    private var window: NSPanel?
    
    func showOverlay(with image: NSImage) {
        if window == nil {
            createWindow()
        }
        
        // Update content
        let contentView = OverlayView(image: image, onClose: { [weak self] in
            self?.closeWindow()
        })
        
        window?.contentView = NSHostingView(rootView: contentView)
        
        // Position bottom right or based on preferences
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowSize = window?.frame.size ?? CGSize(width: 200, height: 150) // estimated
            let x = screenRect.maxX - windowSize.width - 20
            let y = screenRect.minY + 20
            
            window?.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window?.makeKeyAndOrderFront(nil)
    }
    
    private func createWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 160),
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true // Allow dragging the whole window
        
        self.window = panel
    }
    
    private func closeWindow() {
        window?.close()
        window = nil
    }
}
