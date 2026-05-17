import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var apiKey = ""
    @State private var saveMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Anthropic") {
                    SecureField("API key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        saveAPIKey()
                    } label: {
                        Label("Save API Key", systemImage: "key")
                    }

                    if appModel.isAnthropicConfigured {
                        Label("API key configured", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("API key required for processing", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                    }

                    if let saveMessage {
                        Text(saveMessage)
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section("Privacy") {
                    Text("Audio stays on device. Transcription happens on device. Text selected for processing is sent to Anthropic using your API key.")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func saveAPIKey() {
        do {
            try appModel.saveAnthropicAPIKey(apiKey)
            apiKey = ""
            saveMessage = appModel.isAnthropicConfigured ? "Saved." : "Removed."
            errorMessage = nil
        } catch {
            saveMessage = nil
            errorMessage = error.localizedDescription
        }
    }
}
