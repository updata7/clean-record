import AppKit
import SwiftUI
import WebKit

@MainActor
class WhiteboardWindowManager {
    static let shared = WhiteboardWindowManager()
    
    private var window: WhiteboardPanel?
    
    func showWhiteboard() {
        let settings = SettingsManager.shared
        let targetRect = settings.lastRecordingRect ?? NSScreen.main?.frame ?? .zero
        
        if window == nil {
            createWindow(rect: targetRect)
        } else {
            window?.setFrame(targetRect, display: true)
        }
        
        window?.makeKeyAndOrderFront(nil)
    }
    
    func hideWhiteboard() {
        window?.close()
        window = nil
        SettingsManager.shared.whiteboardEnabled = false
    }
    
    private func createWindow(rect: NSRect) {
        let panel = WhiteboardPanel(
            contentRect: rect,
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.backgroundColor = .white
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = false
        
        // CSS to hide Excalidraw's excessive UI elements
        let css = """
        .App-menu, .Footer, .main-menu, .layer-ui__wrapper__github-corner, 
        .layer-ui__wrapper__footer, .Stack-horizontal:has(.Shareable-link) {
            display: none !important;
        }
        """
        
        let source = """
        var style = document.createElement('style');
        style.innerHTML = `\(css)`;
        document.head.appendChild(style);
        """
        
        let userScript = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(userScript)
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.load(URLRequest(url: URL(string: "https://excalidraw.com")!))
        
        panel.contentView = webView
        self.window = panel
    }
}

// Subclass to handle keyboard focus properly
class WhiteboardPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

struct WhiteboardView: View {
    var body: some View {
        WhiteboardWebView(url: URL(string: "https://excalidraw.com")!)
            .edgesIgnoringSafeArea(.all)
    }
}

struct WhiteboardWebView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
