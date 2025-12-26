import SwiftUI

struct ControlBarView: View {
    var onStart: () -> Void
    var onCancel: () -> Void
    
    @ObservedObject var settings = SettingsManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Microphone Toggle
            Toggle(isOn: $settings.micEnabled) {
                Image(systemName: settings.micEnabled ? "mic.fill" : "mic.slash.fill")
            }
            .toggleStyle(.button)
            .help("Microphone Audio")
            
            // System Audio Toggle (Placeholder logic for now)
            Toggle(isOn: $settings.systemAudioEnabled) {
                Image(systemName: settings.systemAudioEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .toggleStyle(.button)
            .help("System Audio (Requires macOS 13+ or driver)")
            .disabled(true) // Disabled for macOS 12 MVP
            
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
        }
        .padding(10)
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow).cornerRadius(25))
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
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
