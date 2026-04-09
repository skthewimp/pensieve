import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var captureService: ThoughtCaptureService
    @State private var permissionGranted = false
    @State private var showPermissionAlert = false
    @State private var isHolding = false

    var isRecording: Bool {
        captureService.audioRecorder.isRecording
    }

    var body: some View {
        VStack(spacing: 12) {
            // Status text
            if isRecording {
                Text(formatDuration(captureService.audioRecorder.recordingDuration))
                    .font(.system(size: 40, weight: .light, design: .monospaced))
                    .foregroundColor(.red)

                Text("Recording...")
                    .font(.caption)
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

            // Two recording modes
            if !isRecording {
                // Hold to record button
                ZStack {
                    Circle()
                        .fill(isHolding ? Color.red : Color.indigo)
                        .frame(width: 80, height: 80)
                        .shadow(radius: 6)
                        .scaleEffect(isHolding ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isHolding)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.2)
                        .onEnded { _ in
                            startRecordingWithPermission()
                            isHolding = true
                        }
                        .sequenced(before: DragGesture(minimumDistance: 0)
                            .onEnded { _ in
                                if isRecording {
                                    captureService.stopRecording()
                                    isHolding = false
                                }
                            }
                        )
                )
                .disabled(captureService.isProcessing || !captureService.isConfigured)
                .opacity(captureService.isConfigured ? 1.0 : 0.5)

                Text("Hold to record")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // OR divider
                HStack {
                    Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                    Text("or")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                }
                .padding(.horizontal, 40)

                // Tap start / stop button
                Button(action: {
                    startRecordingWithPermission()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "record.circle")
                            .font(.system(size: 20))
                        Text("Start Recording")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.indigo)
                    .cornerRadius(25)
                }
                .disabled(captureService.isProcessing || !captureService.isConfigured)
                .opacity(captureService.isConfigured ? 1.0 : 0.5)

                if !captureService.isConfigured {
                    Text("Set up API key in Settings")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else {
                // Currently recording - show stop button
                Button(action: {
                    captureService.stopRecording()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 80, height: 80)
                            .shadow(radius: 6)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .frame(width: 26, height: 26)
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(1.05)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecording)

                Text("Tap to stop")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
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
