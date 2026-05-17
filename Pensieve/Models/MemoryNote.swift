import Foundation

struct MemoryNote: Identifiable, Codable, Equatable {
    var id: UUID
    var captureID: UUID
    var title: String
    var summary: String
    var body: String
    var themes: [String]
    var emotionalTone: String?
    var createdAt: Date
    var updatedAt: Date
    var sourceIdentifier: String?

    init(
        id: UUID = UUID(),
        captureID: UUID,
        title: String,
        summary: String,
        body: String,
        themes: [String] = [],
        emotionalTone: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sourceIdentifier: String? = nil
    ) {
        self.id = id
        self.captureID = captureID
        self.title = title
        self.summary = summary
        self.body = body
        self.themes = themes
        self.emotionalTone = emotionalTone
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceIdentifier = sourceIdentifier
    }

    enum CodingKeys: String, CodingKey {
        case id, captureID, title, summary, body, themes, emotionalTone
        case createdAt, updatedAt, sourceIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        captureID = try container.decode(UUID.self, forKey: .captureID)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        body = try container.decode(String.self, forKey: .body)
        themes = try container.decodeIfPresent([String].self, forKey: .themes) ?? []
        emotionalTone = try container.decodeIfPresent(String.self, forKey: .emotionalTone)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        sourceIdentifier = try container.decodeIfPresent(String.self, forKey: .sourceIdentifier)
    }
}
