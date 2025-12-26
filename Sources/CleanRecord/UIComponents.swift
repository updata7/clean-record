import SwiftUI
import AppKit

// MARK: - Blur Effect

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Common Components

struct ActionButton: View {
    let icon: String
    let help: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .foregroundColor(.white)
                .padding(6)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .help(help)
    }
}

struct VerticalSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 6)
                
                // Active Fill
                Capsule()
                    .fill(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .top, endPoint: .bottom))
                    .frame(width: 6, height: geometry.size.height * CGFloat(normalize(value)))
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .offset(y: -geometry.size.height * CGFloat(normalize(value)) + 7)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let percent = 1.0 - Double(gesture.location.y / geometry.size.height)
                        let boundedPercent = min(max(percent, 0), 1)
                        self.value = denormalize(boundedPercent)
                    }
            )
        }
        .frame(width: 20)
    }
    
    private func normalize(_ val: Double) -> Double {
        (val - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
    
    private func denormalize(_ norm: Double) -> Double {
        norm * (range.upperBound - range.lowerBound) + range.lowerBound
    }
}
