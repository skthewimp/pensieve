import Foundation

actor CaptureService {
    private let store: LocalStore
    private let llmProvider: LLMProvider

    init(store: LocalStore, llmProvider: LLMProvider) {
        self.store = store
        self.llmProvider = llmProvider
    }

    func submitText(_ text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let capture = Capture(kind: .text, rawText: trimmed)
        await store.saveCapture(capture)

        let result = try await llmProvider.processCapture(
            CaptureProcessingInput(capture: capture, normalizedText: trimmed)
        )
        await store.saveNote(result.note)
    }

    func submitURL(_ rawURL: String, note: String) async throws {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return }

        let capture = Capture(
            kind: .url,
            rawText: note.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceURLs: [url]
        )
        await store.saveCapture(capture)

        let normalized = [url.absoluteString, note].joined(separator: "\n\n")
        let result = try await llmProvider.processCapture(
            CaptureProcessingInput(capture: capture, normalizedText: normalized)
        )
        await store.saveNote(result.note)
    }
}
