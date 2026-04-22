import AppKit
import SwiftUI

@MainActor
class ControlBarWindowManager {
    static let shared = ControlBarWindowManager()
    
    var window: NSPanel?
    private var eventMonitor: Any?
    
    func showControlBar(at point: CGPoint, width: CGFloat, onStart: @escaping () -> Void, onStop: @escaping () -> Void, onCancel: @escaping () -> Void) {
        if window == nil {
            createWindow()
        }
        
        // Listen for ESC to cancel if NOT recording
        if eventMonitor == nil {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { // ESC
                    if !RecorderManager.shared.isRecording {
                        print("ControlBarWindowManager: ESC pressed, cancelling.")
                        self?.closeWindow()
                        onCancel()
                        return nil
                    }
                }
                return event
            }
        }
        
        let contentView = ControlBarView(
            onStart: {
                onStart()
            },
            onStop: {
                onStop()
            },
            onCancel: { [weak self] in
                self?.closeWindow()
                onCancel()
            }
        )
        
        if let existingHosting = window?.contentView as? NSHostingView<ControlBarView> {
            existingHosting.rootView = contentView
        } else {
            let hostingView = NSHostingView(rootView: contentView)
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = .clear
            hostingView.layer?.isOpaque = false
            window?.contentView = hostingView
        }
        
        // Dimensions for the window (larger than capsule to avoid shadow clipping)
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 100
        let x = point.x + (width - windowWidth) / 2
        
        // Position the control bar above the bottom of the screen
        var y = point.y + 100
        
        if let screen = NSScreen.main {
            let maxY = screen.frame.height - windowHeight - 20
            if y > maxY {
                y = maxY
            }
        }
        
        window?.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        window?.makeKeyAndOrderFront(nil)
    }
    
    func closeWindow() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        window?.close()
        window = nil
    }
    
    private func createWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        self.window = panel
    }
}
