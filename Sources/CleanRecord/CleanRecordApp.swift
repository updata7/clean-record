import SwiftUI
import AppKit

@main
struct CleanRecordApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("CleanRecord is launching...")
        
        statusBar = StatusBarController()
        
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        
        print("CleanRecord started! Icon in menu bar.")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
