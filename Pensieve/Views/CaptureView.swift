import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var text = ""
    @State private var urlText = ""
    @State private var urlNote = ""
    @State private var setupAPIKey = ""
    @State private var setupMessage: String?
    @State private var isSubmitting = false
    @State private var isTranscribingURLNote = false
    @State private var recordingPurpose: RecordingPurpose?
    @State private var errorMessage: String?
    @FocusState private var focusedField: CaptureField?

    private enum RecordingPurpose {
        case voiceNote
        case urlNote
    }

    private enum CaptureField {
        case setupAPIKey
        case text
        case url
        case urlNote
    }

    private var canSubmitURL: Bool {
        !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSubmitting
            && !isTranscribingURLNote
            && !appModel.audioRecorder.isRecording
    }

    var body: some View {
        NavigationStack {
            Form {
                if !appModel.isSelectedLLMConfigured {
                    Section("Start Here") {
                        Text("Pensieve needs an API key for the selected LLM provider before it can turn voice, text, or URLs into structured notes. The key is stored in the iOS Keychain.")
                            .foregroundStyle(.secondary)

                        SecureField("\(appModel.selectedLLMProvider.label) API key", text: $setupAPIKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .setupAPIKey)

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
                        Task { await toggleVoiceNoteRecording() }
                    } label: {
                        Label(
                            recordingPurpose == .voiceNote ? "Stop Recording" : "Record Voice Note",
                            systemImage: recordingPurpose == .voiceNote ? "stop.circle.fill" : "mic.fill"
                        )
                    }
                    .foregroundStyle(recordingPurpose == .voiceNote ? .red : .primary)
                    .disabled(isSubmitting || isTranscribingURLNote || (appModel.audioRecorder.isRecording && recordingPurpose != .voiceNote))

                    if recordingPurpose == .voiceNote {
                        Text(formatDuration(appModel.audioRecorder.recordingDuration))
                            .font(.system(.title2, design: .monospaced))
                            .foregroundStyle(.red)
                    }

                    Text("Whisper model: \(appModel.transcriptionService.loadingProgress)")
                        .foregroundStyle(.secondary)

                    if !appModel.isSelectedLLMConfigured {
                        Text("Recording works without an LLM API key. Add a key for the selected provider before stopping if you want the recording processed into a note.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Text") {
                    TextEditor(text: $text)
                        .frame(minHeight: 120)
                        .focused($focusedField, equals: .text)

                    Button {
                        Task { await submitText() }
                    } label: {
                        Label("Save Text", systemImage: "tray.and.arrow.down")
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }

                Section("URL") {
                    TextField(focusedField == .url ? "" : "https://example.com", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .focused($focusedField, equals: .url)

                    TextField("Optional note", text: $urlNote, axis: .vertical)
                        .focused($focusedField, equals: .urlNote)

                    Button {
                        Task { await toggleURLNoteRecording() }
                    } label: {
                        Label(
                            recordingPurpose == .urlNote ? "Stop Dictating Note" : "Dictate URL Note",
                            systemImage: recordingPurpose == .urlNote ? "stop.circle.fill" : "mic"
                        )
                    }
                    .foregroundStyle(recordingPurpose == .urlNote ? .red : .primary)
                    .disabled(isSubmitting || isTranscribingURLNote || (appModel.audioRecorder.isRecording && recordingPurpose != .urlNote))

                    if recordingPurpose == .urlNote {
                        Text(formatDuration(appModel.audioRecorder.recordingDuration))
                            .font(.system(.headline, design: .monospaced))
                            .foregroundStyle(.red)
                    } else if isTranscribingURLNote {
                        ProgressView("Transcribing note...")
                    }

                    Button {
                        Task { await submitURL() }
                    } label: {
                        Label("Save URL", systemImage: "link")
                    }
                    .disabled(!canSubmitURL)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField == .url || focusedField == .urlNote {
                        Button("Save URL") {
                            Task { await submitURL() }
                        }
                        .disabled(!canSubmitURL)
                    }

                    Spacer()

                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .navigationTitle("Capture")
        }
    }

    private func saveSetupAPIKey() {
        do {
            switch appModel.selectedLLMProvider {
            case .anthropic:
                try appModel.saveAnthropicAPIKey(setupAPIKey)
            case .openAI:
                try appModel.saveOpenAIAPIKey(setupAPIKey)
            }
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

    private func toggleVoiceNoteRecording() async {
        errorMessage = nil

        if recordingPurpose == .voiceNote, appModel.audioRecorder.isRecording {
            guard let recording = await MainActor.run(body: {
                appModel.audioRecorder.stopRecording()
            }) else { return }
            recordingPurpose = nil

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

        await startRecording(for: .voiceNote)
    }

    private func toggleURLNoteRecording() async {
        errorMessage = nil

        if recordingPurpose == .urlNote, appModel.audioRecorder.isRecording {
            guard let recording = await MainActor.run(body: {
                appModel.audioRecorder.stopRecording()
            }) else { return }
            recordingPurpose = nil

            isTranscribingURLNote = true
            defer { isTranscribingURLNote = false }
            do {
                let transcript = try await appModel.transcriptionService.transcribe(audioURL: recording.url)
                appendURLNote(transcript)
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        await startRecording(for: .urlNote)
    }

    private func startRecording(for purpose: RecordingPurpose) async {
        guard !appModel.audioRecorder.isRecording else { return }

        let granted = await appModel.audioRecorder.requestPermission()
        guard granted else {
            errorMessage = "Microphone access is required to record audio."
            return
        }

        let recordingURL = await MainActor.run {
            appModel.audioRecorder.startRecording()
        }
        if recordingURL == nil {
            errorMessage = "Could not start recording. Check microphone access in Settings."
        } else {
            recordingPurpose = purpose
        }
    }

    private func appendURLNote(_ transcript: String) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let existing = urlNote.trimmingCharacters(in: .whitespacesAndNewlines)
        urlNote = existing.isEmpty ? trimmed : "\(existing)\n\n\(trimmed)"
        focusedField = .urlNote
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
    }
}
