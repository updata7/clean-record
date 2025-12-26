import AppKit
import SwiftUI

class ControlBarWindowManager {
    static let shared = ControlBarWindowManager()
    
    private var window: NSPanel?
    
    func showControlBar(at point: CGPoint, width: CGFloat, onStart: @escaping () -> Void, onCancel: @escaping () -> Void) {
        if window == nil {
            createWindow()
        }
        
        let contentView = ControlBarView(
            onStart: {
                onStart()
            },
            onCancel: { [weak self] in
                self?.closeWindow()
                onCancel()
            }
        )
        
        window?.contentView = NSHostingView(rootView: contentView)
        
        // Center horizontally relative to the selection, below it
        let windowWidth: CGFloat = 280 // Estimated width
        let x = point.x + (width - windowWidth) / 2
        let y = point.y - 60 // Below the rect (rect origin is bottom-left usually?)
        // We'll trust the caller passes a good point (bottom-center of selection)
        
        window?.setFrameOrigin(NSPoint(x: x, y: y))
        window?.makeKeyAndOrderFront(nil)
    }
    
    func closeWindow() {
        window?.close()
        window = nil
    }
    
    private func createWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 50),
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true
        self.window = panel
    }
}
