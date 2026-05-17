import Foundation

enum ContradictionStatus: String, Codable, CaseIterable, Identifiable {
    case unresolved
    case reviewed
    case dismissed

    var id: String { rawValue }
}

struct Contradiction: Identifiable, Codable, Equatable {
    var id: UUID
    var topic: String
    var beforeNoteID: UUID?
    var afterNoteID: UUID?
    var explanation: String
    var status: ContradictionStatus
    var confidence: Double?
    var createdAt: Date
    var updatedAt: Date
}
