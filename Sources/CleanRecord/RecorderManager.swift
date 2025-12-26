import Foundation
import ScreenCaptureKit
import AVFoundation

@available(macOS 12.3, *)
class RecorderManager: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, SCStreamDelegate {
    static let shared = RecorderManager()
    
    private var stream: SCStream?
    private var videoWriter: VideoWriter?
    private var audioSession: AVCaptureSession?
    private var isRecording = false
    
    // Dedicated queue for video samples to prevent blocking Main thread
    private let videoSampleQueue = DispatchQueue(label: "com.cleanrecord.video.samples", qos: .userInitiated)
    
    func startRecording(rect: CGRect? = nil, captureAudio: Bool = false, completion: @escaping (Result<Void, Error>) -> Void) {
        print("RecorderManager: startRecording requested. rect=\(String(describing: rect)), captureAudio=\(captureAudio)")
        
        // Check for Screen Recording permission (macOS 10.15+)
        if #available(macOS 10.15, *) {
            let canRecord = CGPreflightScreenCaptureAccess()
            print("RecorderManager: CGPreflightScreenCaptureAccess = \(canRecord)")
            if !canRecord {
                print("RecorderManager ERROR: No Screen Recording permission!")
                // Don't fail immediately, but log it clearly
            }
        }
        
        Task {
            do {
                let scContent = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                guard let display = scContent.displays.first else {
                    print("RecorderManager Error: No displays found.")
                    completion(.failure(NSError(domain: "RecorderManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No displays found"])))
                    return
                }
                
                print("RecorderManager: Selected display: \(display.displayID), size: \(display.width)x\(display.height)")
                
                let streamConfig = SCStreamConfiguration()
                streamConfig.width = Int(rect?.width ?? CGFloat(display.width)) * 2
                streamConfig.height = Int(rect?.height ?? CGFloat(display.height)) * 2
                
                if let rect = rect {
                    let displayHeight = CGFloat(display.height)
                    let flippedY = displayHeight - rect.maxY
                    let scRect = CGRect(x: rect.minX, y: flippedY, width: rect.width, height: rect.height)
                    streamConfig.sourceRect = scRect
                    print("RecorderManager: Using flipped sourceRect: \(scRect) (orig: \(rect), displayHeight: \(displayHeight))")
                } else {
                    print("RecorderManager: Recording full screen.")
                }
                
                streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)
                streamConfig.queueDepth = 5
                
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
                self.stream = stream
                
                // Audio (Microphone)
                if captureAudio {
                    self.setupAudioCapture()
                }
                
                let outputDir = SettingsManager.shared.outputDirectory
                let fileName = "Recording \(Date().formatted(date: .numeric, time: .standard)).mp4"
                    .replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: ":", with: ".")
                
                let fileURL = outputDir.appendingPathComponent(fileName)
                
                // Init writer
                let writer = VideoWriter(fileURL: fileURL, hasAudio: captureAudio)
                self.videoWriter = writer
                
                print("RecorderManager: Registering stream output to background queue...")
                // CRITICAL: Use non-main queue to avoid deadlocks
                try stream.addStreamOutput(writer, type: SCStreamOutputType.screen, sampleHandlerQueue: videoSampleQueue)
                
                print("RecorderManager: Starting capture...")
                try await stream.startCapture()
                
                if captureAudio {
                    self.audioSession?.startRunning()
                    print("RecorderManager: Audio session started.")
                }
                
                self.isRecording = true
                print("Recording started at \(fileURL.path)")
                completion(.success(()))
                
            } catch {
                print("RecorderManager: Failed to start recording: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    private func setupAudioCapture() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.cleanrecord.recorder.mic"))
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        self.audioSession = session
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Forward to VideoWriter
        // Note: VideoWriter needs to handle this.
        if isRecording, let writer = videoWriter {
             writer.appendAudio(sampleBuffer)
        }
    }
    
    func stopRecording() async -> URL? {
        print("RecorderManager: stopRecording requested. isRecording=\(isRecording)")
        guard isRecording, let stream = stream, let writer = videoWriter else {
            print("RecorderManager: Stop ignored. State invalid: isRecording=\(isRecording), stream=\(stream != nil), writer=\(videoWriter != nil)")
            return nil
        }
        
        do {
            print("RecorderManager: Stopping SCStream...")
            try await stream.stopCapture()
            print("RecorderManager: SCStream stopped.")
            
            if let audioSession = audioSession, audioSession.isRunning {
                audioSession.stopRunning()
                print("RecorderManager: AudioSession stopped.")
            }
            
            print("RecorderManager: Finishing VideoWriter...")
            let url = await writer.finish()
            print("RecorderManager: VideoWriter finished. URL: \(url.path)")
            
            self.stream = nil
            self.videoWriter = nil
            self.audioSession = nil
            self.isRecording = false
            
            return url
        } catch {
            print("RecorderManager: Error stopping capture: \(error)")
            return nil
        }
    }
}
