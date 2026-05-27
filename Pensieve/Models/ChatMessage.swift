import Foundation

struct ChatSession: Identifiable, Codable, Equatable {
    static let legacySessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum ChatRole: String, Codable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Codable, Equatable {
    var id: UUID
    var sessionID: UUID
    var role: ChatRole
    var content: String
    var contextNoteIDs: [UUID]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sessionID: UUID = ChatSession.legacySessionID,
        role: ChatRole,
        content: String,
        contextNoteIDs: [UUID] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.role = role
        self.content = content
        self.contextNoteIDs = contextNoteIDs
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, sessionID, role, content, contextNoteIDs, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionID = try container.decodeIfPresent(UUID.self, forKey: .sessionID) ?? ChatSession.legacySessionID
        role = try container.decode(ChatRole.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        contextNoteIDs = try container.decodeIfPresent([UUID].self, forKey: .contextNoteIDs) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
