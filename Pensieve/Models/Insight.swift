import Foundation

enum InsightKind: String, Codable, CaseIterable, Identifiable {
    case themeSummary
    case pattern
    case openLoop
    case question
    case decision
    case beliefShift

    var id: String { rawValue }

    var label: String {
        switch self {
        case .themeSummary:
            return "Theme"
        case .pattern:
            return "Pattern"
        case .openLoop:
            return "Open Loop"
        case .question:
            return "Question"
        case .decision:
            return "Decision"
        case .beliefShift:
            return "Belief Shift"
        }
    }
}

enum InsightStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case accepted
    case dismissed
    case important
    case superseded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending:
            return "Pending"
        case .accepted:
            return "Accepted"
        case .dismissed:
            return "Dismissed"
        case .important:
            return "Important"
        case .superseded:
            return "Superseded"
        }
    }
}

struct Insight: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: InsightKind
    var title: String
    var explanation: String
    var sourceNoteIDs: [UUID]
    var themes: [String]
    var confidence: Double?
    var status: InsightStatus
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        kind: InsightKind,
        title: String,
        explanation: String,
        sourceNoteIDs: [UUID],
        themes: [String] = [],
        confidence: Double? = nil,
        status: InsightStatus = .pending,
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
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
