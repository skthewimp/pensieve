import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var captures: [Capture] = []
    @Published var notes: [MemoryNote] = []
    @Published var contradictions: [Contradiction] = []
    @Published var chatMessages: [ChatMessage] = []
    @Published var isAnthropicConfigured: Bool

    let captureService: CaptureService
    let localStore: LocalStore
    private let keychain: KeychainService
    private let llmProvider: LLMProvider

    init() {
        let store = FileLocalStore()
        let keychain = KeychainService()
        self.localStore = store
        self.keychain = keychain
        self.isAnthropicConfigured = keychain.hasAnthropicAPIKey()
        self.llmProvider = AnthropicProvider(keychain: keychain)
        self.captureService = CaptureService(store: store, llmProvider: llmProvider)

        Task {
            await refresh()
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
}
