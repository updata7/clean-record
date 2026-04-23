import SwiftUI

struct SelectionOverlayView: View {
    var onConfirm: (CGRect) -> Void
    var onCancel: () -> Void
    
    @ObservedObject var settings = SettingsManager.shared
    @State private var selectionRect: CGRect?
    @State private var startingRect: CGRect?
    @State private var dragMode: DragMode = .none
    
    enum DragMode: Equatable {
        case none, create, move, resize(edge: Edge)
    }
    
    enum Edge: Equatable {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if selectionRect == nil {
                                    // Initial creation
                                    selectionRect = rectFromPoints(start: value.startLocation, end: value.location)
                                    dragMode = .create
                                } else if dragMode == .create {
                                    selectionRect = rectFromPoints(start: value.startLocation, end: value.location)
                                }
                            }
                            .onEnded { _ in
                                dragMode = .none
                                if let r = selectionRect {
                                    onConfirm(r)
                                }
                            }
                    )
                
                // Selection Rect
                if let rect = selectionRect {
                    ZStack {
                        // The selection area (transparent)
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if dragMode != .move {
                                            dragMode = .move
                                            startingRect = rect
                                        }
                                        if let start = startingRect {
                                            selectionRect = CGRect(
                                                x: start.origin.x + value.translation.width,
                                                y: start.origin.y + value.translation.height,
                                                width: start.width,
                                                height: start.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in 
                                        dragMode = .none
                                        startingRect = nil
                                    }
                            )
                        
                        // Border
                        Rectangle()
                            .stroke(Color.blue, lineWidth: 2)
                        
                        // Handles
                        Group {
                            Handle(edge: .topLeft, rect: rect, onResize: { delta in resize(edge: .topLeft, delta: delta) }, onEnd: { startingRect = nil })
                            Handle(edge: .topRight, rect: rect, onResize: { delta in resize(edge: .topRight, delta: delta) }, onEnd: { startingRect = nil })
                            Handle(edge: .bottomLeft, rect: rect, onResize: { delta in resize(edge: .bottomLeft, delta: delta) }, onEnd: { startingRect = nil })
                            Handle(edge: .bottomRight, rect: rect, onResize: { delta in resize(edge: .bottomRight, delta: delta) }, onEnd: { startingRect = nil })
                        }
                    }
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    
                    // Dimensions Label
                    Text("\(Int(rect.width)) x \(Int(rect.height))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.cornerRadius(4))
                        .position(x: rect.midX, y: rect.minY - 20)
                }
                
                // Floating Toolbar
                VStack {
                    HStack(spacing: 12) {
                        RatioBtn(label: "selection.free".localized, ratio: nil, current: settings.selectionAspectRatio) { settings.selectionAspectRatio = nil }
                        RatioBtn(label: "16:9", ratio: 16.0/9.0, current: settings.selectionAspectRatio) { settings.selectionAspectRatio = 16.0/9.0 }
                        RatioBtn(label: "9:16", ratio: 9.0/16.0, current: settings.selectionAspectRatio) { settings.selectionAspectRatio = 9.0/16.0 }
                        RatioBtn(label: "4:3", ratio: 4.0/3.0, current: settings.selectionAspectRatio) { settings.selectionAspectRatio = 4.0/3.0 }
                        RatioBtn(label: "1:1", ratio: 1.0, current: settings.selectionAspectRatio) { settings.selectionAspectRatio = 1.0 }
                        
                        Divider().frame(height: 20).background(Color.white.opacity(0.3))
                        
                        if selectionRect != nil {
                            // Automatically confirm on drag end, or show a small action button
                        }

                        Button(action: onCancel) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Cancel")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow).cornerRadius(12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.top, 40)
                    
                    Spacer()
                }
            }
        }
    }
    
    private func resize(edge: Edge, delta: CGSize) {
        if startingRect == nil {
            startingRect = selectionRect
        }
        
        guard let start = startingRect else { return }
        var newRect = start
        
        switch edge {
        case .topLeft:
            newRect.origin.x += delta.width
            newRect.origin.y += delta.height
            newRect.size.width -= delta.width
            newRect.size.height -= delta.height
        case .topRight:
            newRect.origin.y += delta.height
            newRect.size.width += delta.width
            newRect.size.height -= delta.height
        case .bottomLeft:
            newRect.origin.x += delta.width
            newRect.size.width -= delta.width
            newRect.size.height += delta.height
        case .bottomRight:
            newRect.size.width += delta.width
            newRect.size.height += delta.height
        }
        
        // Constrain aspect ratio if set
        if let ratio = SettingsManager.shared.selectionAspectRatio {
            newRect.size.height = newRect.size.width / ratio
        }
        
        selectionRect = newRect
    }
    
    // Internal Handle Component
    struct Handle: View {
        let edge: Edge
        let rect: CGRect
        let onResize: (CGSize) -> Void
        let onEnd: () -> Void
        
        var body: some View {
            Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.blue, lineWidth: 1))
                .position(positionIn(rect: rect))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            onResize(value.translation)
                        }
                        .onEnded { _ in
                            onEnd()
                        }
                )
        }
        
        private func positionIn(rect: CGRect) -> CGPoint {
            switch edge {
            case .topLeft: return .zero
            case .topRight: return CGPoint(x: rect.width, y: 0)
            case .bottomLeft: return CGPoint(x: 0, y: rect.height)
            case .bottomRight: return CGPoint(x: rect.width, y: rect.height)
            }
        }
    }
    
    func rectFromPoints(start: CGPoint, end: CGPoint) -> CGRect {
        var width = abs(end.x - start.x)
        var height = abs(end.y - start.y)
        
        if let ratio = SettingsManager.shared.selectionAspectRatio {
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
