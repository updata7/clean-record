import AppKit
import SwiftUI

@MainActor
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
        // Default base size 200x200
        let settings = SettingsManager.shared
        let baseSize: CGFloat = 200
        let scale = CGFloat(settings.cameraScale)
        let width = baseSize * scale
        let height = (settings.cameraShape == "rectangle" ? 150 : 200) * scale
        
        // Use lastRecordingRect for initial placement (bottom-left)
        var origin = CGPoint(x: 100, y: 100) // Fallback
        if let rect = settings.lastRecordingRect {
            origin = CGPoint(x: rect.minX, y: rect.minY)
        }
        
        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: CGSize(width: width, height: height)),
            styleMask: [.borderless, .resizable, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true
        panel.hasShadow = false
        self.window = panel
    }
}
