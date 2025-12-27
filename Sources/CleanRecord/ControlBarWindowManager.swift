import AppKit
import SwiftUI

@MainActor
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
        
        // Center horizontally relative to the selection
        let windowWidth: CGFloat = 280
        let windowHeight: CGFloat = 50
        let x = point.x + (width - windowWidth) / 2
        
        // Position the control bar above the bottom of the screen
        // If point.y is at bottom (0 or low), place it higher up
        var y = point.y + 100 // Place it 100 pixels above the bottom point
        
        // Make sure it's not off the top of the screen
        if let screen = NSScreen.main {
            let maxY = screen.frame.height - windowHeight - 20
            if y > maxY {
                y = maxY
            }
        }
        
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
