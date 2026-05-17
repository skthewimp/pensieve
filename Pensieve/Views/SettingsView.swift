import SwiftUI

struct SettingsView: View {
    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Anthropic") {
                    SecureField("API key", text: $apiKey)
                    Button {
                        // Keychain persistence comes next.
                    } label: {
                        Label("Save API Key", systemImage: "key")
                    }
                }

                Section("Privacy") {
                    Text("Audio stays on device. Transcription happens on device. Text selected for processing is sent to Anthropic using your API key.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
