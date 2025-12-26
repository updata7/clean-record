import SwiftUI

struct ControlBarView: View {
    var onStart: () -> Void
    var onCancel: () -> Void
    
    @ObservedObject var settings = SettingsManager.shared
    @State private var isShowingBeauty = false
    @State private var isShowingScale = false
    
    private func shapeIcon(_ shape: String) -> String {
        switch shape {
        case "circle": return "circle"
        case "square": return "square"
        default: return "rectangle"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Microphone Toggle
            ToggleBtn(isOn: $settings.micEnabled, icon: "mic.slash.fill", activeIcon: "mic.fill", help: "Microphone Audio")
            
            // Camera Toggle
            Toggle(isOn: $settings.cameraEnabled) {
                Image(systemName: settings.cameraEnabled ? "video.fill" : "video.slash.fill")
            }
            .toggleStyle(.button)
            .help("Camera Overlay")
            .onChange(of: settings.cameraEnabled) { enabled in
                if enabled {
                    CameraOverlayManager.shared.showCamera()
                } else {
                    CameraOverlayManager.shared.hideCamera()
                }
            }
            
            if settings.cameraEnabled {
                Divider().frame(height: 20)
                
                // Shape Toggle (Menu is fine for this)
                Menu {
                    Button("Circle") { settings.cameraShape = "circle" }
                    Button("Square") { settings.cameraShape = "square" }
                    Button("Rectangle") { settings.cameraShape = "rectangle" }
                } label: {
                    Image(systemName: shapeIcon(settings.cameraShape))
                        .foregroundColor(.blue)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
                .help("Camera Shape")
                
                // Continuous Scale Control
                Button(action: { isShowingScale.toggle() }) {
                    Text("\(Int(settings.cameraScale * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                        .frame(width: 40)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isShowingScale) {
                    VStack(spacing: 8) {
                        Text("\(Int(settings.cameraScale * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                        
                        VerticalSlider(value: $settings.cameraScale, range: 0.2...3.0)
                            .frame(height: 100)
                    }
                    .padding(12)
                }
                .help("Camera Scale")
                
                // Beauty Slider Popover
                Button(action: { isShowingBeauty.toggle() }) {
                    Image(systemName: settings.beautyLevel > 0 ? "face.smiling.fill" : "face.smiling")
                        .foregroundColor(settings.beautyLevel > 0 ? .pink : .primary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isShowingBeauty) {
                    VStack(spacing: 8) {
                        Text("\(Int(settings.beautyLevel * 100))")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.pink)
                        
                        VerticalSlider(value: $settings.beautyLevel, range: 0...1)
                            .frame(height: 100)
                            .onChange(of: settings.beautyLevel) { val in
                                settings.beautyEnabled = (val > 0)
                            }
                    }
                    .padding(12)
                }
                .help("Beauty Filter")
            }
            
            Divider()
                .frame(height: 20)
            
            // Record Button
            Button(action: onStart) {
                Image(systemName: "record.circle")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Start Recording")
            
            // Cancel Button
            Button(action: onCancel) {
                Image(systemName: "xmark.circle")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Cancel")
            
            Divider().frame(height: 20)
        }
        .padding(10)
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow).cornerRadius(25))
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var ratioLabel: String {
        if let ratio = settings.selectionAspectRatio {
            if abs(ratio - 16.0/9.0) < 0.01 { return "16:9" }
            if abs(ratio - 4.0/3.0) < 0.01 { return "4:3" }
            if abs(ratio - 1.0) < 0.01 { return "1:1" }
            if abs(ratio - 9.0/16.0) < 0.01 { return "9:16" }
            if abs(ratio - 6.0/7.0) < 0.01 { return "6:7" }
            return String(format: "%.1f", ratio)
        }
        return "Free"
    }
    
    private func updateRatio(_ ratio: Double?) {
        settings.selectionAspectRatio = ratio
        settings.updateRecordingRect()
    }
}

struct ToggleBtn: View {
    @Binding var isOn: Bool
    let icon: String
    let activeIcon: String
    let help: String
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            Image(systemName: isOn ? activeIcon : icon)
                .foregroundColor(isOn ? .blue : .white)
        }
        .buttonStyle(PlainButtonStyle())
        .help(help)
    }
}
