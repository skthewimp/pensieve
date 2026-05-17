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

        var capture = Capture(kind: .text, rawText: trimmed)
        await store.saveCapture(capture)

        do {
            capture.processingStatus = .processing
            await store.saveCapture(capture)

            let result = try await llmProvider.processCapture(
                CaptureProcessingInput(capture: capture, normalizedText: trimmed)
            )
            await store.saveNote(result.note)

            capture.processingStatus = .processed
            await store.saveCapture(capture)
        } catch {
            capture.processingStatus = .failed
            capture.errorMessage = error.localizedDescription
            await store.saveCapture(capture)
            throw error
        }
    }

    func submitURL(_ rawURL: String, note: String) async throws {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return }

        var capture = Capture(
            kind: .url,
            rawText: note.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceURLs: [url]
        )
        await store.saveCapture(capture)

        do {
            capture.processingStatus = .processing
            await store.saveCapture(capture)

            let normalized = [url.absoluteString, note].joined(separator: "\n\n")
            let result = try await llmProvider.processCapture(
                CaptureProcessingInput(capture: capture, normalizedText: normalized)
            )
            await store.saveNote(result.note)

            capture.processingStatus = .processed
            await store.saveCapture(capture)
        } catch {
            capture.processingStatus = .failed
            capture.errorMessage = error.localizedDescription
            await store.saveCapture(capture)
            throw error
        }
    }
}
