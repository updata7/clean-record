import SwiftUI
import AVFoundation

struct CameraOverlayView: View {
    @ObservedObject var settings = SettingsManager.shared
    
    var body: some View {
        ZStack {
            // Camera Content
            Group {
                if settings.cameraShape == "circle" {
                    CameraPreview()
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2))
                } else if settings.cameraShape == "square" {
                    CameraPreview()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.8), lineWidth: 2))
                } else {
                    CameraPreview()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.8), lineWidth: 2))
                }
            }
            .shadow(radius: 10)
        }
        .frame(width: 200 * CGFloat(settings.cameraScale), 
               height: (settings.cameraShape == "rectangle" ? 150 : 200) * CGFloat(settings.cameraScale))
        .onAppear {
            CameraSessionManager.shared.start()
        }
        .onDisappear {
            CameraSessionManager.shared.stop()
        }
    }
}

// MARK: - Premium UI Components

struct CameraPreview: NSViewRepresentable {
    func makeNSView(context: Context) -> FilteredCameraView {
        let view = FilteredCameraView()
        return view
    }
    
    func updateNSView(_ nsView: FilteredCameraView, context: Context) {}
}

class FilteredCameraView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.contentsGravity = .resizeAspectFill
        
        CameraSessionManager.shared.onFrameUpdate = { [weak self] cgImage in
            DispatchQueue.main.async {
                self?.layer?.contents = cgImage
            }
        }
    }
    
    required init?(coder: NSCoder) { fatalError() }
}
