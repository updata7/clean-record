import Foundation
import ScreenCaptureKit
import AVFoundation

@available(macOS 12.3, *)
class RecorderManager: NSObject, ObservableObject, AVCaptureAudioDataOutputSampleBufferDelegate, SCStreamDelegate {
    static let shared = RecorderManager()
    
    enum RecordingState: Equatable {
        case idle
        case countdown(Int)
        case recording
        case paused
        
        static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.recording, .recording): return true
            case (.paused, .paused): return true
            case (.countdown(let a), .countdown(let b)): return a == b
            default: return false
            }
        }
    }
    
    private var stream: SCStream?
    private var videoWriter: VideoWriter?
    private var audioSession: AVCaptureSession?
    private var lastDisplay: SCDisplay?
    @Published var recordingState: RecordingState = .idle
    @Published var duration: TimeInterval = 0
    
    private var timer: Timer?
    
    var isRecording: Bool { 
        recordingState == .recording || recordingState == .paused 
    }
    var isPaused: Bool { recordingState == .paused }
    
    // Dedicated queue for video samples to prevent blocking Main thread
    private let videoSampleQueue = DispatchQueue(label: "com.cleanrecord.video.samples", qos: .userInitiated)
    
    func startRecording(rect: CGRect? = nil, captureAudio: Bool = false, completion: @escaping (Result<Void, Error>) -> Void) {
        print("RecorderManager: startRecording requested. rect=\(String(describing: rect)), captureAudio=\(captureAudio)")
        
        // Check for Screen Recording permission
        let canRecord = CGPreflightScreenCaptureAccess()
        print("RecorderManager: CGPreflightScreenCaptureAccess = \(canRecord)")
        if !canRecord {
            print("RecorderManager ERROR: No Screen Recording permission!")
            // Don't fail immediately, but log it clearly
        }
        
        Task {
            do {
                let scContent = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                guard let display = scContent.displays.first else {
                    print("RecorderManager Error: No displays found.")
                    completion(.failure(NSError(domain: "RecorderManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No displays found"])))
                    return
                }
                // Find the matching NSScreen for logical coordinate conversion
                let screens = NSScreen.screens
                let matchingScreen = screens.first(where: { screen in
                    let description = screen.deviceDescription
                    let screenID = description[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                    return screenID == display.displayID
                }) ?? NSScreen.main ?? screens[0]
                
                let screenHeight = matchingScreen.frame.height
                let scale = CGFloat(display.width) / matchingScreen.frame.width
                
                print("RecorderManager: Selected display: \(display.displayID), pixelSize: \(display.width)x\(display.height), pointSize: \(matchingScreen.frame.size), scale: \(scale)")
                self.lastDisplay = display
                
                let streamConfig = SCStreamConfiguration()
                
                if let rect = rect {
                    // sourceRect must be in points (logical coordinates) with Top-Left origin
                    let scRect = CGRect(
                        x: floor(rect.minX),
                        y: floor(screenHeight - rect.minY - rect.height),
                        width: floor(rect.width),
                        height: floor(rect.height)
                    ).integral
                    
                    streamConfig.sourceRect = scRect
                    
                    // Output width/height should be physical pixels to maintain quality
                    streamConfig.width = Int(rect.width * scale)
                    streamConfig.height = Int(rect.height * scale)
                    
                    print("RecorderManager: Using SCStream sourceRect (Points, Top-Left): \(scRect) (from Cocoa rect: \(rect), screenHeight: \(screenHeight))")
                    print("RecorderManager: Output size (Pixels): \(streamConfig.width)x\(streamConfig.height)")
                } else {
                    // Full screen
                    streamConfig.width = display.width
                    streamConfig.height = display.height
                }
                
                streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)
                streamConfig.queueDepth = 16
                streamConfig.pixelFormat = SettingsManager.shared.recommendedPixelFormat
                streamConfig.showsCursor = true
                
                // Exclude windows: Self (Recording Border) and potentially others
                var excludedWindows: [SCWindow] = []
                
                // borderWindow.windowNumber access should be on MainActor
                let (borderWindowID, controlBarWindowID) = await MainActor.run { () -> (CGWindowID?, CGWindowID?) in
                    let bID = RecordingBorderManager.shared.window.map { CGWindowID($0.windowNumber) }
                    let cID = ControlBarWindowManager.shared.window.map { CGWindowID($0.windowNumber) }
                    return (bID, cID)
                }
                
                if let bID = borderWindowID {
                    if let scWindow = scContent.windows.first(where: { $0.windowID == bID }) {
                        excludedWindows.append(scWindow)
                        print("RecorderManager: Excluding border window \(bID)")
                    }
                }
                
                if let cID = controlBarWindowID {
                    if let scWindow = scContent.windows.first(where: { $0.windowID == cID }) {
                        excludedWindows.append(scWindow)
                        print("RecorderManager: Excluding control bar window \(cID)")
                    }
                }
                
                let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
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
                
                // Countdown logic
                for i in (1...3).reversed() {
                    self.recordingState = .countdown(i)
                    print("RecorderManager: Countdown... \(i)")
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
                
                print("RecorderManager: Starting capture...")
                try await stream.startCapture()
                
                if captureAudio {
                    self.audioSession?.startRunning()
                    print("RecorderManager: Audio session started.")
                }
                
                self.recordingState = .recording
                self.duration = 0
                self.startTimer()
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
        
        // Force output to a standard format that matches VideoWriter expectations
        output.audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.cleanrecord.recorder.mic"))
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        self.audioSession = session
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Forward to VideoWriter
        if recordingState == .recording, let writer = videoWriter {
             writer.appendAudio(sampleBuffer)
        }
    }
    
    func pauseRecording() {
        guard recordingState == .recording else { return }
        videoWriter?.pause()
        recordingState = .paused
        print("RecorderManager: Recording paused.")
    }
    
    func resumeRecording() {
        guard recordingState == .paused else { return }
        videoWriter?.resume()
        recordingState = .recording
        startTimer()
        print("RecorderManager: Recording resumed.")
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
            
            self.stopTimer()
            self.stream = nil
            self.videoWriter = nil
            self.audioSession = nil
            self.recordingState = .idle
            self.duration = 0
            
            // Hide whiteboard as it is part of the system
            await MainActor.run {
                WhiteboardWindowManager.shared.hideWhiteboard()
            }
            
            // Show notification
            let notification = NSUserNotification()
            notification.title = "Recording Finished"
            notification.informativeText = "Saved to \(url.lastPathComponent)"
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
            
            return url
        } catch {
            print("RecorderManager: Error stopping capture: \(error)")
            return nil
        }
    }
    
    func updateCaptureRect(_ rect: CGRect) {
        guard let stream = stream, let display = lastDisplay else { return }
        
        Task {
            // Re-find the matching screen for consistent coordinate math
            let screens = await MainActor.run { NSScreen.screens }
            let foundScreen = screens.first(where: { screen in
                let description = screen.deviceDescription
                let screenID = description[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                return screenID == display.displayID
            })
            
            let matchingScreen: NSScreen
            if let found = foundScreen {
                matchingScreen = found
            } else if let main = await MainActor.run(body: { NSScreen.main }) {
                matchingScreen = main
            } else {
                matchingScreen = screens[0]
            }
            
            let screenHeight = matchingScreen.frame.height
            let scale = CGFloat(display.width) / matchingScreen.frame.width
            
            let streamConfig = SCStreamConfiguration()
            
            // sourceRect must be in points (logical coordinates) with Top-Left origin
            let scRect = CGRect(
                x: floor(rect.minX),
                y: floor(screenHeight - rect.minY - rect.height),
                width: floor(rect.width),
                height: floor(rect.height)
            ).integral
            
            streamConfig.sourceRect = scRect
            streamConfig.width = Int(rect.width * scale)
            streamConfig.height = Int(rect.height * scale)
            
            streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            streamConfig.queueDepth = 16
            streamConfig.pixelFormat = SettingsManager.shared.recommendedPixelFormat
            streamConfig.showsCursor = true
            
            do {
                try await stream.updateConfiguration(streamConfig)
                print("RecorderManager: Updated capture rect to \(scRect)")
            } catch {
                print("RecorderManager: Failed to update configuration: \(error)")
            }
        }
    }
    
    // MARK: - SCStreamDelegate
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("RecorderManager: SCStream stopped with error: \(error.localizedDescription)")
    }
    
    // MARK: - Timer
    private func startTimer() {
        print("RecorderManager: startTimer() called.")
        stopTimer()
        
        // Use a timer that isn't automatically scheduled, then add it to Main RunLoop
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Check state
            let currentState = self.recordingState
            if case .recording = currentState {
                DispatchQueue.main.async {
                    self.duration += 1
                    if Int(self.duration) % 5 == 0 {
                        print("RecorderManager: Duration updated to \(self.duration)")
                    }
                }
            }
        }
        
        self.timer = t
        RunLoop.main.add(t, forMode: .common)
        print("RecorderManager: Timer added to Main RunLoop.")
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
