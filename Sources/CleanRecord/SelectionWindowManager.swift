import AppKit
import SwiftUI

@MainActor
class SelectionWindowManager: NSObject {
    static let shared = SelectionWindowManager()
    
    private var window: NSWindow?
    private var onCapture: ((CGRect) -> Void)?
    private var eventMonitor: Any?
    
    func startSelection(completion: @escaping (CGRect) -> Void) {
        self.onCapture = completion
        
        // Listen for ESC key to cancel
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                print("SelectionWindowManager: ESC pressed, cancelling selection.")
                self?.closeWindow()
                return nil // Swallow the event
            }
            return event
        }
        
        // Create a window that covers the entire screen
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
                
                // Give AppKit a moment to finish current event processing before transitioning
                DispatchQueue.main.async {
                    self?.closeWindow()
                    self?.onCapture?(cocoaRect)
                }
            },
            onCancel: { [weak self] in
                DispatchQueue.main.async {
                    self?.closeWindow()
                }
            }
        )
        
        newWindow.contentView = NSHostingView(rootView: rootView)
        newWindow.makeKeyAndOrderFront(nil)
        self.window = newWindow
        
        // Activate app to ensure it captures events
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func closeWindow() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        window?.close()
        window = nil
    }
}
