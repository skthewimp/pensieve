import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var captureService: ThoughtCaptureService
    @Environment(\.dismiss) var dismiss

    @AppStorage("anthropicAPIKey") private var apiKey = ""
    @State private var tempAPIKey = ""
    @State private var showAPIKey = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if showAPIKey {
                            TextField("sk-ant-...", text: $tempAPIKey)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("sk-ant-...", text: $tempAPIKey)
                                .textContentType(.password)
                                .autocapitalization(.none)
                        }

                        Button(action: { showAPIKey.toggle() }) {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }

                    Button("Save API Key") {
                        apiKey = tempAPIKey
                        captureService.configure(apiKey: apiKey)
                    }
                    .disabled(tempAPIKey.isEmpty)

                    HStack {
                        Text("Status")
                        Spacer()
                        Text(captureService.isConfigured ? "Configured" : "Not Set")
                            .foregroundColor(captureService.isConfigured ? .green : .orange)
                    }
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Your API key is stored locally on this device. Get one from console.anthropic.com.")
                }

                Section("Whisper Model") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(captureService.transcriptionService.loadingProgress)
                            .foregroundColor(captureService.transcriptionService.isModelLoaded ? .green : .orange)
                    }

                    if !captureService.transcriptionService.isModelLoaded {
                        Button("Load Model") {
                            Task { await captureService.loadWhisperModel() }
                        }
                    }
                }

                Section("Stats") {
                    HStack {
                        Text("Total Thoughts")
                        Spacer()
                        Text("\(captureService.notes.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Saved to Wiki")
                        Spacer()
                        Text("\(captureService.notes.filter { $0.savedToWiki }.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Wiki Notes")
                        Spacer()
                        Text("\(captureService.storageService.rawNoteCount())")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Text("Your thoughts are processed on-device (transcription) and via Claude API (analysis). Raw audio stays on your phone. Only the transcription text is sent to Claude for theme extraction.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Privacy")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                tempAPIKey = apiKey
                if !apiKey.isEmpty {
                    captureService.configure(apiKey: apiKey)
                }
            }
        }
    }
}
