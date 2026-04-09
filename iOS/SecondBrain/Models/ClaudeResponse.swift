import Foundation

/// Structured response from Claude API after processing a voice note
struct ClaudeProcessedNote: Codable {
    let title: String
    let summary: [String]        // Bullet points
    let themes: [String]         // Detected themes (e.g., "career", "health", "priorities")
    let emotionalTone: String    // e.g., "reflective", "anxious", "excited", "frustrated"
    let keyQuotes: [String]      // Notable phrases worth preserving verbatim
    let connections: [String]    // Potential connections to other topics (for wiki cross-referencing)
}

/// Claude API message format
struct ClaudeAPIRequest: Codable {
    let model: String
    let max_tokens: Int
    let messages: [ClaudeMessage]
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeAPIResponse: Codable {
    let content: [ClaudeContentBlock]
}

struct ClaudeContentBlock: Codable {
    let type: String
    let text: String?
}
