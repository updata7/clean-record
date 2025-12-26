import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct OverlayView: View {
    let image: NSImage
    var onClose: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main Content
            VStack(spacing: 0) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 120)
                    .cornerRadius(8)
                    .padding(8)
                    .onDrag {
                        if let tiff = image.tiffRepresentation {
                            return NSItemProvider(item: tiff as NSData, typeIdentifier: UTType.tiff.identifier)
                        }
                        return NSItemProvider()
                    }
                
                // Action Bar (appears on hover or always?)
                // CleanShot puts actions *on* the image or below.
                HStack(spacing: 12) {
                    ActionButton(icon: "square.and.arrow.down", help: "Save") {
                        saveImage()
                    }
                    ActionButton(icon: "doc.on.doc", help: "Copy") {
                        copyImage()
                    }
                    ActionButton(icon: "xmark", help: "Close") {
                        onClose()
                    }
                }
                .padding(.bottom, 8)
            }
            .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow).cornerRadius(12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .frame(width: 220)
        .onHover { hover in
            isHovering = hover
        }
    }
    
    func saveImage() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "Screenshot \(Date().formatted(date: .numeric, time: .standard)).png"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if let tiff = image.tiffRepresentation,
                   let imgRep = NSBitmapImageRep(data: tiff),
                   let png = imgRep.representation(using: .png, properties: [:]) {
                    try? png.write(to: url)
                    onClose() // Close after saving?
                }
            }
        }
    }
    
    func copyImage() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        // Maybe show a "Copied" toast?
    }
}

