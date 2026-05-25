import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var text = ""
    @State private var urlText = ""
    @State private var urlNote = ""
    @State private var setupAPIKey = ""
    @State private var setupMessage: String?
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if !appModel.isAnthropicConfigured {
                    Section("Start Here") {
                        Text("Pensieve needs your Anthropic API key before it can turn voice, text, or URLs into structured notes. The key is stored in the iOS Keychain.")
                            .foregroundStyle(.secondary)

                        SecureField("Anthropic API key", text: $setupAPIKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button {
                            saveSetupAPIKey()
                        } label: {
                            Label("Save API Key", systemImage: "key")
                        }
                        .disabled(setupAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if let setupMessage {
                            Text(setupMessage)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if appModel.notes.isEmpty {
                    Section("First Note") {
                        Text("Record a thought, paste text, or save a URL. Saved captures appear in Notes, Wiki, Insights, Review, Chat, Contradictions, and Mindmap after they are processed.")
                            .foregroundStyle(.secondary)
                    }
                }

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
                    .disabled(isSubmitting || !appModel.isAnthropicConfigured)

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

    private func saveSetupAPIKey() {
        do {
            try appModel.saveAnthropicAPIKey(setupAPIKey)
            setupAPIKey = ""
            setupMessage = "Saved. You can now capture notes."
            errorMessage = nil
        } catch {
            setupMessage = nil
            errorMessage = error.localizedDescription
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
