import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var text = ""
    @State private var urlText = ""
    @State private var urlNote = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Voice") {
                    Button {
                        Task { await toggleRecording() }
                    } label: {
                        Label(
                            appModel.audioRecorder.isRecording ? "Stop Recording" : "Record Voice Note",
                            systemImage: appModel.audioRecorder.isRecording ? "stop.circle.fill" : "mic.fill"
                        )
                    }
                    .foregroundStyle(appModel.audioRecorder.isRecording ? .red : .primary)
                    .disabled(isSubmitting || !appModel.isAnthropicConfigured || !appModel.transcriptionService.isModelLoaded)

                    if appModel.audioRecorder.isRecording {
                        Text(formatDuration(appModel.audioRecorder.recordingDuration))
                            .font(.system(.title2, design: .monospaced))
                            .foregroundStyle(.red)
                    }

                    Text("Whisper: \(appModel.transcriptionService.loadingProgress)")
                        .foregroundStyle(.secondary)
                }

                Section("Text") {
                    TextEditor(text: $text)
                        .frame(minHeight: 120)

                    Button {
                        Task { await submitText() }
                    } label: {
                        Label("Save Text", systemImage: "tray.and.arrow.down")
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }

                Section("URL") {
                    TextField("https://example.com", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                    TextField("Optional note", text: $urlNote, axis: .vertical)

                    Button {
                        Task { await submitURL() }
                    } label: {
                        Label("Save URL", systemImage: "link")
                    }
                    .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Capture")
        }
    }

    private func submitText() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await appModel.captureService.submitText(text)
            text = ""
            await appModel.refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitURL() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await appModel.captureService.submitURL(urlText, note: urlNote)
            urlText = ""
            urlNote = ""
            await appModel.refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleRecording() async {
        errorMessage = nil

        if appModel.audioRecorder.isRecording {
            guard let recording = await MainActor.run(body: {
                appModel.audioRecorder.stopRecording()
            }) else { return }

            isSubmitting = true
            defer { isSubmitting = false }
            do {
                try await appModel.captureService.submitVoice(audioURL: recording.url, duration: recording.duration)
                await appModel.refresh()
            } catch {
                errorMessage = error.localizedDescription
                await appModel.refresh()
            }
            return
        }

        let granted = await appModel.audioRecorder.requestPermission()
        guard granted else {
            errorMessage = "Microphone access is required to record voice notes."
            return
        }

        _ = await MainActor.run {
            appModel.audioRecorder.startRecording()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
    }
}
