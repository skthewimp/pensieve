import Foundation

struct CaptureProcessingInput {
    var capture: Capture
    var normalizedText: String
}

struct CaptureProcessingResult {
    var note: MemoryNote
    var articleFetched: Bool?
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

struct AnthropicProcessedNote: Codable {
    let title: String
    let summary: [String]
    let themes: [String]
    let emotionalTone: String
    let keyQuotes: [String]
    let connections: [String]
}

enum AnthropicError: LocalizedError {
    case apiKeyMissing
    case apiError(statusCode: Int, message: String)
    case noTextInResponse
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "Add your Anthropic API key in Settings."
        case .apiError(let statusCode, let message):
            return "Anthropic API error (\(statusCode)): \(message)"
        case .noTextInResponse:
            return "Anthropic returned no text response."
        case .invalidJSON:
            return "Could not parse Anthropic response."
        }
    }
}

struct AnthropicProvider: LLMProvider {
    private let keychain: KeychainService
    private let model = "claude-sonnet-4-6"
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    init(keychain: KeychainService) {
        self.keychain = keychain
    }

    func processCapture(_ input: CaptureProcessingInput) async throws -> CaptureProcessingResult {
        guard let apiKey = keychain.loadAnthropicAPIKey() else {
            throw AnthropicError.apiKeyMissing
        }

        let processed = try await processInput(
            text: input.normalizedText,
            urls: input.capture.sourceURLs,
            kind: input.capture.kind,
            apiKey: apiKey
        )

        let note = MemoryNote(
            captureID: input.capture.id,
            title: processed.note.title,
            summary: processed.note.summary.joined(separator: "\n"),
            body: buildNoteBody(input: input, processed: processed.note),
            themes: processed.note.themes,
            emotionalTone: processed.note.emotionalTone
        )

        return CaptureProcessingResult(note: note, articleFetched: processed.articleFetched)
    }

    func chat(_ request: ChatRequest) async throws -> ChatResponse {
        ChatResponse(
            answer: "Anthropic chat is not wired yet. This placeholder will become retrieval-backed Claude chat.",
            contextNoteIDs: request.contextNotes.map(\.id)
        )
    }

    private struct ProcessResult {
        var note: AnthropicProcessedNote
        var articleFetched: Bool?
    }

    private func processInput(text: String, urls: [URL], kind: CaptureKind, apiKey: String) async throws -> ProcessResult {
        let systemPrompt = Self.buildSystemPrompt(kind: kind)
        let userMessage = Self.buildUserMessage(text: text, urls: urls, kind: kind)

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]

        if kind == .url, !urls.isEmpty {
            body["tools"] = [[
                "type": "web_fetch_20250910",
                "name": "web_fetch",
                "max_uses": urls.count
            ]]
        }

        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")
        if kind == .url, !urls.isEmpty {
            urlRequest.addValue("web-fetch-2025-09-10", forHTTPHeaderField: "anthropic-beta")
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            throw AnthropicError.apiError(statusCode: statusCode, message: responseBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentBlocks = json["content"] as? [[String: Any]] else {
            throw AnthropicError.invalidJSON
        }

        var textOut: String?
        var anyFetchAttempted = false
        var anyFetchFailed = false

        for block in contentBlocks {
            let type = block["type"] as? String ?? ""
            switch type {
            case "text":
                textOut = block["text"] as? String
            case "web_fetch_tool_result", "tool_result":
                anyFetchAttempted = true
                if let content = block["content"] as? [String: Any],
                   (content["type"] as? String) == "web_fetch_tool_result_error" {
                    anyFetchFailed = true
                } else if let isError = block["is_error"] as? Bool, isError {
                    anyFetchFailed = true
                }
            case "server_tool_use":
                anyFetchAttempted = true
            default:
                break
            }
        }

        guard let textOut else { throw AnthropicError.noTextInResponse }
        let jsonString = extractJSON(from: textOut)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AnthropicError.invalidJSON
        }

        do {
            let note = try JSONDecoder().decode(AnthropicProcessedNote.self, from: jsonData)
            let fetched = kind == .url && !urls.isEmpty ? anyFetchAttempted && !anyFetchFailed : nil
            return ProcessResult(note: note, articleFetched: fetched)
        } catch {
            throw AnthropicError.invalidJSON
        }
    }

    private static func buildSystemPrompt(kind: CaptureKind) -> String {
        let base = """
        You are processing a thought capture for a local-first memory app called Pensieve. The user records stream-of-consciousness thoughts throughout their day: sometimes spoken aloud and transcribed, sometimes typed, sometimes a reaction to something they read online. Extract structure from the raw input.

        Return a JSON object with exactly these fields:
        {
          "title": "3-5 word title for this thought",
          "summary": ["bullet point 1", "bullet point 2"],
          "themes": ["theme1", "theme2"],
          "emotionalTone": "one word describing the emotional tone",
          "keyQuotes": ["notable phrase 1"],
          "connections": ["potential connection to topic X"]
        }

        Rules:
        - themes should be lowercase, simple words, such as "career", "health", "priorities", "relationships", "money", "creativity"
        - use consistent theme names across notes
        - keyQuotes should be verbatim phrases from the input
        - connections are speculative links to other life areas or recurring patterns
        - emotionalTone must be one of: reflective, anxious, excited, frustrated, hopeful, confused, determined, sad, neutral, angry, grateful
        - return only the JSON object, with no markdown or extra prose
        """

        if kind == .url {
            return base + """

            URL CONTEXT:
            The user has shared one or more URLs with their own text. Use the web_fetch tool to fetch each URL. Treat the article content as the thing the user is reacting to, and the user's text as their take on it. Themes, key quotes, and connections should reflect the user's reaction, not just summarize the article. If a fetch fails, proceed using the user's text alone.
            """
        }

        return base
    }

    private static func buildUserMessage(text: String, urls: [URL], kind: CaptureKind) -> String {
        switch kind {
        case .voice:
            return "Process this voice note transcription:\n\n\(text)"
        case .text:
            return "Process this typed thought:\n\n\(text)"
        case .url:
            let urlList = urls.map { "- \($0.absoluteString)" }.joined(separator: "\n")
            let userTake = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "(no additional text; extract from articles only)"
                : text
            return """
            The user is reacting to these URLs:
            \(urlList)

            User's take:
            \(userTake)

            Fetch each URL and return the structured JSON.
            """
        }
    }

    private func buildNoteBody(input: CaptureProcessingInput, processed: AnthropicProcessedNote) -> String {
        let quotes = processed.keyQuotes.isEmpty
            ? "No notable quotes extracted."
            : processed.keyQuotes.map { "> \($0)" }.joined(separator: "\n\n")
        let connections = processed.connections.isEmpty
            ? "No connections extracted."
            : processed.connections.map { "- \($0)" }.joined(separator: "\n")
        let sources = input.capture.sourceURLs.isEmpty
            ? ""
            : "\n\n## Sources\n" + input.capture.sourceURLs.map { "- \($0.absoluteString)" }.joined(separator: "\n")

        return """
        ## Summary
        \(processed.summary.map { "- \($0)" }.joined(separator: "\n"))

        ## Key Quotes
        \(quotes)

        ## Connections
        \(connections)

        ## Raw Input
        \(input.normalizedText)
        \(sources)
        """
    }

    private func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("```") {
            let lines = trimmed.components(separatedBy: "\n")
            return lines.dropFirst().dropLast().joined(separator: "\n")
        }

        return trimmed
    }
}
