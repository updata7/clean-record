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
    
    @Published var cameraScale: CGFloat {
        didSet { defaults.set(cameraScale, forKey: kCameraScale) }
    }
    
    @Published var beautyEnabled: Bool {
        didSet { defaults.set(beautyEnabled, forKey: kBeautyEnabled) }
    }
    
    init() {
        self.micEnabled = defaults.object(forKey: kMicEnabled) as? Bool ?? false
        self.systemAudioEnabled = defaults.object(forKey: kSystemAudioEnabled) as? Bool ?? false
        
        // Camera starts closed
        self.cameraEnabled = false
        
        // Load persistent camera settings
        self.cameraShape = defaults.string(forKey: kCameraShape) ?? "circle"
        self.cameraScale = defaults.object(forKey: kCameraScale) as? CGFloat ?? 1.0
        self.beautyEnabled = defaults.bool(forKey: kBeautyEnabled)
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
}
