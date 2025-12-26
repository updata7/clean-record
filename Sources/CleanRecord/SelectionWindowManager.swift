import AppKit
import SwiftUI

class SelectionWindowManager: NSObject {
    static let shared = SelectionWindowManager()
    
    private var window: NSWindow?
    private var onCapture: ((CGRect) -> Void)?
    
    func startSelection(completion: @escaping (CGRect) -> Void) {
        self.onCapture = completion
        
        // Create a window that covers the entire screen
        // In a multi-screen setup, we should cover the screen with the mouse or all screens.
        // For MVP, Main Screen.
        guard let screen = NSScreen.main else { return }
        
        let newWindow = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.isReleasedWhenClosed = false
        newWindow.backgroundColor = .clear
        newWindow.level = .screenSaver // High level to sit above menu bar and dock
        newWindow.ignoresMouseEvents = false
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Create the SwiftUI view
        let rootView = SelectionOverlayView(
            selectionRect: .constant(nil),
            onConfirm: { [weak self] rect in
                // Coordinate conversion:
                // SwiftUI coordinates (0,0 top-left) usually match window content rect which matches screen frame (bottom-left origin in Cocoa, but SwiftUI abstracts this usually).
                // However, CGWindowListCreateImage needs global display coordinates.
                // If the window fills the screen, the point (x, y) in the view corresponds to (x, y) on that screen.
                // One catch: Cocoa uses bottom-left (0,0). SwiftUI usually top-left.
                // We need to convert SwiftUI rect to CG rect.
                
                let screenHeight = screen.frame.height
                // Flip Y for Cocoa/CG if needed. BUT, CGWindowListCreateImage (flipped: false usually?).
                // Actually CG coordinates are top-left (0,0) for display bounds usually in modern logical coordinates?
                // Wait, CoreGraphics logic: Main display origin (0,0) is top-left.
                // AppKit logic: (0,0) is bottom-left.
                // SwiftUI: (0,0) is top-left.
                // So if we take SwiftUI rect, it matches CG logic (mostly).
                
                // Let's assume direct mapping for now and debug if flipped.
                
                // Convert rect to global screen coordinates (adding result to window origin if window wasn't at 0,0)
                let globalRect = rect.offsetBy(dx: newWindow.frame.origin.x, dy: 0)
                // Y-coordinate needs care if screen origin is not 0,0 or handling multi-monitors.
                
                self?.closeWindow()
                self?.onCapture?(globalRect)
            },
            onCancel: { [weak self] in
                self?.closeWindow()
            }
        )
        
        newWindow.contentView = NSHostingView(rootView: rootView)
        newWindow.makeKeyAndOrderFront(nil)
        self.window = newWindow
        
        // Activate app to ensure it captures events
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func closeWindow() {
        window?.close()
        window = nil
    }
}
