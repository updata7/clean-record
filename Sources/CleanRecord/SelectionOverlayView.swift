import SwiftUI

struct SelectionOverlayView: View {
    var onConfirm: (CGRect) -> Void
    var onCancel: () -> Void
    
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
                    
                    // Add dimensions label?
                }
            }
            .background(Color.clear) // ensure clicks pass through if needed, but here we want to catch them
        }
    }
    
    func rectFromPoints(start: CGPoint, end: CGPoint) -> CGRect {
        let x = min(start.x, end.x)
        let y = min(start.y, end.y)
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
