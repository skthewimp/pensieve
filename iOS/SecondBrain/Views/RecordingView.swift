import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var captureService: ThoughtCaptureService
    @State private var permissionGranted = false
    @State private var showPermissionAlert = false

    var body: some View {
        VStack(spacing: 16) {
            // Status text
            if captureService.isRecording {
                Text(formatDuration(captureService.recordingDuration))
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundColor(.red)
            } else if captureService.isProcessing {
                if let note = captureService.notes.first {
                    VStack(spacing: 6) {
                        ProgressView()
                        Text(note.status.displayText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("What's on your mind?")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            // Single button: Start or Stop
            if captureService.isRecording {
                Button(action: {
                    captureService.stopRecording()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 22))
                        Text("Stop Recording")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.red)
                    .cornerRadius(30)
                }
            } else {
                Button(action: {
                    startRecordingWithPermission()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 22))
                        Text("Start Recording")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.indigo)
                    .cornerRadius(30)
                }
                .disabled(captureService.isProcessing || !captureService.isConfigured)
                .opacity(captureService.isConfigured ? 1.0 : 0.5)

                if !captureService.isConfigured {
                    Text("Set up API key in Settings")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 20)
        .background(Color(.systemGroupedBackground))
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            Button("OK") {}
        } message: {
            Text("Please grant microphone access in Settings to record thoughts.")
        }
    }

    private func startRecordingWithPermission() {
        Task {
            if !permissionGranted {
                permissionGranted = await captureService.audioRecorder.requestPermission()
            }
            if permissionGranted {
                captureService.startRecording()
            } else {
                showPermissionAlert = true
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
    }
}
