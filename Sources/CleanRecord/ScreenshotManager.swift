import AppKit
import UniformTypeIdentifiers
import AVFoundation

class ScreenshotManager {
    static let shared = ScreenshotManager()
    
    // Captures the entire screen of the main display
    func captureFullscreen() -> NSImage? {
        // CGWindowListCreateImage is the standard low-level API. 
        // kCGWindowListOptionOnScreenOnly captures what's visible.
        // kCGNullWindowID means capture everything.
        let displayID = CGMainDisplayID()
        let bounds = CGDisplayBounds(displayID)
        
        guard let cgImage = CGWindowListCreateImage(
            bounds,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else {
            print("Failed to capture screenshot via CGWindowListCreateImage")
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    // Captures a specific rect on the screen
    func captureRect(_ rect: CGRect) -> NSImage? {
        // Since the rect is in screen coordinates (usually bottom-left origin for CG, but AppKit is top-left in some contexts),
        // CGWindowListCreateImage expects CGRect in stream coordinates (top-left origin).
        // However, if we get rect from a transparent window overlay, need to ensure coordinates match.
        // Assuming rect is correctly in global screen coordinates with top-left origin.
        
        // We might need to handle multi-monitor setups here using specific display bounds, 
        // but for MVP let's assume specific rect capture works across the virtual screen.
        
        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else {
            print("Failed to capture rect")
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    func generateThumbnail(for url: URL) -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        do {
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            return NSImage(cgImage: cgImage, size: NSZeroSize)
        } catch {
            print("Failed to generate thumbnail: \(error)")
            return nil
        }
    }
}
