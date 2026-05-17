import Foundation

actor CaptureService {
    private let store: LocalStore
    private let llmProvider: LLMProvider
    private let transcriptionService: TranscriptionService

    init(store: LocalStore, llmProvider: LLMProvider, transcriptionService: TranscriptionService) {
        self.store = store
        self.llmProvider = llmProvider
        self.transcriptionService = transcriptionService
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

    func submitVoice(audioURL: URL, duration: TimeInterval) async throws {
        var capture = Capture(
            kind: .voice,
            rawText: "",
            audioFilePath: audioURL.path
        )
        await store.saveCapture(capture)

        do {
            capture.processingStatus = .processing
            await store.saveCapture(capture)

            let transcript = try await transcriptionService.transcribe(audioURL: audioURL)
            capture.transcript = transcript
            capture.rawText = transcript
            await store.saveCapture(capture)

            let result = try await llmProvider.processCapture(
                CaptureProcessingInput(capture: capture, normalizedText: transcript)
            )
            var note = result.note
            note.body += "\n\n## Audio\nDuration: \(Self.formatDuration(duration))\nFile: \(audioURL.lastPathComponent)"
            await store.saveNote(note)

            capture.processingStatus = .processed
            await store.saveCapture(capture)
        } catch {
            capture.processingStatus = .failed
            capture.errorMessage = error.localizedDescription
            await store.saveCapture(capture)
            throw error
        }
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
