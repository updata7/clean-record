import AppKit
import SwiftUI

class CameraOverlayManager {
    static let shared = CameraOverlayManager()
    
    private var window: NSPanel?
    
    func showCamera() {
        if window == nil {
            createWindow()
        }
        
        let contentView = CameraOverlayView()
        window?.contentView = NSHostingView(rootView: contentView)
        window?.makeKeyAndOrderFront(nil)
    }
    
    func hideCamera() {
        window?.close()
        window = nil
    }
    
    private func createWindow() {
        // Default size 200x200
        let panel = NSPanel(
            contentRect: NSRect(x: 100, y: 100, width: 200, height: 200),
            styleMask: [.borderless, .resizable, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true
        panel.hasShadow = false // shadow handled by view
        self.window = panel
    }
}
