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
    func findContradictions(in notes: [MemoryNote]) async throws -> [Contradiction]
    func analyzeCorpus(_ notes: [MemoryNote]) async throws -> [Insight]
    func generateWeeklyDigest(from notes: [MemoryNote]) async throws -> Insight
    func generateNoteConnections(from notes: [MemoryNote]) async throws -> [NoteConnection]
    func cleanUpTopics(_ notes: [MemoryNote]) async throws -> TopicCleanupResult
    func generateWikiTopicPage(topic: WikiTopic, notes: [MemoryNote]) async throws -> WikiTopic
}

struct AnthropicProcessedNote: Codable {
    let title: String
    let summary: [String]
    let themes: [String]
    let emotionalTone: String
    let keyQuotes: [String]
    let connections: [String]
}

struct AnthropicContradictionsResponse: Codable {
    let contradictions: [AnthropicContradiction]
}

struct AnthropicContradiction: Codable {
    let topic: String
    let beforeNoteID: UUID?
    let afterNoteID: UUID?
    let explanation: String
    let confidence: Double?
}

struct AnthropicInsightsResponse: Codable {
    let insights: [AnthropicInsight]
}

struct AnthropicInsight: Codable {
    let kind: InsightKind
    let title: String
    let explanation: String
    let sourceNoteIDs: [UUID]
    let themes: [String]
    let confidence: Double?
}

struct AnthropicNoteConnectionsResponse: Codable {
    let connections: [AnthropicNoteConnection]
}

struct AnthropicNoteConnection: Codable {
    let kind: NoteConnectionKind
    let title: String
    let explanation: String
    let sourceNoteIDs: [UUID]
    let themes: [String]
    let confidence: Double?
}

struct AnthropicTopicCleanupResponse: Codable {
    let topics: [AnthropicWikiTopic]
    let noteThemeAssignments: [AnthropicTopicThemeAssignment]

    enum CodingKeys: String, CodingKey {
        case topics, noteThemeAssignments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        topics = try container.decodeIfPresent([AnthropicWikiTopic].self, forKey: .topics) ?? []
        noteThemeAssignments = try container.decodeIfPresent([AnthropicTopicThemeAssignment].self, forKey: .noteThemeAssignments) ?? []
    }
}

struct AnthropicWikiTopic: Codable {
    let title: String
    let canonicalTheme: String
    let aliases: [String]
    let summary: String
    let currentUnderstanding: String
    let recurringSubthemes: [String]
    let openQuestions: [String]
    let sourceNoteIDs: [UUID]
    let relatedThemes: [String]

    enum CodingKeys: String, CodingKey {
        case title, canonicalTheme, aliases, summary, currentUnderstanding
        case recurringSubthemes, openQuestions, sourceNoteIDs, relatedThemes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        canonicalTheme = try container.decodeIfPresent(String.self, forKey: .canonicalTheme) ?? ""
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        currentUnderstanding = try container.decodeIfPresent(String.self, forKey: .currentUnderstanding) ?? ""
        recurringSubthemes = try container.decodeIfPresent([String].self, forKey: .recurringSubthemes) ?? []
        openQuestions = try container.decodeIfPresent([String].self, forKey: .openQuestions) ?? []
        relatedThemes = try container.decodeIfPresent([String].self, forKey: .relatedThemes) ?? []
        let rawSourceIDs = try container.decodeIfPresent([String].self, forKey: .sourceNoteIDs) ?? []
        sourceNoteIDs = rawSourceIDs.compactMap(UUID.init(uuidString:))
    }
}

struct AnthropicTopicThemeAssignment: Codable {
    let noteID: UUID?
    let themes: [String]

    enum CodingKeys: String, CodingKey {
        case noteID, themes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawNoteID = try container.decodeIfPresent(String.self, forKey: .noteID)
        noteID = rawNoteID.flatMap(UUID.init(uuidString:))
        themes = try container.decodeIfPresent([String].self, forKey: .themes) ?? []
    }
}

struct AnthropicWikiTopicPageResponse: Codable {
    let title: String
    let summary: String
    let currentUnderstanding: String
    let recurringSubthemes: [String]
    let openQuestions: [String]
    let relatedThemes: [String]
}

enum AnthropicError: LocalizedError {
    case apiKeyMissing
    case apiError(statusCode: Int, message: String)
    case noTextInResponse
    case invalidJSON(String = "Could not parse Anthropic response.")

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "Add your Anthropic API key in Settings."
        case .apiError(let statusCode, let message):
            return "Anthropic API error (\(statusCode)): \(message)"
        case .noTextInResponse:
            return "Anthropic returned no text response."
        case .invalidJSON(let message):
            return message
        }
    }
}

struct AnthropicProvider: LLMProvider {
    private let keychain: KeychainService
    private let model = "claude-sonnet-4-20250514"
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
        guard let apiKey = keychain.loadAnthropicAPIKey() else {
            throw AnthropicError.apiKeyMissing
        }

        let context = request.contextNotes.map { note in
            """
            Note ID: \(note.id.uuidString)
            Title: \(note.title)
            Themes: \(note.themes.joined(separator: ", "))
            Summary:
            \(note.summary)
            Body:
            \(note.body)
            """
        }.joined(separator: "\n\n---\n\n")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": """
            You answer questions for a local-first personal memory app. Use the provided notes as source material. If the notes do not contain enough evidence, say so directly. Be concise, concrete, and cite the note titles you used in plain language.
            """,
            "messages": [
                [
                    "role": "user",
                    "content": """
                    Question:
                    \(request.question)

                    Available notes:
                    \(context.isEmpty ? "(no saved notes yet)" : context)
                    """
                ]
            ]
        ]

        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            throw AnthropicError.apiError(statusCode: statusCode, message: responseBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentBlocks = json["content"] as? [[String: Any]] else {
            throw AnthropicError.invalidJSON()
        }

        let answer = contentBlocks.compactMap { block -> String? in
            guard (block["type"] as? String) == "text" else { return nil }
            return block["text"] as? String
        }.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !answer.isEmpty else {
            throw AnthropicError.noTextInResponse
        }

        return ChatResponse(
            answer: answer,
            contextNoteIDs: request.contextNotes.map(\.id)
        )
    }

    func findContradictions(in notes: [MemoryNote]) async throws -> [Contradiction] {
        guard let apiKey = keychain.loadAnthropicAPIKey() else {
            throw AnthropicError.apiKeyMissing
        }

        let noteDigest = notes
            .sorted { $0.createdAt < $1.createdAt }
            .map(Self.buildContradictionDigest)
            .joined(separator: "\n\n---\n\n")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "system": """
            You analyze a personal note corpus for meaningful contradictions, changed beliefs, recurring tensions, and shifts in priorities. Only return contradictions that are supported by the provided notes. Prefer concrete source-backed changes over vague psychological interpretation.

            Return only a JSON object with this exact shape:
            {
              "contradictions": [
                {
                  "topic": "short topic",
                  "beforeNoteID": "uuid of earlier note or null",
                  "afterNoteID": "uuid of later note or null",
                  "explanation": "one or two sentences explaining the tension or shift",
                  "confidence": 0.0
                }
              ]
            }

            Rules:
            - beforeNoteID and afterNoteID must be IDs from the supplied notes.
            - Include at most 12 high-signal contradictions.
            - Return an empty array if there is not enough evidence.
            - confidence must be between 0 and 1.
            """,
            "messages": [
                [
                    "role": "user",
                    "content": """
                    Find the strongest contradictions or meaningful shifts in this note corpus:

                    \(noteDigest.isEmpty ? "(no notes)" : noteDigest)
                    """
                ]
            ]
        ]

        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            throw AnthropicError.apiError(statusCode: statusCode, message: responseBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentBlocks = json["content"] as? [[String: Any]] else {
            throw AnthropicError.invalidJSON()
        }

        let textOut = contentBlocks.compactMap { block -> String? in
            guard (block["type"] as? String) == "text" else { return nil }
            return block["text"] as? String
        }.joined(separator: "\n\n")

        let jsonString = Self.extractJSON(from: textOut)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AnthropicError.invalidJSON()
        }

        do {
            let response = try JSONDecoder().decode(AnthropicContradictionsResponse.self, from: jsonData)
            return response.contradictions
                .filter { !$0.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .filter { !$0.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map {
                    Contradiction(
                        id: UUID(),
                        topic: $0.topic,
                        beforeNoteID: $0.beforeNoteID,
                        afterNoteID: $0.afterNoteID,
                        explanation: $0.explanation,
                        status: .unresolved,
                        confidence: $0.confidence,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                }
        } catch {
            throw AnthropicError.invalidJSON()
        }
    }

    func analyzeCorpus(_ notes: [MemoryNote]) async throws -> [Insight] {
        guard let apiKey = keychain.loadAnthropicAPIKey() else {
            throw AnthropicError.apiKeyMissing
        }

        let noteDigest = notes
            .sorted { $0.createdAt < $1.createdAt }
            .map(Self.buildAnalysisDigest)
            .joined(separator: "\n\n---\n\n")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "system": """
            You analyze a personal note corpus for a local-first memory app called Pensieve. Generate durable, source-backed insights that deserve review. Prefer high-signal findings over volume.

            Return only a JSON object with this exact shape:
            {
              "insights": [
                {
                  "kind": "pattern",
                  "title": "short title",
                  "explanation": "two or three concrete sentences grounded in the notes",
                  "sourceNoteIDs": ["uuid from supplied notes"],
                  "themes": ["theme"],
                  "confidence": 0.0
                }
              ]
            }

            Allowed kind values:
            - themeSummary
            - pattern
            - openLoop
            - question
            - decision
            - beliefShift

            Rules:
            - sourceNoteIDs must only contain IDs from the supplied notes.
            - Include 5 to 15 insights if evidence supports them.
            - Return fewer insights if the corpus is thin.
            - Do not diagnose the user or invent personality traits.
            - Prefer concrete open loops, decisions, belief shifts, repeated questions, and recurring patterns.
            - confidence must be between 0 and 1.
            - Return only JSON, with no markdown or extra prose.
            """,
            "messages": [
                [
                    "role": "user",
                    "content": """
                    Generate source-backed insights from this note corpus:

                    \(noteDigest.isEmpty ? "(no notes)" : noteDigest)
                    """
                ]
            ]
        ]

        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            throw AnthropicError.apiError(statusCode: statusCode, message: responseBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentBlocks = json["content"] as? [[String: Any]] else {
            throw AnthropicError.invalidJSON()
        }

        let textOut = contentBlocks.compactMap { block -> String? in
            guard (block["type"] as? String) == "text" else { return nil }
            return block["text"] as? String
        }.joined(separator: "\n\n")

        let jsonString = Self.extractJSON(from: textOut)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AnthropicError.invalidJSON()
        }

        do {
            let validNoteIDs = Set(notes.map(\.id))
            let response = try JSONDecoder().decode(AnthropicInsightsResponse.self, from: jsonData)
            return response.insights
                .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .filter { !$0.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { raw in
                    Insight(
                        kind: raw.kind,
                        title: raw.title,
                        explanation: raw.explanation,
                        sourceNoteIDs: raw.sourceNoteIDs.filter { validNoteIDs.contains($0) },
                        themes: raw.themes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty },
                        confidence: raw.confidence,
                        status: .pending,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                }
                .filter { !$0.sourceNoteIDs.isEmpty }
        } catch {
            throw AnthropicError.invalidJSON()
        }
    }

    func generateWeeklyDigest(from notes: [MemoryNote]) async throws -> Insight {
        guard let apiKey = keychain.loadAnthropicAPIKey() else {
            throw AnthropicError.apiKeyMissing
        }

        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        let weeklyNotes = notes
            .filter { $0.createdAt >= startDate && $0.createdAt <= endDate }
            .sorted { $0.createdAt < $1.createdAt }

        guard !weeklyNotes.isEmpty else {
            throw AnthropicError.invalidJSON("No notes from the last 7 days to digest.")
        }

        let noteDigest = weeklyNotes
            .map(Self.buildAnalysisDigest)
            .joined(separator: "\n\n---\n\n")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 3072,
            "temperature": 0,
            "system": """
            You create a weekly review digest for a local-first personal memory app called Pensieve. The digest must be concrete, source-backed, and useful for rediscovery and review.

            Return only a JSON object with this exact shape:
            {
              "insights": [
                {
                  "kind": "weeklyDigest",
                  "title": "Week of short date range",
                  "explanation": "A concise markdown-style digest with sections: Recurring themes, Open loops, Decisions or possible decisions, Rediscovered threads, Questions for next week.",
                  "sourceNoteIDs": ["uuid from supplied notes"],
                  "themes": ["theme"],
                  "confidence": 0.0
                }
              ]
            }

            Rules:
            - Return exactly one insight.
            - The kind must be weeklyDigest.
            - sourceNoteIDs must only contain IDs from the supplied notes.
            - Include source-grounded specifics, not generic advice.
            - If the week is thin, say that directly in the explanation.
            - Do not diagnose the user or invent facts absent from notes.
            - confidence must be between 0 and 1.
            - Return only JSON, with no markdown fences or extra prose.
            """,
            "messages": [
                [
                    "role": "user",
                    "content": """
                    Generate a weekly digest for notes created from \(Self.shortDate(startDate)) through \(Self.shortDate(endDate)).

                    Notes:
                    \(noteDigest)
                    """
                ]
            ]
        ]

        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            throw AnthropicError.apiError(statusCode: statusCode, message: responseBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentBlocks = json["content"] as? [[String: Any]] else {
            throw AnthropicError.invalidJSON()
        }

        let textOut = contentBlocks.compactMap { block -> String? in
            guard (block["type"] as? String) == "text" else { return nil }
            return block["text"] as? String
        }.joined(separator: "\n\n")

        let jsonString = Self.extractJSON(from: textOut)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AnthropicError.invalidJSON()
        }

        do {
            let validNoteIDs = Set(weeklyNotes.map(\.id))
            let response = try JSONDecoder().decode(AnthropicInsightsResponse.self, from: jsonData)
            guard let raw = response.insights.first else {
                throw AnthropicError.invalidJSON("Anthropic returned no weekly digest.")
            }

            let sourceNoteIDs = raw.sourceNoteIDs.filter { validNoteIDs.contains($0) }
            guard !sourceNoteIDs.isEmpty else {
                throw AnthropicError.invalidJSON("Weekly digest did not cite any valid source notes.")
            }

            return Insight(
                kind: .weeklyDigest,
                title: raw.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Weekly Digest" : raw.title,
                explanation: raw.explanation,
                sourceNoteIDs: sourceNoteIDs,
                themes: raw.themes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty },
                confidence: raw.confidence,
                status: .pending,
                createdAt: Date(),
                updatedAt: Date()
            )
        } catch let error as AnthropicError {
            throw error
        } catch {
            throw AnthropicError.invalidJSON()
        }
    }

    func generateNoteConnections(from notes: [MemoryNote]) async throws -> [NoteConnection] {
        guard let apiKey = keychain.loadAnthropicAPIKey() else {
            throw AnthropicError.apiKeyMissing
        }

        let connectionNotes = Self.connectionSample(from: notes, limit: 80)
        guard connectionNotes.count >= 2 else {
            throw AnthropicError.invalidJSON("At least two notes are needed to generate retrospective connections.")
        }

        let noteDigest = connectionNotes
            .map(Self.buildConnectionDigest)
            .joined(separator: "\n\n---\n\n")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "temperature": 0,
            "system": """
            You connect notes retrospectively for a local-first personal memory app called Pensieve. Your job is to find meaningful backlinks and coherent thought threads that a simple keyword search would miss.

            Return only a JSON object with this exact shape:
            {
              "connections": [
                {
                  "kind": "backlink",
                  "title": "short title",
                  "explanation": "two or three concrete sentences explaining the connection and why it matters",
                  "sourceNoteIDs": ["uuid from supplied notes"],
                  "themes": ["theme"],
                  "confidence": 0.0
                }
              ]
            }

            Allowed kind values:
            - backlink: a recent note is meaningfully illuminated by one or more older notes.
            - thread: three or more notes together form a coherent thought, recurring concern, decision arc, or evolving idea.

            Rules:
            - sourceNoteIDs must only contain IDs from the supplied notes.
            - Each connection must include at least 2 sourceNoteIDs.
            - Prefer 6 to 12 high-signal connections over volume.
            - Prefer non-obvious connections grounded in content, not just shared tags.
            - At least half the connections should include notes from different weeks or months when evidence supports it.
            - Keep explanations to one or two sentences.
            - Explain the user-facing value of reviewing the notes together.
            - Do not diagnose the user or invent facts absent from notes.
            - confidence must be between 0 and 1.
            - Return only JSON, with no markdown fences or extra prose.
            """,
            "messages": [
                [
                    "role": "user",
                    "content": """
                    Generate retrospective note connections from this corpus sample:

                    \(noteDigest)
                    """
                ]
            ]
        ]

        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            throw AnthropicError.apiError(statusCode: statusCode, message: responseBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentBlocks = json["content"] as? [[String: Any]] else {
            throw AnthropicError.invalidJSON()
        }

        let textOut = contentBlocks.compactMap { block -> String? in
            guard (block["type"] as? String) == "text" else { return nil }
            return block["text"] as? String
        }.joined(separator: "\n\n")

        let jsonString = Self.extractJSON(from: textOut)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AnthropicError.invalidJSON()
        }

        do {
            let validNoteIDs = Set(connectionNotes.map(\.id))
            let response = try JSONDecoder().decode(AnthropicNoteConnectionsResponse.self, from: jsonData)
            return response.connections
                .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .filter { !$0.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { raw in
                    NoteConnection(
                        kind: raw.kind,
                        title: raw.title,
                        explanation: raw.explanation,
                        sourceNoteIDs: raw.sourceNoteIDs.filter { validNoteIDs.contains($0) },
                        themes: raw.themes.map(Self.normalizedTheme).filter { !$0.isEmpty },
                        confidence: min(1, max(0, raw.confidence ?? 0.7)),
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                }
                .filter { $0.sourceNoteIDs.count >= 2 }
        } catch {
            throw AnthropicError.invalidJSON()
        }
    }

    func cleanUpTopics(_ notes: [MemoryNote]) async throws -> TopicCleanupResult {
        guard let apiKey = keychain.loadAnthropicAPIKey() else {
            throw AnthropicError.apiKeyMissing
        }

        let noteDigests = Self.topicCleanupSample(from: notes, limit: 48)
            .map(Self.buildTopicCleanupDigest)
            .joined(separator: "\n\n---\n\n")
        let themeDigest = Self.buildThemeDigest(from: notes)

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "temperature": 0,
            "system": """
            You clean up topics for a local-first personal memory app called Pensieve. The current notes have too many overlapping themes. Consolidate raw themes into a small durable topic map for navigation, rediscovery, wiki pages, and weekly digests. This is a taxonomy-only pass.

            Return only a JSON object with this exact shape:
            {
              "topics": [
                {
                  "title": "Career",
                  "canonicalTheme": "career",
                  "aliases": ["work", "consulting"],
                  "sourceNoteIDs": ["uuid from supplied notes"],
                  "relatedThemes": ["money"]
                }
              ],
              "noteThemeAssignments": []
            }

            Rules:
            - Use 10 to 14 canonical themes for a corpus of this size. Never create one topic per raw theme.
            - canonicalTheme values must be lowercase, short, stable nouns or noun phrases.
            - Merge near-duplicates and sibling tags aggressively. Examples: work/career/consulting/business/sales/entrepreneurship -> career; identity/self-awareness/clarity/confidence/growth -> self-understanding; priorities/productivity/focus/habits/planning/decisions -> productivity; ai/technology/tools/automation/software -> technology.
            - Split only when a topic would otherwise mix genuinely different user-facing review contexts.
            - Put raw theme names into aliases so the app can map old notes onto the new canonical topics.
            - Cover the high-count raw themes in either canonicalTheme or aliases.
            - Do not assign themes note-by-note. Return an empty noteThemeAssignments array.
            - sourceNoteIDs must use only IDs from the supplied note sample.
            - sourceNoteIDs should contain 1 to 4 representative IDs from the supplied note sample.
            - Do not include summaries, explanations, currentUnderstanding, recurringSubthemes, or openQuestions.
            - Do not invent details not supported by the notes.
            - Return only JSON, with no markdown or extra prose.
            """,
            "messages": [
                [
                    "role": "user",
                    "content": """
                    Existing theme counts:
                    \(themeDigest)

                    Recent/high-signal note sample:
                    \(noteDigests.isEmpty ? "(no notes)" : noteDigests)
                    """
                ]
            ]
        ]

        var urlRequest = URLRequest(url: baseURL)
        urlRequest.timeoutInterval = 180
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            throw AnthropicError.apiError(statusCode: statusCode, message: responseBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentBlocks = json["content"] as? [[String: Any]] else {
            throw AnthropicError.invalidJSON()
        }

        let textOut = contentBlocks.compactMap { block -> String? in
            guard (block["type"] as? String) == "text" else { return nil }
            return block["text"] as? String
        }.joined(separator: "\n\n")

        return try Self.parseTopicCleanupResponse(textOut, validNoteIDs: Set(notes.map(\.id)))
    }

    func generateWikiTopicPage(topic: WikiTopic, notes: [MemoryNote]) async throws -> WikiTopic {
        guard let apiKey = keychain.loadAnthropicAPIKey() else {
            throw AnthropicError.apiKeyMissing
        }

        let noteDigest = notes
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(30)
            .map(Self.buildTopicPageDigest)
            .joined(separator: "\n\n---\n\n")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": """
            You generate one durable source-backed wiki topic page for a local-first personal memory app called Pensieve.

            Return only a JSON object with this exact shape:
            {
              "title": "Career",
              "summary": "one sentence",
              "currentUnderstanding": "2-5 concise paragraphs grounded in the notes",
              "recurringSubthemes": ["subtheme"],
              "openQuestions": ["question"],
              "relatedThemes": ["theme"]
            }

            Rules:
            - Use only the supplied notes.
            - Keep the page concrete and source-backed.
            - Do not diagnose the user or invent traits.
            - Return only JSON, with no markdown or extra prose.
            """,
            "messages": [
                [
                    "role": "user",
                    "content": """
                    Topic: \(topic.title)
                    Canonical theme: \(topic.canonicalTheme)
                    Aliases: \(topic.aliases.joined(separator: ", "))

                    Source notes:
                    \(noteDigest.isEmpty ? "(no notes)" : noteDigest)
                    """
                ]
            ]
        ]

        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            throw AnthropicError.apiError(statusCode: statusCode, message: responseBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentBlocks = json["content"] as? [[String: Any]] else {
            throw AnthropicError.invalidJSON()
        }

        let textOut = contentBlocks.compactMap { block -> String? in
            guard (block["type"] as? String) == "text" else { return nil }
            return block["text"] as? String
        }.joined(separator: "\n\n")

        let jsonString = Self.extractJSON(from: textOut)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AnthropicError.invalidJSON()
        }

        do {
            let response = try JSONDecoder().decode(AnthropicWikiTopicPageResponse.self, from: jsonData)
            var updated = topic
            updated.title = response.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? topic.title : response.title
            updated.summary = response.summary
            updated.currentUnderstanding = response.currentUnderstanding
            updated.recurringSubthemes = response.recurringSubthemes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            updated.openQuestions = response.openQuestions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            updated.relatedThemes = response.relatedThemes.map(Self.normalizedTheme).filter { !$0.isEmpty }
            updated.updatedAt = Date()
            return updated
        } catch {
            throw AnthropicError.invalidJSON()
        }
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
            throw AnthropicError.invalidJSON()
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
        let jsonString = Self.extractJSON(from: textOut)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AnthropicError.invalidJSON()
        }

        do {
            let note = try JSONDecoder().decode(AnthropicProcessedNote.self, from: jsonData)
            let fetched = kind == .url && !urls.isEmpty ? anyFetchAttempted && !anyFetchFailed : nil
            return ProcessResult(note: note, articleFetched: fetched)
        } catch {
            throw AnthropicError.invalidJSON()
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

    private static func buildContradictionDigest(for note: MemoryNote) -> String {
        let summary = note.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let excerpt = note.body
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(700)
        let themes = note.themes.isEmpty ? "none" : note.themes.joined(separator: ", ")

        return """
        ID: \(note.id.uuidString)
        Date: \(ISO8601DateFormatter().string(from: note.createdAt))
        Title: \(note.title)
        Themes: \(themes)
        Tone: \(note.emotionalTone ?? "unknown")
        Summary:
        \(summary)
        Excerpt:
        \(excerpt)
        """
    }

    private static func buildAnalysisDigest(for note: MemoryNote) -> String {
        let summary = note.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let excerpt = note.body
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(900)
        let themes = note.themes.isEmpty ? "none" : note.themes.joined(separator: ", ")

        return """
        ID: \(note.id.uuidString)
        Date: \(ISO8601DateFormatter().string(from: note.createdAt))
        Title: \(note.title)
        Themes: \(themes)
        Tone: \(note.emotionalTone ?? "unknown")
        Summary:
        \(summary)
        Excerpt:
        \(excerpt)
        """
    }

    private static func buildTopicCleanupDigest(for note: MemoryNote) -> String {
        let summary = note.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let excerpt = note.body
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(160)
        let themes = note.themes.isEmpty ? "none" : note.themes.joined(separator: ", ")

        return """
        ID: \(note.id.uuidString)
        Date: \(ISO8601DateFormatter().string(from: note.createdAt))
        Title: \(note.title)
        Current Themes: \(themes)
        Summary:
        \(summary)
        Excerpt:
        \(excerpt)
        """
    }

    private static func buildTopicPageDigest(for note: MemoryNote) -> String {
        let summary = note.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let excerpt = note.body
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(700)
        let themes = note.themes.isEmpty ? "none" : note.themes.joined(separator: ", ")

        return """
        ID: \(note.id.uuidString)
        Date: \(ISO8601DateFormatter().string(from: note.createdAt))
        Title: \(note.title)
        Themes: \(themes)
        Summary:
        \(summary)
        Excerpt:
        \(excerpt)
        """
    }

    private static func buildConnectionDigest(for note: MemoryNote) -> String {
        let summary = note.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let excerpt = note.body
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(650)
        let themes = note.themes.isEmpty ? "none" : note.themes.joined(separator: ", ")

        return """
        ID: \(note.id.uuidString)
        Date: \(ISO8601DateFormatter().string(from: note.createdAt))
        Title: \(note.title)
        Themes: \(themes)
        Tone: \(note.emotionalTone ?? "unknown")
        Summary:
        \(summary)
        Excerpt:
        \(excerpt)
        """
    }

    private static func buildThemeDigest(from notes: [MemoryNote]) -> String {
        let counts = Dictionary(
            grouping: notes.flatMap(\.themes).map(normalizedTheme).filter { !$0.isEmpty },
            by: { $0 }
        )
        .map { (theme: $0.key, count: $0.value.count) }
        .sorted {
            if $0.count == $1.count {
                return $0.theme < $1.theme
            }
            return $0.count > $1.count
        }
            .prefix(60)

        return counts.map { "- \($0.theme): \($0.count)" }.joined(separator: "\n")
    }

    private static func topicCleanupSample(from notes: [MemoryNote], limit: Int) -> [MemoryNote] {
        let sortedNotes = notes.sorted { $0.createdAt > $1.createdAt }
        let topThemes = Set(
            Dictionary(grouping: notes.flatMap(\.themes).map(normalizedTheme).filter { !$0.isEmpty }, by: { $0 })
                .map { (theme: $0.key, count: $0.value.count) }
                .sorted {
                    if $0.count == $1.count {
                        return $0.theme < $1.theme
                    }
                    return $0.count > $1.count
                }
                .prefix(limit)
                .map(\.theme)
        )

        var selected: [MemoryNote] = []
        var selectedIDs = Set<UUID>()

        for theme in topThemes {
            guard let note = sortedNotes.first(where: { note in
                note.themes.map(normalizedTheme).contains(theme) && !selectedIDs.contains(note.id)
            }) else { continue }
            selected.append(note)
            selectedIDs.insert(note.id)
            if selected.count >= limit { return selected }
        }

        for note in sortedNotes where !selectedIDs.contains(note.id) {
            selected.append(note)
            selectedIDs.insert(note.id)
            if selected.count >= limit { break }
        }

        return selected
    }

    private static func connectionSample(from notes: [MemoryNote], limit: Int) -> [MemoryNote] {
        let sortedNotes = notes.sorted { $0.createdAt > $1.createdAt }
        let recentLimit = max(12, limit / 3)
        let recent = Array(sortedNotes.prefix(recentLimit))
        let recentIDs = Set(recent.map(\.id))

        let topThemes = Set(
            Dictionary(grouping: notes.flatMap(\.themes).map(normalizedTheme).filter { !$0.isEmpty }, by: { $0 })
                .map { (theme: $0.key, count: $0.value.count) }
                .sorted {
                    if $0.count == $1.count {
                        return $0.theme < $1.theme
                    }
                    return $0.count > $1.count
                }
                .prefix(20)
                .map(\.theme)
        )

        var selected = recent
        var selectedIDs = recentIDs

        for theme in topThemes {
            let themedNotes = sortedNotes
                .filter { !selectedIDs.contains($0.id) && $0.themes.map(normalizedTheme).contains(theme) }
                .suffix(3)
            for note in themedNotes {
                selected.append(note)
                selectedIDs.insert(note.id)
                if selected.count >= limit { return selected.sorted { $0.createdAt < $1.createdAt } }
            }
        }

        for note in sortedNotes.reversed() where !selectedIDs.contains(note.id) {
            selected.append(note)
            selectedIDs.insert(note.id)
            if selected.count >= limit { break }
        }

        return selected.sorted { $0.createdAt < $1.createdAt }
    }

    private static func normalizedTheme(_ theme: String) -> String {
        theme
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
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

    private static func parseTopicCleanupResponse(_ text: String, validNoteIDs: Set<UUID>) throws -> TopicCleanupResult {
        let jsonString = Self.extractJSON(from: text)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AnthropicError.invalidJSON("Anthropic response was not valid UTF-8 JSON.")
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: jsonData)
        } catch {
            throw AnthropicError.invalidJSON("Anthropic returned malformed JSON: \(shortDebugDescription(error.localizedDescription)).")
        }

        let topicDictionaries: [[String: Any]]
        let assignmentDictionaries: [[String: Any]]

        if let dictionary = object as? [String: Any] {
            topicDictionaries = firstArray(in: dictionary, keys: ["topics", "canonicalTopics", "wikiTopics"])
            assignmentDictionaries = firstArray(in: dictionary, keys: ["noteThemeAssignments", "assignments", "themeAssignments"])
        } else if let array = object as? [[String: Any]] {
            topicDictionaries = array
            assignmentDictionaries = []
        } else {
            throw AnthropicError.invalidJSON("Anthropic JSON was neither an object nor a topic array.")
        }

        let topics = topicDictionaries.compactMap { raw -> WikiTopic? in
            let canonicalTheme = normalizedTheme(firstString(in: raw, keys: ["canonicalTheme", "canonical_theme", "theme", "slug"]))
            let title = firstString(in: raw, keys: ["title", "name"]).trimmingCharacters(in: .whitespacesAndNewlines)
            let sourceNoteIDs = firstUUIDArray(in: raw, keys: ["sourceNoteIDs", "sourceNoteIds", "source_note_ids", "noteIDs", "noteIds", "note_ids"])
                .filter { validNoteIDs.contains($0) }
            guard !canonicalTheme.isEmpty, !title.isEmpty else { return nil }

            let summary = firstString(in: raw, keys: ["summary", "description"])
            let currentUnderstanding = firstString(in: raw, keys: ["currentUnderstanding", "current_understanding", "understanding"])

            return WikiTopic(
                title: title,
                canonicalTheme: canonicalTheme,
                aliases: firstStringArray(in: raw, keys: ["aliases", "alternateNames", "alternate_names"])
                    .map(normalizedTheme)
                    .filter { !$0.isEmpty && $0 != canonicalTheme },
                summary: summary.isEmpty ? "Notes grouped around \(canonicalTheme)." : summary,
                currentUnderstanding: currentUnderstanding.isEmpty ? (summary.isEmpty ? "Notes grouped around \(canonicalTheme)." : summary) : currentUnderstanding,
                recurringSubthemes: firstStringArray(in: raw, keys: ["recurringSubthemes", "recurring_subthemes", "subthemes"]),
                openQuestions: firstStringArray(in: raw, keys: ["openQuestions", "open_questions", "questions"]),
                sourceNoteIDs: sourceNoteIDs,
                relatedThemes: firstStringArray(in: raw, keys: ["relatedThemes", "related_themes", "related"])
                    .map(normalizedTheme)
                    .filter { !$0.isEmpty },
                createdAt: Date(),
                updatedAt: Date()
            )
        }

        guard !topics.isEmpty else {
            throw AnthropicError.invalidJSON("Anthropic JSON contained no usable topics.")
        }

        let canonicalThemes = Set(topics.map(\.canonicalTheme))
        let assignments = assignmentDictionaries.compactMap { raw -> TopicThemeAssignment? in
            guard let noteID = firstUUID(in: raw, keys: ["noteID", "noteId", "note_id"]), validNoteIDs.contains(noteID) else { return nil }
            let cleaned = cleanedTopicThemes(firstStringArray(in: raw, keys: ["themes", "canonicalThemes", "canonical_themes"]))
                .filter { canonicalThemes.contains($0) }
            guard !cleaned.isEmpty else { return nil }
            return TopicThemeAssignment(noteID: noteID, themes: cleaned)
        }

        return TopicCleanupResult(topics: topics, assignments: assignments)
    }

    private static func firstArray(in dictionary: [String: Any], keys: [String]) -> [[String: Any]] {
        for key in keys {
            if let value = dictionary[key] as? [[String: Any]] {
                return value
            }
        }
        return []
    }

    private static func firstString(in dictionary: [String: Any], keys: [String]) -> String {
        for key in keys {
            if let value = dictionary[key] as? String {
                return value
            }
        }
        return ""
    }

    private static func firstStringArray(in dictionary: [String: Any], keys: [String]) -> [String] {
        for key in keys {
            if let values = dictionary[key] as? [String] {
                return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            }
            if let value = dictionary[key] as? String {
                return value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }
        return []
    }

    private static func firstUUIDArray(in dictionary: [String: Any], keys: [String]) -> [UUID] {
        firstStringArray(in: dictionary, keys: keys).compactMap(UUID.init(uuidString:))
    }

    private static func firstUUID(in dictionary: [String: Any], keys: [String]) -> UUID? {
        for key in keys {
            if let value = dictionary[key] as? String, let id = UUID(uuidString: value) {
                return id
            }
        }
        return nil
    }

    private static func cleanedTopicThemes(_ themes: [String]) -> [String] {
        let uniqueThemes = Set(themes.map(normalizedTheme).filter { !$0.isEmpty })
        return Array(Array(uniqueThemes).sorted().prefix(4))
    }

    private static func shortDebugDescription(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(240))
    }

    private static func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("```") {
            let lines = trimmed.components(separatedBy: "\n")
            return lines.dropFirst().dropLast().joined(separator: "\n")
        }

        let objectStart = trimmed.firstIndex(of: "{")
        let arrayStart = trimmed.firstIndex(of: "[")
        let start = [objectStart, arrayStart].compactMap { $0 }.min()
        guard let start else { return trimmed }

        if trimmed[start] == "{", let end = trimmed.lastIndex(of: "}"), start <= end {
            return String(trimmed[start...end])
        }
        if trimmed[start] == "[", let end = trimmed.lastIndex(of: "]"), start <= end {
            return String(trimmed[start...end])
        }

        return trimmed
    }
}
