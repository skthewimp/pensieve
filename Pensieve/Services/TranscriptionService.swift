import Foundation
import WhisperKit

enum TranscriptionProviderKind: String, CaseIterable, Identifiable {
    case whisperKit
    case openAI
    case sarvam

    var id: String { rawValue }

    var label: String {
        switch self {
        case .whisperKit:
            return "On-device Whisper"
        case .openAI:
            return "OpenAI"
        case .sarvam:
            return "Sarvam"
        }
    }
}

@MainActor
final class TranscriptionService: ObservableObject {
    @Published var isModelLoaded = false
    @Published var loadingProgress = "Not loaded"

    private static let modelName = "openai_whisper-small"
    private let keychain: KeychainService
    private let defaults: UserDefaults
    private let selectedProviderKey = "selected-transcription-provider"
    private let openAITranscriptionModelKey = "openai-transcription-model"
    private var whisperKit: WhisperKit?
    private var isLoadingModel = false

    init(keychain: KeychainService = KeychainService(), defaults: UserDefaults = .standard) {
        self.keychain = keychain
        self.defaults = defaults
    }

    var selectedProvider: TranscriptionProviderKind {
        get {
            guard let rawValue = defaults.string(forKey: selectedProviderKey),
                  let provider = TranscriptionProviderKind(rawValue: rawValue) else {
                return .whisperKit
            }
            return provider
        }
        set {
            defaults.set(newValue.rawValue, forKey: selectedProviderKey)
        }
    }

    var openAITranscriptionModel: String {
        let stored = defaults.string(forKey: openAITranscriptionModelKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return stored?.isEmpty == false ? stored! : "gpt-4o-transcribe"
    }

    func loadModel() async {
        guard selectedProvider == .whisperKit else {
            loadingProgress = "\(selectedProvider.label) selected"
            return
        }
        guard whisperKit == nil else { return }
        if isLoadingModel {
            while isLoadingModel, whisperKit == nil {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            return
        }

        isLoadingModel = true
        defer { isLoadingModel = false }

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
                loadingProgress = "Downloaded and ready"
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
            loadingProgress = "Downloaded and ready"
        } catch {
            isModelLoaded = false
            loadingProgress = "Failed: \(error.localizedDescription)"
            print("Failed to load WhisperKit: \(error)")
        }
    }

    func transcribe(audioURL: URL) async throws -> String {
        switch selectedProvider {
        case .whisperKit:
            return try await transcribeWithWhisperKit(audioURL: audioURL)
        case .openAI:
            return try await transcribeWithOpenAI(audioURL: audioURL)
        case .sarvam:
            return try await transcribeWithSarvam(audioURL: audioURL)
        }
    }

    private func transcribeWithWhisperKit(audioURL: URL) async throws -> String {
        await loadModel()

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

    private func transcribeWithOpenAI(audioURL: URL) async throws -> String {
        guard let apiKey = keychain.loadOpenAIAPIKey() else {
            throw TranscriptionError.apiKeyMissing("Add your OpenAI API key in Settings.")
        }

        let data = try multipartBody(
            fileURL: audioURL,
            fileFieldName: "file",
            parameters: ["model": openAITranscriptionModel]
        )
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("multipart/form-data; boundary=\(data.boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = data.body

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: responseData, encoding: .utf8) ?? "no body"
            throw TranscriptionError.apiError("OpenAI transcription error (\(statusCode)): \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let text = json["text"] as? String else {
            throw TranscriptionError.emptyResult
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranscriptionError.emptyResult }
        return trimmed
    }

    private func transcribeWithSarvam(audioURL: URL) async throws -> String {
        guard let apiKey = keychain.loadSarvamAPIKey() else {
            throw TranscriptionError.apiKeyMissing("Add your Sarvam API key in Settings.")
        }

        let data = try multipartBody(
            fileURL: audioURL,
            fileFieldName: "file",
            parameters: ["model": "saaras:v3"]
        )
        var request = URLRequest(url: URL(string: "https://api.sarvam.ai/speech-to-text")!)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "api-subscription-key")
        request.addValue("multipart/form-data; boundary=\(data.boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = data.body

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: responseData, encoding: .utf8) ?? "no body"
            throw TranscriptionError.apiError("Sarvam transcription error (\(statusCode)): \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw TranscriptionError.emptyResult
        }
        let text = (json["transcript"] as? String)
            ?? (json["text"] as? String)
            ?? (json["transcription"] as? String)
            ?? ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranscriptionError.emptyResult }
        return trimmed
    }

    private func multipartBody(fileURL: URL, fileFieldName: String, parameters: [String: String]) throws -> (body: Data, boundary: String) {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        for (key, value) in parameters {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendString("\(value)\r\n")
        }

        let fileData = try Data(contentsOf: fileURL)
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        body.appendString("Content-Type: audio/mp4\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")

        return (body, boundary)
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
    case apiKeyMissing(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model is not loaded yet."
        case .emptyResult:
            return "Transcription returned empty text."
        case .apiKeyMissing(let message):
            return message
        case .apiError(let message):
            return message
        }
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}
