import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var apiKey = ""
    @State private var saveMessage: String?
    @State private var errorMessage: String?
    @State private var importMessage: String?
    @State private var isImporting = false
    @State private var isShowingImporter = false
    @State private var backupDocument = PensieveBackupDocument()
    @State private var backupFilename = "pensieve-backup"
    @State private var backupMessage: String?
    @State private var isPreparingBackup = false
    @State private var isShowingBackupExporter = false
    @State private var isShowingBackupImporter = false
    @State private var isRestoringBackup = false
    @State private var analysisMessage: String?
    @State private var isAnalyzing = false

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

                Section("Backup") {
                    Button {
                        prepareBackup()
                    } label: {
                        Label("Export Pensieve Backup", systemImage: "externaldrive")
                    }
                    .disabled(isPreparingBackup || isRestoringBackup)

                    Button {
                        isShowingBackupImporter = true
                    } label: {
                        Label("Restore Pensieve Backup", systemImage: "arrow.clockwise.icloud")
                    }
                    .disabled(isPreparingBackup || isRestoringBackup)

                    if isPreparingBackup {
                        ProgressView("Preparing backup...")
                    }

                    if isRestoringBackup {
                        ProgressView("Restoring backup...")
                    }

                    if let backupMessage {
                        Text(backupMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Analysis") {
                    Button {
                        analyzeCorpus()
                    } label: {
                        Label("Analyze Corpus", systemImage: "sparkles")
                    }
                    .disabled(isAnalyzing || appModel.notes.isEmpty || !appModel.isAnthropicConfigured)

                    Button {
                        cleanUpTopics()
                    } label: {
                        Label("Clean Up Topics", systemImage: "rectangle.3.group")
                    }
                    .disabled(isAnalyzing || appModel.notes.isEmpty || !appModel.isAnthropicConfigured)

                    Button {
                        generateContradictions()
                    } label: {
                        Label("Find Contradictions", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(isAnalyzing || appModel.notes.isEmpty)

                    if isAnalyzing {
                        ProgressView("Analyzing notes...")
                    }

                    if let analysisMessage {
                        Text(analysisMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Migration") {
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
            .fileExporter(
                isPresented: $isShowingBackupExporter,
                document: backupDocument,
                contentType: .json,
                defaultFilename: backupFilename
            ) { result in
                handleBackupExport(result)
            }
            .fileImporter(
                isPresented: $isShowingBackupImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleBackupRestore(result)
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

    private func generateContradictions() {
        isAnalyzing = true
        analysisMessage = nil
        UIApplication.shared.isIdleTimerDisabled = true

        Task {
            do {
                let savedCount = try await appModel.generateContradictions()
                await MainActor.run {
                    analysisMessage = savedCount == 0 ? "No new contradictions found." : "Added \(savedCount) contradictions."
                    isAnalyzing = false
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            } catch {
                await MainActor.run {
                    analysisMessage = error.localizedDescription
                    isAnalyzing = false
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
        }
    }

    private func analyzeCorpus() {
        isAnalyzing = true
        analysisMessage = nil
        UIApplication.shared.isIdleTimerDisabled = true

        Task {
            do {
                let savedCount = try await appModel.analyzeCorpus()
                await MainActor.run {
                    analysisMessage = savedCount == 0 ? "No new insights found." : "Added \(savedCount) insights."
                    isAnalyzing = false
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            } catch {
                await MainActor.run {
                    analysisMessage = error.localizedDescription
                    isAnalyzing = false
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
        }
    }

    private func cleanUpTopics() {
        isAnalyzing = true
        analysisMessage = nil
        UIApplication.shared.isIdleTimerDisabled = true

        Task {
            do {
                let result = try await appModel.cleanUpTopics()
                await MainActor.run {
                    analysisMessage = "Updated \(result.updatedNotes) notes and generated \(result.topics) topics."
                    isAnalyzing = false
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            } catch {
                await MainActor.run {
                    analysisMessage = error.localizedDescription
                    isAnalyzing = false
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
        }
    }

    private func prepareBackup() {
        isPreparingBackup = true
        backupMessage = nil

        Task {
            do {
                let data = try await appModel.exportBackupData()
                let filename = appModel.backupFilename()
                await MainActor.run {
                    backupDocument = PensieveBackupDocument(data: data)
                    backupFilename = filename
                    isPreparingBackup = false
                    isShowingBackupExporter = true
                }
            } catch {
                await MainActor.run {
                    backupMessage = error.localizedDescription
                    isPreparingBackup = false
                }
            }
        }
    }

    private func handleBackupExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            backupMessage = "Backup exported."
        case .failure(let error):
            backupMessage = error.localizedDescription
        }
    }

    private func handleBackupRestore(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let backupURL = urls.first else { return }
            isRestoringBackup = true
            backupMessage = nil

            Task {
                do {
                    let didStartAccess = backupURL.startAccessingSecurityScopedResource()
                    defer {
                        if didStartAccess {
                            backupURL.stopAccessingSecurityScopedResource()
                        }
                    }

                    let data = try Data(contentsOf: backupURL)
                    try await appModel.restoreBackupData(data)
                    await MainActor.run {
                        backupMessage = "Backup restored."
                        isRestoringBackup = false
                    }
                } catch {
                    await MainActor.run {
                        backupMessage = error.localizedDescription
                        isRestoringBackup = false
                    }
                }
            }
        case .failure(let error):
            backupMessage = error.localizedDescription
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
