import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct ClaudeClient {
    public let apiKey: String
    public let model: String
    public let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    public init(apiKey: String, model: String = "claude-sonnet-4-6") {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = model
    }

    public struct Response {
        public let text: String
        public let inputTokens: Int
        public let outputTokens: Int
        public let cacheReadTokens: Int
        public let cacheWriteTokens: Int
    }

    public func complete(system: String, user: String, maxTokens: Int = 16000) async throws -> Response {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": [
                [
                    "type": "text",
                    "text": system,
                    "cache_control": ["type": "ephemeral"]
                ]
            ],
            "messages": [
                ["role": "user", "content": user]
            ]
        ]

        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = [
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json"
        ]
        config.timeoutIntervalForRequest = 600
        config.timeoutIntervalForResource = 900
        let session = URLSession(configuration: config)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            let msg = String(data: data, encoding: .utf8) ?? "no body"
            throw IngestError.apiError(code, msg)
        }

        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IngestError.decodeError("response not a JSON object")
        }

        let content = (obj["content"] as? [[String: Any]]) ?? []
        let text = content.compactMap { $0["text"] as? String }.joined()

        let usage = (obj["usage"] as? [String: Any]) ?? [:]
        let inTok = (usage["input_tokens"] as? Int) ?? 0
        let outTok = (usage["output_tokens"] as? Int) ?? 0
        let cacheR = (usage["cache_read_input_tokens"] as? Int) ?? 0
        let cacheW = (usage["cache_creation_input_tokens"] as? Int) ?? 0

        return Response(
            text: text,
            inputTokens: inTok,
            outputTokens: outTok,
            cacheReadTokens: cacheR,
            cacheWriteTokens: cacheW
        )
    }
}
