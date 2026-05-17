import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var captures: [Capture] = []
    @Published var notes: [MemoryNote] = []
    @Published var contradictions: [Contradiction] = []
    @Published var chatMessages: [ChatMessage] = []
    @Published var isAnthropicConfigured: Bool

    let audioRecorder = AudioRecorderService()
    let transcriptionService = TranscriptionService()
    let captureService: CaptureService
    let localStore: LocalStore
    private let keychain: KeychainService
    private let llmProvider: LLMProvider
    private let importService: SecondBrainImportService
    private var cancellables = Set<AnyCancellable>()

    init() {
        let store = FileLocalStore()
        let keychain = KeychainService()
        self.localStore = store
        self.keychain = keychain
        self.isAnthropicConfigured = keychain.hasAnthropicAPIKey()
        self.llmProvider = AnthropicProvider(keychain: keychain)
        self.importService = SecondBrainImportService(store: store)
        self.captureService = CaptureService(
            store: store,
            llmProvider: llmProvider,
            transcriptionService: transcriptionService
        )

        audioRecorder.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        transcriptionService.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        Task {
            await refresh()
            await transcriptionService.loadModel()
        }
    }

    func refresh() async {
        captures = await localStore.loadCaptures()
        notes = await localStore.loadNotes()
        contradictions = await localStore.loadContradictions()
        chatMessages = await localStore.loadChatMessages()
    }

    func saveAnthropicAPIKey(_ apiKey: String) throws {
        try keychain.saveAnthropicAPIKey(apiKey)
        isAnthropicConfigured = keychain.hasAnthropicAPIKey()
    }

    func sendChatMessage(_ content: String) async throws {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: trimmed)
        await localStore.saveChatMessage(userMessage)
        await refresh()

        let context = notesForQuery(trimmed)
        let response = try await llmProvider.chat(
            ChatRequest(question: trimmed, contextNotes: context)
        )
        let assistantMessage = ChatMessage(
            role: .assistant,
            content: response.answer,
            contextNoteIDs: response.contextNoteIDs
        )
        await localStore.saveChatMessage(assistantMessage)
        await refresh()
    }

    func importSecondBrainRawFolder(_ folderURL: URL) async throws -> SecondBrainImportResult {
        let result = try await importService.importRawFolder(folderURL)
        await refresh()
        return result
    }

    func generateContradictions() async throws -> Int {
        let existing = await localStore.loadContradictions()
        let existingFingerprints = Set(existing.map(Self.contradictionFingerprint))
        let generated = try await findContradictionsWithRetry()

        var savedCount = 0
        for contradiction in generated where !existingFingerprints.contains(Self.contradictionFingerprint(contradiction)) {
            await localStore.saveContradiction(contradiction)
            savedCount += 1
        }

        await refresh()
        return savedCount
    }

    private func findContradictionsWithRetry() async throws -> [Contradiction] {
        do {
            return try await llmProvider.findContradictions(in: notes)
        } catch {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return try await llmProvider.findContradictions(in: notes)
        }
    }

    func exportBackupData() async throws -> Data {
        try await localStore.exportBackupData()
    }

    func backupFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "pensieve-backup-\(formatter.string(from: Date()))"
    }

    private static func contradictionFingerprint(_ contradiction: Contradiction) -> String {
        [
            contradiction.topic.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            contradiction.beforeNoteID?.uuidString ?? "",
            contradiction.afterNoteID?.uuidString ?? ""
        ].joined(separator: "|")
    }

    private func notesForQuery(_ query: String) -> [MemoryNote] {
        let queryTerms = Set(
            query
                .lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count > 2 }
        )

        let scored = notes.map { note in
            let haystack = ([note.title, note.summary, note.body] + note.themes)
                .joined(separator: " ")
                .lowercased()
            let score = queryTerms.reduce(0) { partial, term in
                partial + (haystack.contains(term) ? 1 : 0)
            }
            return (note: note, score: score)
        }

        let matched = scored
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .map(\.note)

        return Array((matched.isEmpty ? notes : matched).prefix(8))
    }
}
