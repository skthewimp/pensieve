import Foundation
import WhisperKit

@MainActor
final class TranscriptionService: ObservableObject {
    @Published var isModelLoaded = false
    @Published var loadingProgress = "Not loaded"

    private static let modelName = "openai_whisper-small"
    private var whisperKit: WhisperKit?

    func loadModel() async {
        if let existingFolder = modelFolder() {
            loadingProgress = "Loading model..."
            do {
                whisperKit = try await WhisperKit(
                    WhisperKitConfig(
                        modelFolder: existingFolder,
                        verbose: false,
                        logLevel: .error,
                        load: true,
                        download: false
                    )
                )
                isModelLoaded = true
                loadingProgress = "Ready"
                return
            } catch {
                print("Failed to load cached WhisperKit model: \(error)")
            }
        }

        do {
            loadingProgress = "Downloading model..."
            whisperKit = try await WhisperKit(
                WhisperKitConfig(
                    model: Self.modelName,
                    verbose: false,
                    logLevel: .error,
                    load: true,
                    download: true
                )
            )
            isModelLoaded = true
            loadingProgress = "Ready"
        } catch {
            isModelLoaded = false
            loadingProgress = "Failed: \(error.localizedDescription)"
            print("Failed to load WhisperKit: \(error)")
        }
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard let whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        let results = try await whisperKit.transcribe(audioPath: audioURL.path)
        guard let result = results.first else {
            throw TranscriptionError.emptyResult
        }

        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw TranscriptionError.emptyResult
        }

        return text
    }

    private func modelFolder() -> String? {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsURL = documentsURL.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")
        guard let contents = try? FileManager.default.contentsOfDirectory(at: modelsURL, includingPropertiesForKeys: nil) else {
            return nil
        }

        for item in contents where item.lastPathComponent.contains(Self.modelName) {
            let files = (try? FileManager.default.contentsOfDirectory(at: item, includingPropertiesForKeys: nil)) ?? []
            if files.contains(where: { $0.pathExtension == "mlmodelc" }) {
                return item.path
            }
        }

        return nil
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model is not loaded yet."
        case .emptyResult:
            return "Transcription returned empty text."
        }
    }
}
