import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var captures: [Capture] = []
    @Published var notes: [MemoryNote] = []
    @Published var contradictions: [Contradiction] = []
    @Published var chatMessages: [ChatMessage] = []

    let captureService: CaptureService
    let localStore: LocalStore
    let llmProvider: LLMProvider

    init() {
        let store = InMemoryLocalStore()
        self.localStore = store
        self.llmProvider = AnthropicProvider()
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
}
