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
        
        // Listen for language changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshMenu),
            name: .languageDidChange,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        print("StatusBarController: Deinitializing! This is likely why the icon disappears.")
    }
    
    @objc private func refreshMenu() {
        print("StatusBarController: refreshMenu() called")
        // Ensure we're on the main thread for UI updates
        Task { @MainActor in
            print("StatusBarController: Clearing menu items")
            // Clear existing menu
            menu.removeAllItems()
            
            print("StatusBarController: Rebuilding menu with new localized strings")
            // Rebuild menu with new localized strings
            setupMenuItems()
            print("StatusBarController: Menu refresh complete")
        }
    }

    private func setupMenu() {
        if let button = statusItem.button {
            // Use custom Nano Banana logo from Resources
            let iconPath = "/Users/chenk/Documents/code/AI/clean-record/CleanRecord/Sources/CleanRecord/Resources/AppIcon.png"
            if let image = NSImage(contentsOfFile: iconPath) {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true // Allows it to change color in Dark Mode
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "aperture", accessibilityDescription: "CleanRecord")
            }
            
            button.action = #selector(menuWillOpen)
        }
        
        setupMenuItems()
        statusItem.menu = menu
    }
    
    private func setupMenuItems() {
        let aboutItem = NSMenuItem(title: "menu.about".localized, action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())
        
        // Construct the menu
        let captureAreaItem = NSMenuItem(title: "menu.capture_area".localized, action: #selector(captureArea), keyEquivalent: "a")
        captureAreaItem.target = self
        menu.addItem(captureAreaItem)
        
        let captureFullscreenItem = NSMenuItem(title: "menu.capture_fullscreen".localized, action: #selector(captureFullscreen), keyEquivalent: "f")
        captureFullscreenItem.target = self
        menu.addItem(captureFullscreenItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let recordAreaItem = NSMenuItem(title: "menu.record_screen".localized, action: #selector(recordScreen), keyEquivalent: "r")
        recordAreaItem.target = self
        menu.addItem(recordAreaItem)
        
        let recordFullscreenItem = NSMenuItem(title: "menu.record_fullscreen".localized, action: #selector(recordFullscreen), keyEquivalent: "R")
        recordFullscreenItem.target = self
        menu.addItem(recordFullscreenItem)
        
        // Pause/Resume items
        let pauseItem = NSMenuItem(title: "menu.pause_recording".localized, action: #selector(pauseRecording), keyEquivalent: "p")
        pauseItem.target = self
        pauseItem.isHidden = true
        menu.addItem(pauseItem)
        
        let resumeItem = NSMenuItem(title: "menu.resume_recording".localized, action: #selector(resumeRecording), keyEquivalent: "")
        resumeItem.target = self
        resumeItem.isHidden = true
        menu.addItem(resumeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Language submenu
        let languageMenu = NSMenu()
        let systemLangItem = NSMenuItem(title: "language.system".localized, action: #selector(setSystemLanguage), keyEquivalent: "")
        systemLangItem.target = self
        languageMenu.addItem(systemLangItem)
        languageMenu.addItem(NSMenuItem.separator())
        let englishItem = NSMenuItem(title: "language.english".localized, action: #selector(setEnglish), keyEquivalent: "")
        englishItem.target = self
        languageMenu.addItem(englishItem)
        let chineseItem = NSMenuItem(title: "language.chinese".localized, action: #selector(setChinese), keyEquivalent: "")
        chineseItem.target = self
        languageMenu.addItem(chineseItem)
        
        let languageMenuItem = NSMenuItem(title: "menu.language".localized, action: nil, keyEquivalent: "")
        languageMenuItem.submenu = languageMenu
        menu.addItem(languageMenuItem)
        
        menu.addItem(withTitle: "menu.select_output_folder".localized, action: #selector(selectOutputDirectory), keyEquivalent: "o")
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "menu.quit".localized, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
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
        
        Task { @MainActor in
            if #available(macOS 12.3, *) {
                let rManager = RecorderManager.shared
                if let item = sItem.menu?.item(withTitle: "menu.record_screen".localized) ?? sItem.menu?.item(withTitle: "menu.stop_recording".localized) {
                    if item.title == "menu.record_screen".localized {
                        SelectionWindowManager.shared.startSelection { rect in
                            Task { @MainActor in
                                stManager.lastRecordingRect = rect
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
                                            CameraOverlayManager.shared.hideCamera()
                                            CameraSessionManager.shared.stop()
                                            stManager.cameraEnabled = false
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
                        CameraSessionManager.shared.stop() // Kill hardware light
                        
                        print("StatusBarController: Resetting icon image and title.")
                        item.title = "menu.record_screen".localized
                        
                        let iconPath = "/Users/chenk/Documents/code/AI/clean-record/CleanRecord/Sources/CleanRecord/Resources/AppIcon.png"
                        if let image = NSImage(contentsOfFile: iconPath) {
                            image.size = NSSize(width: 18, height: 18)
                            image.isTemplate = true
                            sItem.button?.image = image
                        } else {
                            sItem.button?.image = NSImage(systemSymbolName: "aperture", accessibilityDescription: "Record Screen")
                        }
                        sItem.button?.title = ""
                        
                        // Hide Pause/Resume
                        sItem.menu?.item(withTitle: "menu.pause_recording".localized)?.isHidden = true
                        sItem.menu?.item(withTitle: "menu.resume_recording".localized)?.isHidden = true
                        
                        if let url = await rManager.stopRecording() {
                            print("StatusBarController: Recording stopped successfully at \(url.path)")
                            
                            // Check for 0 bytes file
                            let attr = try? FileManager.default.attributesOfItem(atPath: url.path)
                            let fileSize = attr?[.size] as? UInt64 ?? 0
                            
                            if fileSize > 0 {
                                // v2.2 refinement: Reveal in Finder instead of showing overlay
                                NSWorkspace.shared.activateFileViewerSelecting([url])
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
    
    @objc func recordFullscreen() {
        let sItem = statusItem
        let stManager = SettingsManager.shared
        
        Task { @MainActor in
            if #available(macOS 12.3, *) {
                let rManager = RecorderManager.shared
                if let item = sItem.menu?.item(withTitle: "menu.record_fullscreen".localized) ?? sItem.menu?.item(withTitle: "menu.stop_recording".localized) {
                    if item.title == "menu.record_fullscreen".localized {
                        // Get main screen bounds
                        guard let screen = NSScreen.main else { return }
                        let rect = screen.frame
                        
                        stManager.lastRecordingRect = rect
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
                                                item.title = "menu.stop_recording".localized
                                                sItem.button?.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Recording")
                                                
                                                // Show Pause
                                                sItem.menu?.item(withTitle: "menu.pause_recording".localized)?.isHidden = false
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
                                    CameraOverlayManager.shared.hideCamera()
                                    CameraSessionManager.shared.stop()
                                    stManager.cameraEnabled = false
                                }
                            }
                        )
                    } else {
                        // Stop recording (same as recordScreen)
                        print("StatusBarController: Stop recording clicked.")
                        RecordingBorderManager.shared.hideBorder()
                        CameraOverlayManager.shared.hideCamera()
                        CameraSessionManager.shared.stop()
                        
                        print("StatusBarController: Resetting icon image and title.")
                        item.title = "menu.record_fullscreen".localized
                        
                        let iconPath = "/Users/chenk/Documents/code/AI/clean-record/CleanRecord/Sources/CleanRecord/Resources/AppIcon.png"
                        if let image = NSImage(contentsOfFile: iconPath) {
                            image.size = NSSize(width: 18, height: 18)
                            image.isTemplate = true
                            sItem.button?.image = image
                        } else {
                            sItem.button?.image = NSImage(systemSymbolName: "aperture", accessibilityDescription: "Record Screen")
                        }
                        sItem.button?.title = ""
                        
                        // Hide Pause/Resume
                        sItem.menu?.item(withTitle: "menu.pause_recording".localized)?.isHidden = true
                        sItem.menu?.item(withTitle: "menu.resume_recording".localized)?.isHidden = true
                        
                        if let url = await rManager.stopRecording() {
                            print("StatusBarController: Recording stopped successfully at \(url.path)")
                            
                            let attr = try? FileManager.default.attributesOfItem(atPath: url.path)
                            let fileSize = attr?[.size] as? UInt64 ?? 0
                            
                            if fileSize > 0 {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
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
        statusItem.menu?.item(withTitle: "menu.pause_recording".localized)?.isHidden = true
        statusItem.menu?.item(withTitle: "menu.resume_recording".localized)?.isHidden = false
        statusItem.button?.image = NSImage(systemSymbolName: "pause.circle", accessibilityDescription: "Paused")
    }
    
    @objc func resumeRecording() {
        RecorderManager.shared.resumeRecording()
        statusItem.menu?.item(withTitle: "menu.pause_recording".localized)?.isHidden = false
        statusItem.menu?.item(withTitle: "menu.resume_recording".localized)?.isHidden = true
        statusItem.button?.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Recording")
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "about.title".localized
        alert.informativeText = "\("about.version".localized)\n\("about.description".localized)"
        
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
        
        alert.addButton(withTitle: "about.ok".localized)
        alert.runModal()
    }
    
    @objc func setSystemLanguage() {
        print("StatusBarController: setSystemLanguage() called")
        LocalizationManager.shared.resetToSystemLanguage()
        // Menu will refresh automatically via NotificationCenter
    }
    
    @objc func setEnglish() {
        print("StatusBarController: setEnglish() called")
        LocalizationManager.shared.currentLanguage = "en"
        // Menu will refresh automatically via NotificationCenter
    }
    
    @objc func setChinese() {
        print("StatusBarController: setChinese() called")
        LocalizationManager.shared.currentLanguage = "zh-hans"
        // Menu will refresh automatically via NotificationCenter
    }
    
    @objc func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "panel.select_folder".localized
        
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
