import AppKit
import SwiftUI
import Combine

@MainActor
class CameraOverlayManager {
    static let shared = CameraOverlayManager()
    
    private var window: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    
    func showCamera() {
        if window == nil {
            createWindow()
            setupObservations()
        }
        
        let contentView = CameraOverlayView()
        window?.contentView = NSHostingView(rootView: contentView)
        window?.makeKeyAndOrderFront(nil)
    }
    
    func hideCamera() {
        window?.close()
        window = nil
        cancellables.removeAll()
    }
    
    private func createWindow() {
        let settings = SettingsManager.shared
        let size = calculateSize(scale: settings.cameraScale, shape: settings.cameraShape)
        
        // Use lastRecordingRect for initial placement (bottom-right with 20px padding)
        var origin = CGPoint(x: 100, y: 100) // Fallback
        if let rect = settings.lastRecordingRect {
            origin = CGPoint(x: rect.maxX - size.width - 20, y: rect.minY + 20)
        }
        
        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: CGSize(width: size.width, height: size.height)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .statusBar // Ensure it's above the whiteboard
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = false // Allow it to become key if clicked
        
        // Ensure gestures can reach it
        self.window = panel
    }
    
    private func setupObservations() {
        let settings = SettingsManager.shared
        
        // Combine scale and shape updates
        Publishers.CombineLatest(settings.$cameraScale, settings.$cameraShape)
            .receive(on: RunLoop.main)
            .sink { [weak self] scale, shape in
                guard let self = self, let window = self.window else { return }
                
                let newSize = self.calculateSize(scale: scale, shape: shape)
                var currentFrame = window.frame
                
                // Keep the center or top-left anchored depending on preference.
                // For a floating camera, anchoring the center is usually best.
                let deltaWidth = newSize.width - currentFrame.width
                let deltaHeight = newSize.height - currentFrame.height
                
                currentFrame.origin.x -= deltaWidth / 2
                currentFrame.origin.y -= deltaHeight / 2
                currentFrame.size = newSize
                
                window.setFrame(currentFrame, display: true, animate: false)
            }
            .store(in: &cancellables)
    }
    
    private func calculateSize(scale: Double, shape: String) -> CGSize {
        let baseSize: CGFloat = 200
        let scaleFloat = CGFloat(scale)
        let width = baseSize * scaleFloat
        let height = (shape == "rectangle" ? 150 : 200) * scaleFloat
        // Add padding for the resize handle shadow and hover effects
        return CGSize(width: width + 20, height: height + 20)
    }
}
