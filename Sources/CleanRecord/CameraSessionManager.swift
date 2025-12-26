import AVFoundation
import CoreImage
import AppKit

class CameraSessionManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    static let shared = CameraSessionManager()
    
    private let session = AVCaptureSession()
    private let context = CIContext(options: [.workingColorSpace: NSNull()])
    private let output = AVCaptureVideoDataOutput()
    
    // We'll notify listeners (the views) when a new frame is processed
    var onFrameUpdate: ((CGImage) -> Void)?
    
    private override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        session.sessionPreset = .medium
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            print("CameraSessionManager: No camera device found.")
            return
        }
        
        if session.canAddInput(input) { session.addInput(input) }
        
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.cleanrecord.camera.session", qos: .userInteractive))
        if session.canAddOutput(output) { session.addOutput(output) }
    }
    
    func start() {
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }
    
    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        let settings = SettingsManager.shared
        if settings.beautyEnabled && settings.beautyLevel > 0 {
            let filter = CIFilter(name: "CIBilateralFilter")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            
            // Aggressive mapping for visible impact at 100%
            let level = settings.beautyLevel
            // radius: 1.0 to 100.0 (high radius = more area smoothed)
            // softness: 0.01 to 0.5 (high softness = smoother skin)
            let radius = 1.0 + (level * 99.0)
            let softness = 0.01 + (level * 0.49)
            
            filter?.setValue(radius, forKey: "inputRadius")
            filter?.setValue(softness, forKey: "inputSoftness")
            
            if let outputImage = filter?.outputImage {
                ciImage = outputImage
            }
        }
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            onFrameUpdate?(cgImage)
        }
    }
}
