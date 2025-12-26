
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
    
    init(fileURL: URL, hasAudio: Bool = false) {
        self.fileURL = fileURL
        self.hasAudio = hasAudio
        super.init()
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
                AVNumberOfChannelsKey: 1,
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
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        
        // Lazy initialize on first video frame
        if assetWriter == nil {
            print("VideoWriter: Received first frame. Attempting initialization...")
            guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                  let attachment = attachments.first,
                  let contentRectDict = attachment[.contentRect],
                  let _ = CGRect(dictionaryRepresentation: contentRectDict as! CFDictionary) else {
                
                // Fallback to image buffer
                if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    let width = CVPixelBufferGetWidth(imageBuffer)
                    let height = CVPixelBufferGetHeight(imageBuffer)
                    print("VideoWriter: Init fallback using ImageBuffer: \(width)x\(height)")
                    try? setupWriter(width: width, height: height)
                } else {
                     print("VideoWriter: Failed to extract dimensions from first frame. Waiting for next.")
                }
                return
            }
            
            // Prefer Pixel Buffer
            if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
               let width = CVPixelBufferGetWidth(imageBuffer)
               let height = CVPixelBufferGetHeight(imageBuffer)
                do {
                   try setupWriter(width: width, height: height)
                } catch {
                    print("VideoWriter Setup Error: \(error)")
                    // Disable writing to prevent spam
                    isWriting = false 
                    return
                }
           }
        }
        
        guard let writer = assetWriter, let videoInput = videoInput, isWriting else { return }
        
        if writer.status != .writing {
            if writer.status == .failed {
                print("VideoWriter Error: Writer failed: \(String(describing: writer.error))")
                isWriting = false
            }
            return
        }
        
        let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if !sessionStarted {
            print("VideoWriter: Starting session at \(currentTime.seconds)")
            writer.startSession(atSourceTime: currentTime)
            sessionStarted = true
        }
        
        if videoInput.isReadyForMoreMediaData {
            if !videoInput.append(sampleBuffer) {
                print("VideoWriter Error: Failed to append video buffer. Status: \(writer.status.rawValue), Error: \(String(describing: writer.error))")
            } else {
                frameCounter += 1
                if frameCounter % 100 == 0 {
                    print("VideoWriter: Stream activity - received \(frameCounter) frames.")
                }
            }
        } else {
            // Optional: log if dropping too many
            // print("VideoWriter: Video input not ready.")
        }
    }
    
    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        guard sessionStarted, let audioInput = audioInput, audioInput.isReadyForMoreMediaData else { return }
        if !audioInput.append(sampleBuffer) {
             print("VideoWriter Error: Failed to append audio buffer.")
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

