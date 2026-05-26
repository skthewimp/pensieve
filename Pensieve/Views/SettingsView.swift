import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var apiKey = ""
    @State private var openAIAPIKey = ""
    @State private var sarvamAPIKey = ""
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
    @State private var topicCleanupPreview: TopicCleanupPreview?

    var body: some View {
        NavigationStack {
            Form {
                Section("Getting Started") {
                    GettingStartedStep(number: 1, text: "Choose an LLM provider and save its API key.")
                    GettingStartedStep(number: 2, text: "Capture voice, text, or URLs from the Capture tab.")
                    GettingStartedStep(number: 3, text: "Use Notes and Wiki to browse saved memory.")
                    GettingStartedStep(number: 4, text: "Use Chat to ask questions over your notes.")
                    GettingStartedStep(number: 5, text: "Run analysis tools here when you want digests, links, insights, topic cleanup, or contradictions.")
                }

                Section("AI Processing") {
                    Picker("LLM provider", selection: Binding(
                        get: { appModel.selectedLLMProvider },
                        set: { appModel.setLLMProvider($0) }
                    )) {
                        ForEach(LLMProviderKind.allCases) { provider in
                            Text(provider.label).tag(provider)
                        }
                    }

                    Text("Capture processing, chat, insights, topic cleanup, and contradictions use the selected LLM provider.")
                        .foregroundStyle(.secondary)

                    SecureField("Anthropic API key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        Button {
                            saveAPIKey()
                        } label: {
                            Label("Save Anthropic Key", systemImage: "key")
                        }

                        Button(role: .destructive) {
                            deleteAnthropicAPIKey()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(!appModel.isAnthropicConfigured)
                    }

                    if appModel.isAnthropicConfigured {
                        Label("Anthropic key configured", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Anthropic key not configured", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                    }

                    SecureField("OpenAI API key", text: $openAIAPIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        Button {
                            saveOpenAIAPIKey()
                        } label: {
                            Label("Save OpenAI Key", systemImage: "key")
                        }

                        Button(role: .destructive) {
                            deleteOpenAIAPIKey()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(!appModel.isOpenAIConfigured)
                    }

                    if appModel.isOpenAIConfigured {
                        Label("OpenAI key configured", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("OpenAI key not configured", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                    }

                    if appModel.isSelectedLLMConfigured {
                        Label("\(appModel.selectedLLMProvider.label) ready", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Selected LLM provider needs an API key", systemImage: "exclamationmark.circle")
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

                Section("Transcription") {
                    Picker("Provider", selection: Binding(
                        get: { appModel.selectedTranscriptionProvider },
                        set: { appModel.setTranscriptionProvider($0) }
                    )) {
                        ForEach(TranscriptionProviderKind.allCases) { provider in
                            Text(provider.label).tag(provider)
                        }
                    }

                    Text("Voice recordings can be transcribed on device, or sent to a selected cloud transcription provider.")
                        .foregroundStyle(.secondary)

                    SecureField("Sarvam API key", text: $sarvamAPIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        Button {
                            saveSarvamAPIKey()
                        } label: {
                            Label("Save Sarvam Key", systemImage: "key")
                        }

                        Button(role: .destructive) {
                            deleteSarvamAPIKey()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(!appModel.isSarvamConfigured)
                    }

                    if appModel.isSarvamConfigured {
                        Label("Sarvam key configured", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Sarvam key not configured", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Privacy") {
                    Text("Audio stays on device only when On-device Whisper is selected. Cloud transcription sends audio to the selected transcription provider. Text selected for processing is sent to the selected LLM provider using your API key.")
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
                        generateWeeklyDigest()
                    } label: {
                        Label("Generate Weekly Digest", systemImage: "calendar.badge.clock")
                    }
                    .disabled(isAnalyzing || appModel.notes.isEmpty || !appModel.isSelectedLLMConfigured)

                    Button {
                        connectNotesRetrospectively()
                    } label: {
                        Label("Connect Notes Retrospectively", systemImage: "link")
                    }
                    .disabled(isAnalyzing || appModel.notes.count < 2 || !appModel.isSelectedLLMConfigured)

                    Button {
                        analyzeCorpus()
                    } label: {
                        Label("Analyze Corpus", systemImage: "sparkles")
                    }
                    .disabled(isAnalyzing || appModel.notes.isEmpty || !appModel.isSelectedLLMConfigured)

                    Button {
                        prepareTopicCleanupPreview()
                    } label: {
                        Label("Preview Topic Cleanup", systemImage: "rectangle.3.group")
                    }
                    .disabled(isAnalyzing || appModel.notes.isEmpty || !appModel.isSelectedLLMConfigured)

                    if let topicCleanupPreview {
                        TopicCleanupDiagnosticsView(
                            title: "Cleanup Preview",
                            diagnostics: topicCleanupPreview.diagnostics
                        )

                        Button {
                            applyTopicCleanupPreview(topicCleanupPreview)
                        } label: {
                            Label("Apply Topic Cleanup", systemImage: "checkmark.circle")
                        }
                        .disabled(isAnalyzing)

                        Button(role: .cancel) {
                            self.topicCleanupPreview = nil
                        } label: {
                            Label("Discard Preview", systemImage: "xmark.circle")
                        }
                        .disabled(isAnalyzing)
                    } else if let diagnostics = appModel.lastTopicCleanupDiagnostics {
                        TopicCleanupDiagnosticsView(
                            title: "Last Cleanup",
                            diagnostics: diagnostics
                        )
                    }

                    Button {
                        generateContradictions()
                    } label: {
                        Label("Find Contradictions", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(isAnalyzing || appModel.notes.isEmpty || !appModel.isSelectedLLMConfigured)

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
            saveMessage = appModel.isAnthropicConfigured ? "Anthropic key saved." : "Anthropic key removed."
            errorMessage = nil
        } catch {
            saveMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAnthropicAPIKey() {
        do {
            try appModel.deleteAnthropicAPIKey()
            apiKey = ""
            saveMessage = "Anthropic key deleted."
            errorMessage = nil
        } catch {
            saveMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func saveOpenAIAPIKey() {
        do {
            try appModel.saveOpenAIAPIKey(openAIAPIKey)
            openAIAPIKey = ""
            saveMessage = appModel.isOpenAIConfigured ? "OpenAI key saved." : "OpenAI key removed."
            errorMessage = nil
        } catch {
            saveMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func deleteOpenAIAPIKey() {
        do {
            try appModel.deleteOpenAIAPIKey()
            openAIAPIKey = ""
            saveMessage = "OpenAI key deleted."
            errorMessage = nil
        } catch {
            saveMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func saveSarvamAPIKey() {
        do {
            try appModel.saveSarvamAPIKey(sarvamAPIKey)
            sarvamAPIKey = ""
            saveMessage = appModel.isSarvamConfigured ? "Sarvam key saved." : "Sarvam key removed."
            errorMessage = nil
        } catch {
            saveMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSarvamAPIKey() {
        do {
            try appModel.deleteSarvamAPIKey()
            sarvamAPIKey = ""
            saveMessage = "Sarvam key deleted."
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

    private func generateWeeklyDigest() {
        isAnalyzing = true
        analysisMessage = nil
        UIApplication.shared.isIdleTimerDisabled = true

        Task {
            do {
                _ = try await appModel.generateWeeklyDigest()
                await MainActor.run {
                    analysisMessage = "Weekly digest added to Insights."
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

    private func connectNotesRetrospectively() {
        isAnalyzing = true
        analysisMessage = nil
        UIApplication.shared.isIdleTimerDisabled = true

        Task {
            do {
                let savedCount = try await appModel.connectNotesRetrospectively()
                await MainActor.run {
                    analysisMessage = savedCount == 0 ? "No new retrospective connections found." : "Added \(savedCount) retrospective connections."
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

    private func prepareTopicCleanupPreview() {
        isAnalyzing = true
        analysisMessage = nil
        topicCleanupPreview = nil
        UIApplication.shared.isIdleTimerDisabled = true

        Task {
            do {
                let preview = try await appModel.prepareTopicCleanupPreview()
                await MainActor.run {
                    topicCleanupPreview = preview
                    analysisMessage = "Topic cleanup preview ready."
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

    private func applyTopicCleanupPreview(_ preview: TopicCleanupPreview) {
        isAnalyzing = true
        analysisMessage = nil
        UIApplication.shared.isIdleTimerDisabled = true

        Task {
            do {
                let diagnostics = try await appModel.applyTopicCleanupPreview(preview)
                await MainActor.run {
                    topicCleanupPreview = nil
                    analysisMessage = "Updated \(diagnostics.updatedNoteCount) notes and generated \(diagnostics.generatedTopicCount) topics."
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

private struct GettingStartedStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

private struct TopicCleanupDiagnosticsView: View {
    let title: String
    let diagnostics: TopicCleanupDiagnostics

    private var runDate: String {
        diagnostics.runAt.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            LabeledContent("Source", value: diagnostics.source.rawValue)
            if let fallbackReason = diagnostics.fallbackReason, !fallbackReason.isEmpty {
                Text(fallbackReason)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Notes to update", value: "\(diagnostics.updatedNoteCount)")
            LabeledContent("Topics", value: "\(diagnostics.generatedTopicCount)")
            LabeledContent("Run time", value: runDate)

            if !diagnostics.largestGroups.isEmpty {
                Text("Largest groups")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(diagnostics.largestGroups) { group in
                    HStack {
                        Text(group.theme.capitalized)
                        Spacer()
                        Text("\(group.noteCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .font(.subheadline)
        .padding(.vertical, 4)
    }
}
