import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var apiKey = ""
    @State private var saveMessage: String?
    @State private var errorMessage: String?
    @State private var importMessage: String?
    @State private var isImporting = false
    @State private var isShowingImporter = false

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

                Section("Personal Import") {
                    Button {
                        isShowingImporter = true
                    } label: {
                        Label("Import SecondBrain Raw Folder", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isImporting)

                    if isImporting {
                        ProgressView("Importing...")
                    }

                    if let importMessage {
                        Text(importMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .fileImporter(
                isPresented: $isShowingImporter,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
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

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let folderURL = urls.first else { return }
            isImporting = true
            importMessage = nil

            Task {
                do {
                    let result = try await appModel.importSecondBrainRawFolder(folderURL)
                    await MainActor.run {
                        importMessage = "Imported \(result.importedCount) notes. Skipped \(result.skippedCount)."
                        isImporting = false
                    }
                } catch {
                    await MainActor.run {
                        importMessage = error.localizedDescription
                        isImporting = false
                    }
                }
            }
        case .failure(let error):
            importMessage = error.localizedDescription
        }
    }
}
