import AppKit
import SwiftUI
import Combine
import Carbon

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var menu: NSMenu
    private var cancellables = Set<AnyCancellable>()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        
        super.init()
        setupMenu()
        setupDurationObservation()
        
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
            print("StatusBarController: Rebuilding menu with new localized strings")
            setupMenuItems()
            print("StatusBarController: Menu refresh complete")
        }
    }

    private func setupMenu() {
        if let button = statusItem.button {
            // Use custom logo from Resources
            if let image = Bundle.module.image(forResource: "AppIcon") {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true // Allows it to change color in Dark Mode
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "aperture", accessibilityDescription: "CleanRecord")
            }
            
            button.action = #selector(menuWillOpen)
        }
        
        setupMenuItems()
        setupGlobalHotKeys()
        statusItem.menu = menu
    }
    
    private func setupMenuItems() {
        menu.removeAllItems()
        
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
        
        let recordAreaItem = NSMenuItem(title: "menu.record_screen".localized, action: #selector(recordScreen), keyEquivalent: "2")
        recordAreaItem.keyEquivalentModifierMask = [.option, .shift]
        recordAreaItem.target = self
        menu.addItem(recordAreaItem)
        
        let recordFullscreenItem = NSMenuItem(title: "menu.record_fullscreen".localized, action: #selector(recordFullscreen), keyEquivalent: "1")
        recordFullscreenItem.keyEquivalentModifierMask = [.option, .shift]
        recordFullscreenItem.target = self
        menu.addItem(recordFullscreenItem)
        
        // Pause/Resume items
        let pauseItem = NSMenuItem(title: "menu.pause_recording".localized, action: #selector(pauseRecording), keyEquivalent: "p")
        pauseItem.keyEquivalentModifierMask = [.option, .shift]
        pauseItem.target = self
        pauseItem.isHidden = true
        menu.addItem(pauseItem)
        
        let resumeItem = NSMenuItem(title: "menu.resume_recording".localized, action: #selector(resumeRecording), keyEquivalent: "p")
        resumeItem.keyEquivalentModifierMask = [.option, .shift]
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
    
    private func setupGlobalHotKeys() {
        let hotKeyManager = GlobalHotKeyManager.shared
        
        // Modifiers: Shift (0x0200) + Option (0x0800) = 0x0A00
        let modifiers: UInt32 = UInt32(shiftKey | optionKey)
        
        // 1. Record Area: Opt + Shift + 2 (Key code 19)
        hotKeyManager.register(keyCode: 19, modifiers: modifiers, identifier: 1) { [weak self] in
            print("GlobalHotKey: Record Area triggered")
            self?.recordScreen()
        }
        
        // 2. Record Fullscreen: Opt + Shift + 1 (Key code 18)
        hotKeyManager.register(keyCode: 18, modifiers: modifiers, identifier: 2) { [weak self] in
            print("GlobalHotKey: Record Fullscreen triggered")
            self?.recordFullscreen()
        }
        
        // 3. Stop: Opt + Shift + S (Key code 1)
        hotKeyManager.register(keyCode: 1, modifiers: modifiers, identifier: 4) { [weak self] in
            print("GlobalHotKey: Stop triggered")
            Task { @MainActor in
                await self?.stopActiveRecording()
            }
        }
        
        // 4. Pause/Resume: Opt + Shift + P (Key code 35)
        hotKeyManager.register(keyCode: 35, modifiers: modifiers, identifier: 3) { [weak self] in
            print("GlobalHotKey: Pause/Resume triggered")
            if RecorderManager.shared.isRecording {
                if RecorderManager.shared.isPaused {
                    self?.resumeRecording()
                } else {
                    self?.pauseRecording()
                }
            }
        }
        
        // Update menu tooltips to show global shortcuts
        menu.item(withTitle: "menu.record_screen".localized)?.toolTip = "⌥⇧2"
        menu.item(withTitle: "menu.record_fullscreen".localized)?.toolTip = "⌥⇧1"
        menu.item(withTitle: "menu.pause_recording".localized)?.toolTip = "⌥⇧P"
        
        // Also add a dedicated (hidden) stop item if needed, but since we toggle titles, 
        // we can just update the stop shortcut in the stopActiveRecording reset logic or here.
        // For now, these cover the start actions.
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
                
                // Unified check: If recording, stop it regardless of how it started
                if rManager.isRecording {
                    await self.stopActiveRecording()
                    return
                }
                
                if let item = sItem.menu?.item(withTitle: "menu.record_screen".localized) {
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
                                        let captureMic = stManager.micEnabled
                                        rManager.startRecording(rect: rect, captureAudio: captureMic) { result in
                                            switch result {
                                            case .success:
                                                Task { @MainActor in
                                                    item.title = "menu.stop_recording".localized
                                                    item.keyEquivalent = "s"
                                                    item.keyEquivalentModifierMask = [.option, .shift]
                                                    if let recordImg = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording") {
                                                        sItem.button?.image = recordImg
                                                        sItem.button?.contentTintColor = .red
                                                    } else if let image = Bundle.module.image(forResource: "AppIcon") {
                                                        image.size = NSSize(width: 18, height: 18)
                                                        image.isTemplate = true
                                                        sItem.button?.image = image
                                                    }
                                                    
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
                                onStop: {
                                    Task { @MainActor in
                                        await self.stopActiveRecording()
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
                
                if rManager.isRecording {
                    await self.stopActiveRecording()
                    return
                }
                
                if let item = sItem.menu?.item(withTitle: "menu.record_fullscreen".localized) {
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
                                    // ControlBarWindowManager.shared.closeWindow()
                                    
                                    let captureMic = stManager.micEnabled
                                    rManager.startRecording(rect: rect, captureAudio: captureMic) { result in
                                        switch result {
                                        case .success:
                                            Task { @MainActor in
                                                item.title = "menu.stop_recording".localized
                                                item.keyEquivalent = "s"
                                                item.keyEquivalentModifierMask = [.option, .shift]
                                                
                                                if let recordImg = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording") {
                                                    sItem.button?.image = recordImg
                                                    sItem.button?.contentTintColor = .red
                                                } else if let image = Bundle.module.image(forResource: "AppIcon") {
                                                    image.size = NSSize(width: 18, height: 18)
                                                    image.isTemplate = true
                                                    sItem.button?.image = image
                                                }
                                                
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
                            onStop: {
                                Task { @MainActor in
                                    await self.stopActiveRecording()
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
            }
        }

    @MainActor
    func stopActiveRecording() async {
        let rManager = RecorderManager.shared
        guard rManager.isRecording else { return }
        
        print("StatusBarController: stopActiveRecording() called.")
        await RecordingBorderManager.shared.hideBorder()
        await CameraOverlayManager.shared.hideCamera()
        await CameraSessionManager.shared.stop()
        
        // Reset menu items
        let sItem = statusItem
        // Reset to defaults by recreating the menu or manually setting titles
        setupMenuItems()
        
        if let image = Bundle.module.image(forResource: "AppIcon") {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            sItem.button?.image = image
        } else {
            sItem.button?.image = NSImage(systemSymbolName: "aperture", accessibilityDescription: "Record Screen")
        }
        sItem.button?.title = ""
        sItem.button?.contentTintColor = nil
        await ControlBarWindowManager.shared.closeWindow()
        
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
        
        if let image = Bundle.module.image(forResource: "AppIcon") {
            alert.icon = image
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
    
    // MARK: - Duration Observation
    private func setupDurationObservation() {
        RecorderManager.shared.$duration
            .receive(on: RunLoop.main)
            .sink { [weak self] duration in
                guard let self = self else { return }
                let state = RecorderManager.shared.recordingState
                if case .recording = state {
                    let mins = Int(duration) / 60
                    let secs = Int(duration) % 60
                    let title = String(format: " %02d:%02d", mins, secs)
                    self.statusItem.button?.title = title
                    if Int(duration) % 5 == 0 {
                        print("StatusBarController: Updated menu bar duration: \(title)")
                    }
                } else {
                    self.statusItem.button?.title = ""
                }
            }
            .store(in: &cancellables)
            
        RecorderManager.shared.$recordingState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                print("StatusBarController: Recording state changed to \(state)")
                if case .idle = state {
                    self.statusItem.button?.title = ""
                }
            }
            .store(in: &cancellables)
    }
}
