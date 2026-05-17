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
    var sourceIdentifier: String?

    init(
        id: UUID = UUID(),
        kind: CaptureKind,
        createdAt: Date = Date(),
        rawText: String,
        transcript: String? = nil,
        sourceURLs: [URL] = [],
        audioFilePath: String? = nil,
        processingStatus: ProcessingStatus = .pending,
        errorMessage: String? = nil,
        sourceIdentifier: String? = nil
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
        self.sourceIdentifier = sourceIdentifier
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, createdAt, rawText, transcript, sourceURLs, audioFilePath
        case processingStatus, errorMessage, sourceIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(CaptureKind.self, forKey: .kind)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        rawText = try container.decode(String.self, forKey: .rawText)
        transcript = try container.decodeIfPresent(String.self, forKey: .transcript)
        sourceURLs = try container.decodeIfPresent([URL].self, forKey: .sourceURLs) ?? []
        audioFilePath = try container.decodeIfPresent(String.self, forKey: .audioFilePath)
        processingStatus = try container.decodeIfPresent(ProcessingStatus.self, forKey: .processingStatus) ?? .pending
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        sourceIdentifier = try container.decodeIfPresent(String.self, forKey: .sourceIdentifier)
    }
}
