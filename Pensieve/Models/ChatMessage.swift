import Foundation

enum ChatRole: String, Codable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Codable, Equatable {
    var id: UUID
    var role: ChatRole
    var content: String
    var contextNoteIDs: [UUID]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        contextNoteIDs: [UUID] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.contextNoteIDs = contextNoteIDs
        self.createdAt = createdAt
    }
}
