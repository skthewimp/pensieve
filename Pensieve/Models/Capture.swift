import Foundation

enum CaptureKind: String, Codable, CaseIterable, Identifiable {
    case voice
    case text
    case url

    var id: String { rawValue }
}

enum ProcessingStatus: String, Codable {
    case pending
    case processing
    case processed
    case failed
}

struct Capture: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: CaptureKind
    var createdAt: Date
    var rawText: String
    var transcript: String?
    var sourceURLs: [URL]
    var audioFilePath: String?
    var processingStatus: ProcessingStatus
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        kind: CaptureKind,
        createdAt: Date = Date(),
        rawText: String,
        transcript: String? = nil,
        sourceURLs: [URL] = [],
        audioFilePath: String? = nil,
        processingStatus: ProcessingStatus = .pending,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.rawText = rawText
        self.transcript = transcript
        self.sourceURLs = sourceURLs
        self.audioFilePath = audioFilePath
        self.processingStatus = processingStatus
        self.errorMessage = errorMessage
    }
}
