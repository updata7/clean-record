import SwiftUI

struct ControlBarView: View {
    var onStart: () -> Void
    var onStop: () -> Void
    var onCancel: () -> Void
    
    @ObservedObject var recorder = RecorderManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @State private var isShowingBeauty = false
    @State private var isShowingScale = false
    @State private var pulseScale: CGFloat = 1.0
    
    private func shapeIcon(_ shape: String) -> String {
        switch shape {
        case "circle": return "circle"
        case "square": return "square"
        default: return "rectangle"
        }
    }
    
    var body: some View {
        // Main Control Bar
        HStack(spacing: 0) {
            // Left Group: Timer
            if recorder.isRecording {
                durationView
                    .padding(.leading, 12)
                
                Separator()
                    .padding(.horizontal, 10)
            }
            
            // Middle Group: Settings
            HStack(spacing: 12) {
                // Microphone
                CompactToggleBtn(isOn: $settings.micEnabled, icon: "mic.slash.fill", activeIcon: "mic.fill")
                
                // Camera
                CompactCameraToggle(isOn: $settings.cameraEnabled)
                
                // Whiteboard
                CompactWhiteboardToggle(isOn: $settings.whiteboardEnabled)
                
                if settings.cameraEnabled {
                    CompactSeparator()
                    cameraControls
                }
            }
            .padding(.horizontal, 10)
            
            Separator()
                .padding(.horizontal, 10)
            
            // Right Group: Actions
            HStack(spacing: 12) {
                if recorder.isRecording {
                    // Pause/Resume Button
                    Button(action: {
                        if recorder.isPaused {
                            recorder.resumeRecording()
                        } else {
                            recorder.pauseRecording()
                        }
                    }) {
                        Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.black.opacity(0.7))
                            .frame(width: 24, height: 24)
                            .background(Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                compactRecordButton
                actionButton
            }
            .padding(.trailing, 10)
        }
        .padding(.vertical, 4)
        .background(
            ZStack {
                VisualEffectBlur(material: .menu, blendingMode: .behindWindow, cornerRadius: 6)
                RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.9))
            }
        )
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
        )
        .overlay(
            // Countdown Overlay
            Group {
                if case .countdown(let count) = recorder.recordingState {
                    Text("\(count)")
                        .font(.system(size: 80, weight: .black, design: .rounded))
                        .foregroundColor(.black.opacity(0.8))
                        .shadow(color: .white.opacity(0.5), radius: 15)
                        .offset(y: -100)
                        .transition(.scale.combined(with: .opacity))
                        .id(count)
                }
            }
        )
        .disabled(isCountingDown)
    }
    
    private var isCountingDown: Bool {
        if case .countdown = recorder.recordingState { return true }
        return false
    }
    
    private var durationView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
                .scaleEffect(pulseScale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        pulseScale = 1.4
                    }
                }
            
            Text(formatDuration(recorder.duration))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.black.opacity(0.8))
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private var cameraControls: some View {
        HStack(spacing: 8) {
            Button(action: { isShowingScale.toggle() }) {
                Image(systemName: shapeIcon(settings.cameraShape))
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                    .background(Color.blue.opacity(0.08).cornerRadius(6))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isShowingScale, arrowEdge: .top) {
                VStack(spacing: 16) {
                    // Shape Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("camera.shape".localized.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 10) {
                            ShapeButton(icon: "circle", isSelected: settings.cameraShape == "circle") {
                                settings.cameraShape = "circle"
                            }
                            ShapeButton(icon: "square", isSelected: settings.cameraShape == "square") {
                                settings.cameraShape = "square"
                            }
                            ShapeButton(icon: "rectangle", isSelected: settings.cameraShape == "rectangle") {
                                settings.cameraShape = "rectangle"
                            }
                        }
                    }
                    
                    Divider().opacity(0.5)
                    
                    // Scale Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("camera.size".localized.uppercased())
                            Spacer()
                            Text("\(Int(settings.cameraScale * 100))%")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        
                        CustomSlider(value: $settings.cameraScale, range: 0.2...3.0, icon: "magnifyingglass")
                    }
                    
                    // Beauty Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("camera.beauty".localized.uppercased())
                            Spacer()
                            Text("\(Int(settings.beautyLevel * 100))%")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        
                        CustomSlider(value: $settings.beautyLevel, range: 0...1, icon: "face.smiling")
                    }
                }
                .padding(14)
                .frame(width: 180)
                .background(VisualEffectBlur(material: .popover, blendingMode: .behindWindow, cornerRadius: 12))
            }
        }
    }
    
    private var compactRecordButton: some View {
        Button(action: {
            if recorder.isRecording {
                onStop()
            } else {
                onStart()
            }
        }) {
            ZStack {
                if recorder.isRecording {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                }
            }
            .frame(width: 28, height: 28)
            .background(Color.red.opacity(0.1))
            .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var actionButton: some View {
        Button(action: { 
            if recorder.isRecording {
                ControlBarWindowManager.shared.closeWindow()
            } else {
                onCancel()
            }
        }) {
            Image(systemName: recorder.isRecording ? "eye.slash" : "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.black.opacity(0.4))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct Separator: View {
    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.1))
            .frame(width: 1, height: 16)
    }
}

struct CompactSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(width: 1, height: 12)
    }
}

struct CompactCameraToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button(action: { isOn.toggle() }) {
            Image(systemName: isOn ? "video.fill" : "video.slash.fill")
                .font(.system(size: 13))
                .foregroundColor(isOn ? .blue : .black.opacity(0.6))
        }
        .buttonStyle(PlainButtonStyle())
        .onChange(of: isOn) { enabled in
            if enabled {
                CameraOverlayManager.shared.showCamera()
            } else {
                CameraOverlayManager.shared.hideCamera()
            }
        }
    }
}

struct CompactWhiteboardToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button(action: { isOn.toggle() }) {
            Image(systemName: isOn ? "pencil.tip.crop.circle.badge.minus" : "pencil.tip.crop.circle")
                .font(.system(size: 13))
                .foregroundColor(isOn ? .blue : .black.opacity(0.6))
        }
        .buttonStyle(PlainButtonStyle())
        .onChange(of: isOn) { enabled in
            if enabled {
                WhiteboardWindowManager.shared.showWhiteboard()
            } else {
                WhiteboardWindowManager.shared.hideWhiteboard()
            }
        }
    }
}

struct CompactToggleBtn: View {
    @Binding var isOn: Bool
    let icon: String
    let activeIcon: String
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            Image(systemName: isOn ? activeIcon : icon)
                .font(.system(size: 13))
                .foregroundColor(isOn ? .blue : .black.opacity(0.6))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ShapeButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .white : .black.opacity(0.6))
                .frame(width: 36, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.blue : Color.black.opacity(0.04))
                )
        }
        .buttonStyle(.plain)
    }
}

struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 14)
            
            Slider(value: $value, in: range)
                .accentColor(.blue)
                .controlSize(.small)
        }
    }
}
