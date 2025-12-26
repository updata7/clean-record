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
                        
                        Button(action: { settings.beautyEnabled.toggle() }) {
                            Image(systemName: settings.beautyEnabled ? "face.smiling.fill" : "face.smiling")
                                .padding(6)
                                .background(settings.beautyEnabled ? Color.pink : Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Beauty Mode")

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
        
        // Match orientation if needed (not usually needed for webcam on Mac)
        
        if SettingsManager.shared.beautyEnabled {
            // Basic skin smoothing using Bilateral Filter
            let filter = CIFilter(name: "CIBilateralFilter")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(3.0, forKey: "inputRadius") // Small radius for subtlety
            filter?.setValue(0.02, forKey: "inputSoftness")
            
            if let outputImage = filter?.outputImage {
                ciImage = outputImage
            }
        }
        
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
