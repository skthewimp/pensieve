import Foundation

protocol LocalStore {
    func saveCapture(_ capture: Capture) async
    func saveNote(_ note: MemoryNote) async
    func saveImported(capture: Capture, note: MemoryNote) async
    func saveContradiction(_ contradiction: Contradiction) async
    func saveChatMessage(_ message: ChatMessage) async
    func loadCaptures() async -> [Capture]
    func loadNotes() async -> [MemoryNote]
    func loadContradictions() async -> [Contradiction]
    func loadChatMessages() async -> [ChatMessage]
}

actor FileLocalStore: LocalStore {
    private struct Snapshot: Codable {
        var captures: [Capture] = []
        var notes: [MemoryNote] = []
        var contradictions: [Contradiction] = []
        var chatMessages: [ChatMessage] = []
    }

    private var snapshot = Snapshot()
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pensieve", isDirectory: true)
        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)

        self.fileURL = baseURL.appendingPathComponent("local-store.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        self.snapshot = Self.loadFromDisk(fileURL: fileURL, decoder: decoder)
    }

    func saveCapture(_ capture: Capture) {
        upsert(capture, into: &snapshot.captures)
        snapshot.captures.sort { $0.createdAt > $1.createdAt }
        persist()
    }

    func saveNote(_ note: MemoryNote) {
        upsert(note, into: &snapshot.notes)
        snapshot.notes.sort { $0.createdAt > $1.createdAt }
        persist()
    }

    func saveImported(capture: Capture, note: MemoryNote) {
        if let sourceIdentifier = capture.sourceIdentifier,
           let existingCapture = snapshot.captures.first(where: { $0.sourceIdentifier == sourceIdentifier }) {
            var updatedCapture = capture
            updatedCapture.id = existingCapture.id
            upsert(updatedCapture, into: &snapshot.captures)

            var updatedNote = note
            updatedNote.captureID = existingCapture.id
            if let existingNote = snapshot.notes.first(where: { $0.sourceIdentifier == sourceIdentifier }) {
                updatedNote.id = existingNote.id
            }
            upsert(updatedNote, into: &snapshot.notes)
        } else {
            upsert(capture, into: &snapshot.captures)
            upsert(note, into: &snapshot.notes)
        }

        snapshot.captures.sort { $0.createdAt > $1.createdAt }
        snapshot.notes.sort { $0.createdAt > $1.createdAt }
        persist()
    }

    func saveContradiction(_ contradiction: Contradiction) {
        upsert(contradiction, into: &snapshot.contradictions)
        snapshot.contradictions.sort { $0.createdAt > $1.createdAt }
        persist()
    }

    func saveChatMessage(_ message: ChatMessage) {
        snapshot.chatMessages.append(message)
        persist()
    }

    func loadCaptures() -> [Capture] {
        snapshot.captures
    }

    func loadNotes() -> [MemoryNote] {
        snapshot.notes
    }

    func loadContradictions() -> [Contradiction] {
        snapshot.contradictions
    }

    func loadChatMessages() -> [ChatMessage] {
        snapshot.chatMessages
    }

    private static func loadFromDisk(fileURL: URL, decoder: JSONDecoder) -> Snapshot {
        guard let data = try? Data(contentsOf: fileURL) else { return Snapshot() }
        do {
            return try decoder.decode(Snapshot.self, from: data)
        } catch {
            print("Failed to load local store: \(error)")
            return Snapshot()
        }
    }

    private func persist() {
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Failed to persist local store: \(error)")
        }
    }

    private func upsert<T: Identifiable>(_ value: T, into values: inout [T]) where T.ID: Equatable {
        if let index = values.firstIndex(where: { $0.id == value.id }) {
            values[index] = value
        } else {
            values.insert(value, at: 0)
        }
    }
}

actor InMemoryLocalStore: LocalStore {
    private var captures: [Capture] = []
    private var notes: [MemoryNote] = []
    private var contradictions: [Contradiction] = []
    private var chatMessages: [ChatMessage] = []

    func saveCapture(_ capture: Capture) {
        upsert(capture, into: &captures)
    }

    func saveNote(_ note: MemoryNote) {
        upsert(note, into: &notes)
    }

    func saveImported(capture: Capture, note: MemoryNote) {
        if let sourceIdentifier = capture.sourceIdentifier,
           let existingCapture = captures.first(where: { $0.sourceIdentifier == sourceIdentifier }) {
            var updatedCapture = capture
            updatedCapture.id = existingCapture.id
            upsert(updatedCapture, into: &captures)

            var updatedNote = note
            updatedNote.captureID = existingCapture.id
            if let existingNote = notes.first(where: { $0.sourceIdentifier == sourceIdentifier }) {
                updatedNote.id = existingNote.id
            }
            upsert(updatedNote, into: &notes)
        } else {
            upsert(capture, into: &captures)
            upsert(note, into: &notes)
        }
    }

    func saveContradiction(_ contradiction: Contradiction) {
        upsert(contradiction, into: &contradictions)
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

    private func upsert<T: Identifiable>(_ value: T, into values: inout [T]) where T.ID: Equatable {
        if let index = values.firstIndex(where: { $0.id == value.id }) {
            values[index] = value
        } else {
            values.insert(value, at: 0)
        }
    }
}
