import Foundation

struct CaptureProcessingInput {
    var capture: Capture
    var normalizedText: String
}

struct CaptureProcessingResult {
    var note: MemoryNote
}

struct ChatRequest {
    var question: String
    var contextNotes: [MemoryNote]
}

struct ChatResponse {
    var answer: String
    var contextNoteIDs: [UUID]
}

protocol LLMProvider {
    func processCapture(_ input: CaptureProcessingInput) async throws -> CaptureProcessingResult
    func chat(_ request: ChatRequest) async throws -> ChatResponse
}

struct AnthropicProvider: LLMProvider {
    func processCapture(_ input: CaptureProcessingInput) async throws -> CaptureProcessingResult {
        let text = input.normalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = text.split(separator: "\n").first.map(String.init) ?? "Untitled"
        let note = MemoryNote(
            captureID: input.capture.id,
            title: title.isEmpty ? "Untitled" : title,
            summary: text,
            body: text
        )
        return CaptureProcessingResult(note: note)
    }

    func chat(_ request: ChatRequest) async throws -> ChatResponse {
        ChatResponse(
            answer: "Anthropic chat is not wired yet. This placeholder will become retrieval-backed Claude chat.",
            contextNoteIDs: request.contextNotes.map(\.id)
        )
    }
}
