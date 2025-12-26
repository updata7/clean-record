import SwiftUI
import AVFoundation

struct CameraOverlayView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var isHovering = false
    
    @State private var currentMagnification: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Camera Shape
            Group {
                if settings.cameraShape == "circle" {
                    CameraPreview()
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                } else if settings.cameraShape == "square" {
                    CameraPreview()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white, lineWidth: 2))
                } else {
                    CameraPreview()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                }
            }
            .shadow(radius: 5)
            
            // Hover Controls
            if isHovering {
                VStack {
                    HStack(spacing: 8) {
                        Button(action: { settings.cameraShape = "circle" }) {
                            Image(systemName: "circle")
                                .padding(6)
                                .background(settings.cameraShape == "circle" ? Color.blue : Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { settings.cameraShape = "square" }) {
                            Image(systemName: "square")
                                .padding(6)
                                .background(settings.cameraShape == "square" ? Color.blue : Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { settings.cameraShape = "rectangle" }) {
                            Image(systemName: "rectangle")
                                .padding(6)
                                .background(settings.cameraShape == "rectangle" ? Color.blue : Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { 
                            settings.beautyLevel = (settings.beautyLevel + 1) % 4
                            settings.beautyEnabled = (settings.beautyLevel > 0)
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: settings.beautyLevel == 0 ? "face.smiling" : "face.smiling.fill")
                                if settings.beautyLevel > 0 {
                                    Text("\(settings.beautyLevel)")
                                        .font(.caption2.bold())
                                }
                            }
                            .padding(6)
                            .background(beautyColor(for: settings.beautyLevel))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help(beautyHelp(for: settings.beautyLevel))

                        Spacer()
                        
                        Button(action: { settings.cameraEnabled = false }) {
                            Image(systemName: "xmark")
                                .padding(6)
                                .background(Color.red.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundColor(.white)
                    .padding(8)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: { settings.cameraScale = max(settings.cameraScale - 0.1, 0.2) }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        
                        Text("\(Int(settings.cameraScale * 100))%")
                            .font(.caption2.bold())
                            .frame(width: 40)
                        
                        Button(action: { settings.cameraScale = min(settings.cameraScale + 0.1, 10.0) }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(width: 200 * settings.cameraScale * currentMagnification, 
               height: (settings.cameraShape == "rectangle" ? 150 : 200) * settings.cameraScale * currentMagnification)
        .contentShape(Rectangle()) 
        .onHover { hover in
            withAnimation { isHovering = hover }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    // value is the delta multiplier since the start of the gesture
                    self.currentMagnification = value
                }
                .onEnded { value in
                    // Commit the final scale
                    settings.cameraScale = min(max(settings.cameraScale * value, 0.2), 10.0)
                    self.currentMagnification = 1.0
                }
        )
    }
    
    private func beautyColor(for level: Int) -> Color {
        switch level {
        case 1: return .green.opacity(0.8)
        case 2: return .blue.opacity(0.8)
        case 3: return .pink.opacity(0.8)
        default: return .black.opacity(0.6)
        }
    }
    
    private func beautyHelp(for level: Int) -> String {
        switch level {
        case 1: return "Beauty: Natural"
        case 2: return "Beauty: Smooth"
        case 3: return "Beauty: Glamour"
        default: return "Beauty: Off"
        }
    }
}

struct CameraPreview: NSViewRepresentable {
    func makeNSView(context: Context) -> FilteredCameraView {
        let view = FilteredCameraView()
        return view
    }
    
    func updateNSView(_ nsView: FilteredCameraView, context: Context) {}
}

class FilteredCameraView: NSView, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let context = CIContext(options: [.workingColorSpace: NSNull()])
    private var beautyFilter: CIFilter?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.contentsGravity = .resizeAspectFill
        setupSession()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupSession() {
        session.sessionPreset = .medium
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if session.canAddInput(input) { session.addInput(input) }
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.cleanrecord.camera.filter"))
        if session.canAddOutput(output) { session.addOutput(output) }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        let settings = SettingsManager.shared
        if settings.beautyEnabled {
            let filter = CIFilter(name: "CIBilateralFilter")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            
            // Scaled parameters based on beautyLevel
            switch settings.beautyLevel {
            case 1: // Natural
                filter?.setValue(2.0, forKey: "inputRadius")
                filter?.setValue(0.015, forKey: "inputSoftness")
            case 2: // Smooth
                filter?.setValue(4.0, forKey: "inputRadius")
                filter?.setValue(0.03, forKey: "inputSoftness")
            case 3: // Glamour
                filter?.setValue(7.0, forKey: "inputRadius")
                filter?.setValue(0.06, forKey: "inputSoftness")
            default: break
            }
            
            if let outputImage = filter?.outputImage {
                ciImage = outputImage
            }
        }
        
        // Ensure aspect ratio is preserved during rendering
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            DispatchQueue.main.async { [weak self] in
                self?.layer?.contents = cgImage
            }
        }
    }
    
    deinit {
        session.stopRunning()
    }
}
