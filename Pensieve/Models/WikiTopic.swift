import Foundation

struct WikiTopic: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var canonicalTheme: String
    var aliases: [String]
    var summary: String
    var currentUnderstanding: String
    var recurringSubthemes: [String]
    var openQuestions: [String]
    var sourceNoteIDs: [UUID]
    var relatedThemes: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        canonicalTheme: String,
        aliases: [String] = [],
        summary: String,
        currentUnderstanding: String,
        recurringSubthemes: [String] = [],
        openQuestions: [String] = [],
        sourceNoteIDs: [UUID],
        relatedThemes: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.canonicalTheme = canonicalTheme
        self.aliases = aliases
        self.summary = summary
        self.currentUnderstanding = currentUnderstanding
        self.recurringSubthemes = recurringSubthemes
        self.openQuestions = openQuestions
        self.sourceNoteIDs = sourceNoteIDs
        self.relatedThemes = relatedThemes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct TopicThemeAssignment: Codable, Equatable {
    var noteID: UUID
    var themes: [String]
}

struct TopicCleanupResult {
    var topics: [WikiTopic]
    var assignments: [TopicThemeAssignment]
}
