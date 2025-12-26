import SwiftUI

struct SelectionOverlayView: View {
    var onConfirm: (CGRect) -> Void
    var onCancel: () -> Void
    
    @ObservedObject var settings = SettingsManager.shared
    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if startPoint == nil {
                                    startPoint = value.startLocation
                                }
                                currentPoint = value.location
                            }
                            .onEnded { value in
                                let rect = rectFromPoints(start: startPoint ?? .zero, end: value.location)
                                onConfirm(rect)
                            }
                    )
                
                // Cutout / Selection indication
                if let start = startPoint, let current = currentPoint {
                    let rect = rectFromPoints(start: start, end: current)
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                        .background(Color.clear) // Transparent center
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                    
                    // Dimensions Label
                    Text("\(Int(rect.width)) x \(Int(rect.height))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6).cornerRadius(4))
                        .position(x: rect.midX, y: rect.maxY + 20)
                }
                
                // Floating Toolbar
                VStack {
                    HStack(spacing: 16) {
                        RatioBtn(label: "Free", ratio: nil, current: settings.selectionAspectRatio) { settings.selectionAspectRatio = nil }
                        RatioBtn(label: "16:9", ratio: 16.0/9.0, current: settings.selectionAspectRatio) { settings.selectionAspectRatio = 16.0/9.0 }
                        RatioBtn(label: "4:3", ratio: 4.0/3.0, current: settings.selectionAspectRatio) { settings.selectionAspectRatio = 4.0/3.0 }
                        RatioBtn(label: "1:1", ratio: 1.0, current: settings.selectionAspectRatio) { settings.selectionAspectRatio = 1.0 }
                        RatioBtn(label: "9:16", ratio: 9.0/16.0, current: settings.selectionAspectRatio) { settings.selectionAspectRatio = 9.0/16.0 }
                        RatioBtn(label: "6:7", ratio: 6.0/7.0, current: settings.selectionAspectRatio) { settings.selectionAspectRatio = 6.0/7.0 }

                        Divider().frame(height: 20).background(Color.white.opacity(0.3))
                        
                        Button(action: onCancel) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Cancel")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow).cornerRadius(30))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.top, 40)
                    
                    Spacer()
                }
            }
            .background(Color.clear) // ensure clicks pass through if needed, but here we want to catch them
        }
    }
    
    func rectFromPoints(start: CGPoint, end: CGPoint) -> CGRect {
        var width = abs(end.x - start.x)
        var height = abs(end.y - start.y)
        
        if let ratio = SettingsManager.shared.selectionAspectRatio {
            // Constrain width and height based on ratio
            // width / height = ratio => width = height * ratio
            if width > height * ratio {
                width = height * ratio
            } else {
                height = width / ratio
            }
        }
        
        let x = start.x < end.x ? start.x : start.x - width
        let y = start.y < end.y ? start.y : start.y - height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

struct RatioBtn: View {
    let label: String
    let ratio: Double?
    let current: Double?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isSelected ? .blue : .white)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var isSelected: Bool {
        if let r = ratio {
            guard let c = current else { return false }
            return abs(r - c) < 0.01
        }
        return current == nil
    }
}
