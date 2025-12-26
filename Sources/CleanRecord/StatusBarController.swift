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
    
    deinit {
        print("StatusBarController: Deinitializing! This is likely why the icon disappears.")
    }

    private func setupMenu() {
        let aboutItem = NSMenuItem(title: "About CleanRecord", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())
        
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
        
        // Pause/Resume items
        let pauseItem = NSMenuItem(title: "Pause Recording", action: #selector(pauseRecording), keyEquivalent: "p")
        pauseItem.target = self
        pauseItem.isHidden = true
        menu.addItem(pauseItem)
        
        let resumeItem = NSMenuItem(title: "Resume Recording", action: #selector(resumeRecording), keyEquivalent: "")
        resumeItem.target = self
        resumeItem.isHidden = true
        menu.addItem(resumeItem)
        
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
        let sManager = ScreenshotManager.shared
        Task { @MainActor [weak self] in
            SelectionWindowManager.shared.startSelection { [weak self] rect in
                guard let image = sManager.captureRect(rect) else { return }
                Task { @MainActor [weak self] in
                    self?.handleCapturedImage(image)
                }
            }
        }
    }

    @objc func captureFullscreen() {
        let sManager = ScreenshotManager.shared
        Task { @MainActor [weak self] in
            guard let image = sManager.captureFullscreen() else { return }
            self?.handleCapturedImage(image)
        }
    }

    @objc func recordScreen() {
        let sItem = statusItem
        let stManager = SettingsManager.shared
        
        Task { @MainActor [weak self] in
            if #available(macOS 12.3, *) {
                let rManager = RecorderManager.shared
                if let item = sItem.menu?.item(withTitle: "Record Screen") ?? sItem.menu?.item(withTitle: "Stop Recording") {
                    if item.title == "Record Screen" {
                        SelectionWindowManager.shared.startSelection { rect in
                            Task { @MainActor in
                                RecordingBorderManager.shared.showBorder(for: rect)
                                
                                let bottomPoint = CGPoint(x: rect.minX, y: rect.minY)
                                
                                ControlBarWindowManager.shared.showControlBar(
                                    at: bottomPoint,
                                    width: rect.width,
                                    onStart: {
                                        Task { @MainActor in
                                            ControlBarWindowManager.shared.closeWindow()
                                            
                                            let captureMic = stManager.micEnabled
                                            rManager.startRecording(rect: rect, captureAudio: captureMic) { result in
                                                switch result {
                                                case .success:
                                                    Task { @MainActor in
                                                        item.title = "Stop Recording"
                                                        sItem.button?.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Recording")
                                                        
                                                        // Show Pause
                                                        sItem.menu?.item(withTitle: "Pause Recording")?.isHidden = false
                                                    }
                                                case .failure(let error):
                                                    print("Error: \(error)")
                                                    Task { @MainActor in
                                                        RecordingBorderManager.shared.hideBorder()
                                                    }
                                                }
                                            }
                                        }
                                    },
                                    onCancel: {
                                        Task { @MainActor in
                                            RecordingBorderManager.shared.hideBorder()
                                        }
                                    }
                                )
                            }
                        }
                    } else {
                        // Stop
                        print("StatusBarController: Stop recording clicked.")
                        RecordingBorderManager.shared.hideBorder()
                        CameraOverlayManager.shared.hideCamera()
                        
                        print("StatusBarController: Resetting icon image and title.")
                        item.title = "Record Screen"
                        if let image = NSImage(systemSymbolName: "aperture", accessibilityDescription: "Record Screen") {
                            sItem.button?.image = image
                            sItem.button?.title = "" // Clear title if we have image
                        } else {
                            sItem.button?.image = nil
                            sItem.button?.title = "REC"
                        }
                        
                        // Hide Pause/Resume
                        sItem.menu?.item(withTitle: "Pause Recording")?.isHidden = true
                        sItem.menu?.item(withTitle: "Resume Recording")?.isHidden = true
                        
                        if let url = await rManager.stopRecording() {
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
                                print("StatusBarController Error: Recording produced 0 bytes file.")
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
    
    @objc func pauseRecording() {
        RecorderManager.shared.pauseRecording()
        statusItem.menu?.item(withTitle: "Pause Recording")?.isHidden = true
        statusItem.menu?.item(withTitle: "Resume Recording")?.isHidden = false
        statusItem.button?.image = NSImage(systemSymbolName: "pause.circle", accessibilityDescription: "Paused")
    }
    
    @objc func resumeRecording() {
        RecorderManager.shared.resumeRecording()
        statusItem.menu?.item(withTitle: "Pause Recording")?.isHidden = false
        statusItem.menu?.item(withTitle: "Resume Recording")?.isHidden = true
        statusItem.button?.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Recording")
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "CleanRecord"
        alert.informativeText = "Version 2.1\nA sleek screen recorder with Nano Banana energy."
        
        if let logoPath = Bundle.main.path(forResource: "AppIcon", ofType: "png"),
           let image = NSImage(contentsOfFile: logoPath) {
            alert.icon = image
        } else {
            // Fallback to absolute path if bundle fails (common in standalone scripts/debug builds)
            let fallbackPath = "/Users/chenk/Documents/code/AI/clean-record/CleanRecord/Sources/CleanRecord/Resources/AppIcon.png"
            if let image = NSImage(contentsOfFile: fallbackPath) {
                alert.icon = image
            }
        }
        
        alert.addButton(withTitle: "OK")
        alert.runModal()
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

    @MainActor
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    @MainActor
    private func handleCapturedImage(_ image: NSImage) {
        // Play shutter sound
        NSSound(named: "Ping")?.play()
        
        // Show overlay
        Task { @MainActor in
            OverlayWindowManager.shared.showOverlay(with: image)
        }
    }
}
