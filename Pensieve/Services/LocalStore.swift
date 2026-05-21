import Foundation

struct LocalStoreSnapshot: Codable {
    static let currentSchemaVersion = 3

    var schemaVersion: Int
    var captures: [Capture]
    var notes: [MemoryNote]
    var contradictions: [Contradiction]
    var insights: [Insight]
    var wikiTopics: [WikiTopic]
    var noteConnections: [NoteConnection]
    var chatMessages: [ChatMessage]

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        captures: [Capture] = [],
        notes: [MemoryNote] = [],
        contradictions: [Contradiction] = [],
        insights: [Insight] = [],
        wikiTopics: [WikiTopic] = [],
        noteConnections: [NoteConnection] = [],
        chatMessages: [ChatMessage] = []
    ) {
        self.schemaVersion = schemaVersion
        self.captures = captures
        self.notes = notes
        self.contradictions = contradictions
        self.insights = insights
        self.wikiTopics = wikiTopics
        self.noteConnections = noteConnections
        self.chatMessages = chatMessages
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, captures, notes, contradictions, insights, wikiTopics, noteConnections, chatMessages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        captures = try container.decodeIfPresent([Capture].self, forKey: .captures) ?? []
        notes = try container.decodeIfPresent([MemoryNote].self, forKey: .notes) ?? []
        contradictions = try container.decodeIfPresent([Contradiction].self, forKey: .contradictions) ?? []
        insights = try container.decodeIfPresent([Insight].self, forKey: .insights) ?? []
        wikiTopics = try container.decodeIfPresent([WikiTopic].self, forKey: .wikiTopics) ?? []
        noteConnections = try container.decodeIfPresent([NoteConnection].self, forKey: .noteConnections) ?? []
        chatMessages = try container.decodeIfPresent([ChatMessage].self, forKey: .chatMessages) ?? []
    }
}

protocol LocalStore {
    func saveCapture(_ capture: Capture) async
    func saveNote(_ note: MemoryNote) async
    func saveImported(capture: Capture, note: MemoryNote) async
    func saveContradiction(_ contradiction: Contradiction) async
    func saveInsight(_ insight: Insight) async
    func saveWikiTopic(_ topic: WikiTopic) async
    func saveNoteConnection(_ connection: NoteConnection) async
    func deleteWikiTopics() async
    func saveChatMessage(_ message: ChatMessage) async
    func exportBackupData() async throws -> Data
    func restoreBackupData(_ data: Data) async throws
    func loadCaptures() async -> [Capture]
    func loadNotes() async -> [MemoryNote]
    func loadContradictions() async -> [Contradiction]
    func loadInsights() async -> [Insight]
    func loadWikiTopics() async -> [WikiTopic]
    func loadNoteConnections() async -> [NoteConnection]
    func loadChatMessages() async -> [ChatMessage]
}

actor FileLocalStore: LocalStore {
    private var snapshot = LocalStoreSnapshot()
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

    func saveInsight(_ insight: Insight) {
        upsert(insight, into: &snapshot.insights)
        snapshot.insights.sort { $0.createdAt > $1.createdAt }
        persist()
    }

    func saveWikiTopic(_ topic: WikiTopic) {
        if let index = snapshot.wikiTopics.firstIndex(where: { $0.canonicalTheme == topic.canonicalTheme }) {
            snapshot.wikiTopics[index] = topic
        } else {
            snapshot.wikiTopics.insert(topic, at: 0)
        }
        snapshot.wikiTopics.sort { $0.sourceNoteIDs.count > $1.sourceNoteIDs.count }
        persist()
    }

    func saveNoteConnection(_ connection: NoteConnection) {
        upsert(connection, into: &snapshot.noteConnections)
        snapshot.noteConnections.sort { $0.createdAt > $1.createdAt }
        persist()
    }

    func deleteWikiTopics() {
        snapshot.wikiTopics = []
        persist()
    }

    func saveChatMessage(_ message: ChatMessage) {
        snapshot.chatMessages.append(message)
        persist()
    }

    func exportBackupData() throws -> Data {
        var exportSnapshot = snapshot
        exportSnapshot.schemaVersion = LocalStoreSnapshot.currentSchemaVersion
        return try encoder.encode(exportSnapshot)
    }

    func restoreBackupData(_ data: Data) throws {
        var restored = try decoder.decode(LocalStoreSnapshot.self, from: data)
        restored.schemaVersion = LocalStoreSnapshot.currentSchemaVersion
        restored.captures.sort { $0.createdAt > $1.createdAt }
        restored.notes.sort { $0.createdAt > $1.createdAt }
        restored.contradictions.sort { $0.createdAt > $1.createdAt }
        restored.insights.sort { $0.createdAt > $1.createdAt }
        restored.wikiTopics.sort { $0.sourceNoteIDs.count > $1.sourceNoteIDs.count }
        restored.noteConnections.sort { $0.createdAt > $1.createdAt }
        snapshot = restored
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

    func loadInsights() -> [Insight] {
        snapshot.insights
    }

    func loadWikiTopics() -> [WikiTopic] {
        snapshot.wikiTopics
    }

    func loadNoteConnections() -> [NoteConnection] {
        snapshot.noteConnections
    }

    func loadChatMessages() -> [ChatMessage] {
        snapshot.chatMessages
    }

    private static func loadFromDisk(fileURL: URL, decoder: JSONDecoder) -> LocalStoreSnapshot {
        guard let data = try? Data(contentsOf: fileURL) else { return LocalStoreSnapshot() }
        do {
            return try decoder.decode(LocalStoreSnapshot.self, from: data)
        } catch {
            print("Failed to load local store: \(error)")
            return LocalStoreSnapshot()
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
    private var insights: [Insight] = []
    private var wikiTopics: [WikiTopic] = []
    private var noteConnections: [NoteConnection] = []
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

    func saveInsight(_ insight: Insight) {
        upsert(insight, into: &insights)
    }

    func saveWikiTopic(_ topic: WikiTopic) {
        if let index = wikiTopics.firstIndex(where: { $0.canonicalTheme == topic.canonicalTheme }) {
            wikiTopics[index] = topic
        } else {
            wikiTopics.insert(topic, at: 0)
        }
    }

    func saveNoteConnection(_ connection: NoteConnection) {
        upsert(connection, into: &noteConnections)
    }

    func deleteWikiTopics() {
        wikiTopics = []
    }

    func saveChatMessage(_ message: ChatMessage) {
        chatMessages.append(message)
    }

    func exportBackupData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(
            LocalStoreSnapshot(
                captures: captures,
                notes: notes,
                contradictions: contradictions,
                insights: insights,
                wikiTopics: wikiTopics,
                noteConnections: noteConnections,
                chatMessages: chatMessages
            )
        )
    }

    func restoreBackupData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(LocalStoreSnapshot.self, from: data)
        captures = restored.captures.sorted { $0.createdAt > $1.createdAt }
        notes = restored.notes.sorted { $0.createdAt > $1.createdAt }
        contradictions = restored.contradictions.sorted { $0.createdAt > $1.createdAt }
        insights = restored.insights.sorted { $0.createdAt > $1.createdAt }
        wikiTopics = restored.wikiTopics.sorted { $0.sourceNoteIDs.count > $1.sourceNoteIDs.count }
        noteConnections = restored.noteConnections.sorted { $0.createdAt > $1.createdAt }
        chatMessages = restored.chatMessages
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

    func loadInsights() -> [Insight] {
        insights
    }

    func loadWikiTopics() -> [WikiTopic] {
        wikiTopics
    }

    func loadNoteConnections() -> [NoteConnection] {
        noteConnections
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
