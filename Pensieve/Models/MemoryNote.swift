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

    init(
        id: UUID = UUID(),
        captureID: UUID,
        title: String,
        summary: String,
        body: String,
        themes: [String] = [],
        emotionalTone: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
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
    }
}
