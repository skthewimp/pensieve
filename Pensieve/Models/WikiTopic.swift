import Foundation

enum WikiTopicStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case useful
    case stale
    case needsRefresh
    case dismissed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending:
            return "Pending"
        case .useful:
            return "Useful"
        case .stale:
            return "Stale"
        case .needsRefresh:
            return "Marked for Refresh"
        case .dismissed:
            return "Dismissed"
        }
    }
}

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
    var status: WikiTopicStatus
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
        status: WikiTopicStatus = .pending,
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
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, canonicalTheme, aliases, summary, currentUnderstanding
        case recurringSubthemes, openQuestions, sourceNoteIDs, relatedThemes
        case status, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        canonicalTheme = try container.decode(String.self, forKey: .canonicalTheme)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        summary = try container.decode(String.self, forKey: .summary)
        currentUnderstanding = try container.decode(String.self, forKey: .currentUnderstanding)
        recurringSubthemes = try container.decodeIfPresent([String].self, forKey: .recurringSubthemes) ?? []
        openQuestions = try container.decodeIfPresent([String].self, forKey: .openQuestions) ?? []
        sourceNoteIDs = try container.decodeIfPresent([UUID].self, forKey: .sourceNoteIDs) ?? []
        relatedThemes = try container.decodeIfPresent([String].self, forKey: .relatedThemes) ?? []
        status = try container.decodeIfPresent(WikiTopicStatus.self, forKey: .status) ?? .pending
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

struct TopicThemeAssignment: Codable, Equatable {
    var noteID: UUID
    var themes: [String]
}

struct TopicCleanupResult: Equatable {
    var topics: [WikiTopic]
    var assignments: [TopicThemeAssignment]
}

enum TopicCleanupSource: String, Equatable {
    case llm = "LLM taxonomy"
    case localFallback = "Local fallback"
}

struct TopicCleanupGroupSummary: Identifiable, Equatable {
    var id: String { theme }
    var theme: String
    var noteCount: Int
}

struct TopicCleanupDiagnostics: Equatable {
    var source: TopicCleanupSource
    var fallbackReason: String?
    var updatedNoteCount: Int
    var generatedTopicCount: Int
    var largestGroups: [TopicCleanupGroupSummary]
    var runAt: Date
}

struct TopicCleanupPreview: Equatable {
    var result: TopicCleanupResult
    var diagnostics: TopicCleanupDiagnostics
}
