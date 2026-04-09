import Foundation
import WhisperKit

/// On-device transcription using WhisperKit.
/// Runs entirely on the iPhone's Neural Engine — no network needed.
class TranscriptionService: ObservableObject {
    private var whisperKit: WhisperKit?
    @Published var isModelLoaded = false
    @Published var loadingProgress: String = "Not loaded"

    /// Load the Whisper model. Call once at app startup.
    /// Uses "base" model for balance of speed and accuracy on iPhone.
    func loadModel() async {
        do {
            await MainActor.run { loadingProgress = "Downloading model..." }
            whisperKit = try await WhisperKit(
                WhisperKitConfig(model: "openai_whisper-base", verbose: true, logLevel: .debug)
            )
            await MainActor.run {
                isModelLoaded = true
                loadingProgress = "Ready"
            }
            print("WhisperKit model loaded")
        } catch {
            await MainActor.run { loadingProgress = "Failed: \(error.localizedDescription)" }
            print("Failed to load WhisperKit: \(error)")
        }
    }

    /// Transcribe an audio file. Returns the full text.
    func transcribe(audioURL: URL) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        let results = try await whisperKit.transcribe(audioPath: audioURL.path)

        guard let result = results.first, !result.text.isEmpty else {
            throw TranscriptionError.emptyResult
        }

        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "Whisper model not loaded yet"
        case .emptyResult: return "Transcription returned empty result"
        }
    }
}
