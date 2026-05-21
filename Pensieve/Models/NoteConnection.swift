import Foundation

enum NoteConnectionKind: String, Codable, CaseIterable, Identifiable {
    case backlink
    case thread

    var id: String { rawValue }

    var label: String {
        switch self {
        case .backlink:
            return "Backlink"
        case .thread:
            return "Thread"
        }
    }
}

struct NoteConnection: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: NoteConnectionKind
    var title: String
    var explanation: String
    var sourceNoteIDs: [UUID]
    var themes: [String]
    var confidence: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        kind: NoteConnectionKind,
        title: String,
        explanation: String,
        sourceNoteIDs: [UUID],
        themes: [String] = [],
        confidence: Double,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.explanation = explanation
        self.sourceNoteIDs = sourceNoteIDs
        self.themes = themes
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
