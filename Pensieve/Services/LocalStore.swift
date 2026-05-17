import Foundation

protocol LocalStore {
    func saveCapture(_ capture: Capture) async
    func saveNote(_ note: MemoryNote) async
    func saveChatMessage(_ message: ChatMessage) async
    func loadCaptures() async -> [Capture]
    func loadNotes() async -> [MemoryNote]
    func loadContradictions() async -> [Contradiction]
    func loadChatMessages() async -> [ChatMessage]
}

actor InMemoryLocalStore: LocalStore {
    private var captures: [Capture] = []
    private var notes: [MemoryNote] = []
    private var contradictions: [Contradiction] = []
    private var chatMessages: [ChatMessage] = []

    func saveCapture(_ capture: Capture) {
        captures.insert(capture, at: 0)
    }

    func saveNote(_ note: MemoryNote) {
        notes.insert(note, at: 0)
    }

    func saveChatMessage(_ message: ChatMessage) {
        chatMessages.append(message)
    }

    func loadCaptures() -> [Capture] {
        captures
    }

    func loadNotes() -> [MemoryNote] {
        notes
    }

    func loadContradictions() -> [Contradiction] {
        contradictions
    }

    func loadChatMessages() -> [ChatMessage] {
        chatMessages
    }
}
