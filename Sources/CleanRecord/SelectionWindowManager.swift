import AppKit
import SwiftUI

@MainActor
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
            onConfirm: { [weak self] rect in
                // Rect is coming in SwiftUI coordinates (0,0 top-left) relative to the screen.
                // We need to convert it to Cocoa (0,0 bottom-left) for NSWindow / RecordingBorder.
                
                let screenHeight = screen.frame.height
                let cocoaY = screenHeight - rect.maxY
                let cocoaRect = CGRect(x: rect.minX, y: cocoaY, width: rect.width, height: rect.height).integral
                
                print("SelectionWindowManager: Converted SwiftUI \(rect) to Cocoa \(cocoaRect) (screenHeight: \(screenHeight))")
                
                self?.closeWindow()
                self?.onCapture?(cocoaRect)
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
