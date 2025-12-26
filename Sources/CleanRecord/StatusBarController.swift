import AppKit
import SwiftUI

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var menu: NSMenu

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        
        super.init()
        setupMenu()
    }

    private func setupMenu() {
        if let button = statusItem.button {
            // Using a system symbol for now, similar to a camera or lens
            button.image = NSImage(systemSymbolName: "aperture", accessibilityDescription: "CleanRecord")
            if button.image == nil {
                button.title = "REC"
            }
            button.action = #selector(menuWillOpen)
        }
        
        // Construct the menu
        let captureAreaItem = NSMenuItem(title: "Capture Area", action: #selector(captureArea), keyEquivalent: "a")
        captureAreaItem.target = self
        menu.addItem(captureAreaItem)
        
        let captureFullscreenItem = NSMenuItem(title: "Capture Fullscreen", action: #selector(captureFullscreen), keyEquivalent: "f")
        captureFullscreenItem.target = self
        menu.addItem(captureFullscreenItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let recordScreenItem = NSMenuItem(title: "Record Screen", action: #selector(recordScreen), keyEquivalent: "r")
        recordScreenItem.target = self
        menu.addItem(recordScreenItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Select Output Folder...", action: #selector(selectOutputDirectory), keyEquivalent: "o")
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit CleanRecord", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func menuWillOpen() {
        // Dynamic updates to menu can happen here
    }

    @objc func captureArea() {
        SelectionWindowManager.shared.startSelection { [weak self] rect in
            guard let image = ScreenshotManager.shared.captureRect(rect) else { return }
            self?.handleCapturedImage(image)
        }
    }

    @objc func captureFullscreen() {
        guard let image = ScreenshotManager.shared.captureFullscreen() else { return }
        handleCapturedImage(image)
    }

    @objc func recordScreen() {
        if #available(macOS 12.3, *) {
            if let item = statusItem.menu?.item(withTitle: "Record Screen") ?? statusItem.menu?.item(withTitle: "Stop Recording") {
                if item.title == "Record Screen" {
                    // Step 1: Select Area
                    SelectionWindowManager.shared.startSelection { [weak self] rect in
                        // Step 1.5: Show Persistent Border immediately
                        RecordingBorderManager.shared.showBorder(for: rect)
                        
                        // Step 2: Show Control Bar
                        let bottomPoint = CGPoint(x: rect.minX, y: rect.minY) 
                        
                        ControlBarWindowManager.shared.showControlBar(
                            at: bottomPoint,
                            width: rect.width,
                            onStart: {
                                // Step 3: Start Recording
                                ControlBarWindowManager.shared.closeWindow()
                                
                                let captureMic = SettingsManager.shared.micEnabled
                                
                                RecorderManager.shared.startRecording(rect: rect, captureAudio: captureMic) { result in
                                    switch result {
                                    case .success:
                                        DispatchQueue.main.async {
                                            item.title = "Stop Recording"
                                            self?.statusItem.button?.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Recording")
                                        }
                                    case .failure(let error):
                                        print("Error: \(error)")
                                        RecordingBorderManager.shared.hideBorder()
                                    }
                                }
                            },
                            onCancel: {
                                // User cancelled
                                RecordingBorderManager.shared.hideBorder()
                            }
                        )
                    }
                } else {
                    // Stop
                    // Stop recording logic
                Task {
                    print("StatusBarController: Stop recording clicked.")
                    do {
                        // Reset UI first to feel responsive
                        DispatchQueue.main.async {
                            item.title = "Record Screen"
                            self.statusItem.button?.image = NSImage(systemSymbolName: "aperture", accessibilityDescription: "Record Screen")
                        }
                        
                        RecordingBorderManager.shared.hideBorder()
                        CameraOverlayManager.shared.hideCamera()
                        
                        if let url = await RecorderManager.shared.stopRecording() {
                            print("StatusBarController: Recording stopped successfully at \(url.path)")
                            
                            // Check for 0 bytes file
                            let attr = try? FileManager.default.attributesOfItem(atPath: url.path)
                            let fileSize = attr?[.size] as? UInt64 ?? 0
                            
                            if fileSize > 0 {
                                if let thumbnail = ScreenshotManager.shared.generateThumbnail(for: url) {
                                    OverlayWindowManager.shared.showOverlay(with: thumbnail)
                                } else {
                                    NSWorkspace.shared.activateFileViewerSelecting([url])
                                }
                            } else {
                                print("StatusBarController Error: Recording produced 0 bytes file. Resolution mismatch or capture failed.")
                                // Clean up 0 byte file
                                try? FileManager.default.removeItem(at: url)
                            }
                        } else {
                            print("StatusBarController Error: RecorderManager returned nil URL.")
                        }
                    }
                }
            }
        }
    }
}

    
    @objc func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select Folder"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                SettingsManager.shared.setOutputDirectory(to: url)
                print("Output directory set to: \(url.path)")
            }
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    private func handleCapturedImage(_ image: NSImage) {
        // Play shutter sound
        NSSound(named: "Ping")?.play()
        
        // Show overlay
        OverlayWindowManager.shared.showOverlay(with: image)
        
        // Also copy to clipboard by default or based on settings?
        // CleanShot style: Show overlay, allow copy.
        // For MVP convenience, let's also put it in clipboard or just show overlay.
        // Let's rely on overlay for actions.
    }
}
