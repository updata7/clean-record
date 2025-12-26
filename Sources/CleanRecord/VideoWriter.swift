
import AVFoundation
import ScreenCaptureKit
import Foundation
@available(macOS 12.3, *)
@available(macOS 12.3, *)
class VideoWriter: NSObject, SCStreamOutput {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private let fileURL: URL
    private let hasAudio: Bool
    private var isWriting = true
    private var sessionStarted = false
    private var frameCounter = 0
    private var startTime: CMTime?
    
    // Pause/Resume state
    private var isPaused = false
    private var totalPausedDuration: CMTime = .zero
    private var lastPausedTime: CMTime?
    
    // Audio buffering to wait for video start
    private var audioBufferQueue: [CMSampleBuffer] = []
    
    init(fileURL: URL, hasAudio: Bool = false) {
        self.fileURL = fileURL
        self.hasAudio = hasAudio
        super.init()
    }
    
    deinit {
        print("VideoWriter: Deinitializing.")
    }
    
    private func setupWriter(width: Int, height: Int) throws {
        let writer = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
        
        // Video Settings
        // Ensure dimensions are even numbers (H.264 requirement usually)
        let adjWidth = width % 2 == 0 ? width : width - 1
        let adjHeight = height % 2 == 0 ? height : height - 1
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: adjWidth,
            AVVideoHeightKey: adjHeight,
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspect
        ]
        
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true
        
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: adjWidth,
            kCVPixelBufferHeightKey as String: adjHeight
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: vInput,
            sourcePixelBufferAttributes: attributes
        )
        
        if writer.canAdd(vInput) {
            writer.add(vInput)
        } else {
            throw NSError(domain: "VideoWriter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input"])
        }
        
        // Audio Settings
        if hasAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1, // Mono is safer and matches fixed mic output
                AVEncoderBitRateKey: 64000
            ]
            let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            aInput.expectsMediaDataInRealTime = true
            if writer.canAdd(aInput) {
                writer.add(aInput)
                self.audioInput = aInput
            } else {
                 print("VideoWriter Warning: Cannot add audio input")
            }
        }
        
        if !writer.startWriting() {
            throw writer.error ?? NSError(domain: "VideoWriter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start writing"])
        }
        
        self.assetWriter = writer
        self.videoInput = vInput
        self.pixelBufferAdaptor = adaptor
        self.isWriting = true
        print("VideoWriter: Initialized lazily with size \(adjWidth)x\(adjHeight)")
    }
    
    func pause() {
        guard isWriting, !isPaused else { return }
        isPaused = true
        print("VideoWriter: Paused.")
    }
    
    func resume() {
        guard isWriting, isPaused else { return }
        isPaused = false
        print("VideoWriter: Resumed.")
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        
        let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Lazy initialize on first video frame
        if assetWriter == nil {
            print("VideoWriter: Received first frame. Attempting initialization...")
            // ... (setup code remains same)
            setupOnFirstFrame(sampleBuffer)
        }
        
        guard let writer = assetWriter, let videoInput = videoInput, isWriting else { return }
        
        if writer.status != .writing {
            if writer.status == .failed {
                print("VideoWriter Error: Writer failed: \(String(describing: writer.error))")
                isWriting = false
            }
            return
        }
        
        if !sessionStarted {
            print("VideoWriter: Starting session at \(currentTime.seconds)")
            writer.startSession(atSourceTime: currentTime)
            self.startTime = currentTime
            self.sessionStarted = true
        }
        
        // Handle Pause/Resume
        if isPaused {
            if lastPausedTime == nil {
                lastPausedTime = currentTime
            }
            return
        } else if let pauseStart = lastPausedTime {
            // We just resumed
            let pauseDuration = CMTimeSubtract(currentTime, pauseStart)
            totalPausedDuration = CMTimeAdd(totalPausedDuration, pauseDuration)
            lastPausedTime = nil
            print("VideoWriter: Adjusted for pause of \(pauseDuration.seconds)s. Total pause: \(totalPausedDuration.seconds)s")
        }
        
        // Adjust timestamp
        let adjustedTime = CMTimeSubtract(currentTime, totalPausedDuration)
        
        if videoInput.isReadyForMoreMediaData {
            var timing = CMSampleTimingInfo(
                duration: CMSampleBufferGetDuration(sampleBuffer),
                presentationTimeStamp: adjustedTime,
                decodeTimeStamp: .invalid
            )
            
            var adjustedBuffer: CMSampleBuffer?
            let status = CMSampleBufferCreateCopyWithNewTiming(
                allocator: kCFAllocatorDefault,
                sampleBuffer: sampleBuffer,
                sampleTimingEntryCount: 1,
                sampleTimingArray: &timing,
                sampleBufferOut: &adjustedBuffer
            )
            
            if status == noErr, let buffer = adjustedBuffer {
                if !videoInput.append(buffer) {
                    print("VideoWriter Error: Failed to append video buffer. Status: \(writer.status.rawValue), Error: \(String(describing: writer.error))")
                } else {
                    frameCounter += 1
                    if frameCounter == 1 {
                        processPendingAudio()
                    }
                    if frameCounter <= 10 || frameCounter % 100 == 0 {
                        print("VideoWriter: Stream activity - recorded \(frameCounter) frames (adjusted PTS: \(adjustedTime.seconds)).")
                    }
                }
            }
        }
    }
    
    private func setupOnFirstFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        do {
            try setupWriter(width: width, height: height)
        } catch {
            print("VideoWriter Setup Error: \(error)")
            isWriting = false 
        }
    }
    
    private func processPendingAudio() {
        print("VideoWriter: Flushing \(audioBufferQueue.count) pending audio buffers.")
        let buffers = audioBufferQueue
        audioBufferQueue.removeAll()
        for buffer in buffers {
            appendAudioInternal(buffer)
        }
    }
    
    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        guard isWriting, !isPaused, audioInput != nil else { return }
        
        if !sessionStarted || frameCounter == 0 {
            // Buffer audio until first video frame is written
            if audioBufferQueue.count < 1000 { // Safety limit
                audioBufferQueue.append(sampleBuffer)
            }
            return
        }
        
        appendAudioInternal(sampleBuffer)
    }
    
    private func appendAudioInternal(_ sampleBuffer: CMSampleBuffer) {
        guard let startTime = startTime, let audioInput = audioInput, audioInput.isReadyForMoreMediaData else { return }
        
        let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if currentTime < startTime { return }
        
        // Adjust timestamp for pauses
        let adjustedTime = CMTimeSubtract(currentTime, totalPausedDuration)
        
        var timing = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(sampleBuffer),
            presentationTimeStamp: adjustedTime,
            decodeTimeStamp: .invalid
        )
        
        var adjustedBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleBufferOut: &adjustedBuffer
        )
        
        if status == noErr, let buffer = adjustedBuffer {
            if !audioInput.append(buffer) {
                 print("VideoWriter Error: Failed to append audio buffer. Status: \(assetWriter?.status.rawValue ?? -1)")
            }
        }
    }
    
    func finish() async -> URL {
        return await withCheckedContinuation { continuation in
            print("VideoWriter: Finish requested. isWriting=\(isWriting), sessionStarted=\(sessionStarted)")
            guard let writer = assetWriter else {
                print("VideoWriter: Writer was never initialized (No frames received?). Returning URL with 0 bytes.")
                continuation.resume(returning: self.fileURL)
                return
            }
            
            isWriting = false
            videoInput?.markAsFinished()
            audioInput?.markAsFinished()
            
            if writer.status == .writing {
                writer.finishWriting {
                    print("VideoWriter: Finished. Status: \(writer.status.rawValue). Error: \(String(describing: writer.error))")
                    continuation.resume(returning: self.fileURL)
                }
            } else {
                print("VideoWriter: Not writing (Status: \(writer.status.rawValue)). Error: \(String(describing: writer.error))")
                 continuation.resume(returning: self.fileURL)
            }
        }
    }
}

