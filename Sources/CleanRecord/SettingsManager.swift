import Foundation
import SwiftUI

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    // Keys
    private let kOutputDirectory = "outputDirectory"
    private let kMicEnabled = "micEnabled"
    private let kSystemAudioEnabled = "systemAudioEnabled"
    private let kCameraEnabled = "cameraEnabled"
    private let kCameraShape = "cameraShape"
    private let kCameraScale = "cameraScale"
    private let kBeautyEnabled = "beautyEnabled"
    private let kBeautyLevel = "beauty_level"
    private let kSelectionAspectRatio = "selectionAspectRatio"
    
    // Published properties for UI binding
    @Published var micEnabled: Bool {
        didSet { defaults.set(micEnabled, forKey: kMicEnabled) }
    }
    
    @Published var systemAudioEnabled: Bool {
        didSet { defaults.set(systemAudioEnabled, forKey: kSystemAudioEnabled) }
    }
    
    // Camera enabled is session-only
    @Published var cameraEnabled: Bool = false
    
    // Camera shape and scale are persisted
    @Published var cameraShape: String {
        didSet { defaults.set(cameraShape, forKey: kCameraShape) }
    }
    
    @Published var cameraScale: Double {
        didSet { defaults.set(cameraScale, forKey: kCameraScale) }
    }
    
    @Published var beautyEnabled: Bool {
        didSet { defaults.set(beautyEnabled, forKey: kBeautyEnabled) }
    }
    
    @Published var beautyLevel: Double {
        didSet { defaults.set(beautyLevel, forKey: kBeautyLevel) }
    }
    
    @Published var selectionAspectRatio: Double? {
        didSet { defaults.set(selectionAspectRatio ?? 0, forKey: kSelectionAspectRatio) }
    }
    
    // Non-persistent state for current session
    @Published var lastRecordingRect: NSRect? = nil
    
    init() {
        self.micEnabled = defaults.object(forKey: kMicEnabled) as? Bool ?? false
        self.systemAudioEnabled = defaults.object(forKey: kSystemAudioEnabled) as? Bool ?? false
        self.cameraEnabled = false
        self.cameraShape = defaults.string(forKey: kCameraShape) ?? "circle"
        
        let savedScale = defaults.double(forKey: kCameraScale)
        self.cameraScale = savedScale == 0 ? 1.0 : savedScale
        
        self.beautyEnabled = defaults.bool(forKey: kBeautyEnabled)
        self.beautyLevel = defaults.double(forKey: kBeautyLevel)
        
        let savedRatio = defaults.double(forKey: kSelectionAspectRatio)
        self.selectionAspectRatio = savedRatio == 0 ? nil : savedRatio
    }
    
    var outputDirectory: URL {
        get {
            if let path = defaults.string(forKey: kOutputDirectory),
               let url = URL(string: path) {
                return url
            }
            // Default to Movies folder, or Downloads if Movies unavailable
            return FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        }
        set {
            defaults.set(newValue.absoluteString, forKey: kOutputDirectory)
            objectWillChange.send()
        }
    }
    
    func setOutputDirectory(to url: URL) {
        // Save bookmark data if needed for sandboxed apps, but for now just path
        self.outputDirectory = url
    }
    
    // Adjusts a rect to match a target aspect ratio while preserving the center
    func adjustRect(_ rect: NSRect, to ratio: Double?) -> NSRect {
        guard let ratio = ratio else { return rect }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        var newWidth = rect.width
        var newHeight = rect.height
        
        if newWidth / newHeight > ratio {
            // Rect is too wide, shrink width
            newWidth = newHeight * ratio
        } else {
            // Rect is too tall, shrink height
            newHeight = newWidth / ratio
        }
        
        return NSRect(
            x: center.x - newWidth / 2,
            y: center.y - newHeight / 2,
            width: newWidth,
            height: newHeight
        ).integral
    }

    // Applies the current selectionAspectRatio to lastRecordingRect and updates UI
    func updateRecordingRect() {
        guard let currentRect = lastRecordingRect else { return }
        let newRect = adjustRect(currentRect, to: selectionAspectRatio)
        
        if newRect != currentRect {
            self.lastRecordingRect = newRect // This will trigger UI updates
            
            // Update UI
            Task { @MainActor in
                RecordingBorderManager.shared.showBorder(for: newRect)
                
                // Update Control Bar position (bottomPoint)
                // This is a simplified approach. A more robust solution might involve
                // passing a window reference or using notifications.
                // For now, we assume the ControlBarWindowManager will react to border changes
                // or that the user will reposition if needed.
                // ControlBarWindowManager.shared.updatePosition(for: newRect) // If such a method existed
            }
        }
    }

    // Hardware capabilities
    var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
    
    var recommendedVideoCodec: String {
        return isAppleSilicon ? "hevc" : "h264"
    }
    
    var recommendedBitrate: Int {
        return isAppleSilicon ? 20_000_000 : 12_000_000
    }
    
    var recommendedPixelFormat: OSType {
        // NV12 is much more efficient for hardware encoders
        return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    }
}
