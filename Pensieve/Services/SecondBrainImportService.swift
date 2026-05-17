import Foundation

struct SecondBrainImportResult {
    var importedCount: Int
    var skippedCount: Int
}

enum SecondBrainImportError: LocalizedError {
    case folderUnreadable

    var errorDescription: String? {
        switch self {
        case .folderUnreadable:
            return "Could not read the selected folder."
        }
    }
}

struct SecondBrainImportService {
    private let store: LocalStore

    init(store: LocalStore) {
        self.store = store
    }

    func importRawFolder(_ folderURL: URL) async throws -> SecondBrainImportResult {
        let accessing = folderURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw SecondBrainImportError.folderUnreadable
        }

        let fileURLs = enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "md" }

        var importedCount = 0
        var skippedCount = 0

        for fileURL in fileURLs {
            do {
                let markdown = try String(contentsOf: fileURL, encoding: .utf8)
                if let imported = parse(markdown: markdown, fileURL: fileURL) {
                    await store.saveImported(capture: imported.capture, note: imported.note)
                    importedCount += 1
                } else {
                    skippedCount += 1
                }
            } catch {
                skippedCount += 1
            }
        }

        return SecondBrainImportResult(importedCount: importedCount, skippedCount: skippedCount)
    }

    private func parse(markdown: String, fileURL: URL) -> (capture: Capture, note: MemoryNote)? {
        let frontmatter = parseFrontmatter(markdown)
        let title = frontmatter["title"] ?? headingTitle(in: markdown) ?? fileURL.deletingPathExtension().lastPathComponent
        let date = frontmatter["date"].flatMap(Self.parseDate) ?? dateFromFilename(fileURL) ?? Date()
        let themes = parseThemes(frontmatter["themes"])
        let emotionalTone = frontmatter["emotional_tone"]
        let source = CaptureKind(rawValue: frontmatter["source"] ?? "") ?? .voice
        let rawText = section(named: "Transcription", in: markdown)
            ?? section(named: "Raw Input", in: markdown)
            ?? markdownWithoutFrontmatter(markdown)
        let summary = section(named: "Summary", in: markdown)?
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "- ").union(.whitespaces)) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n") ?? ""
        let body = markdownWithoutFrontmatter(markdown)
        let sourceIdentifier = "secondbrain/raw/\(fileURL.lastPathComponent)"

        let capture = Capture(
            kind: source,
            createdAt: date,
            rawText: rawText.trimmingCharacters(in: .whitespacesAndNewlines),
            transcript: source == .voice ? rawText.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            sourceURLs: parseURLs(from: frontmatter["urls"] ?? rawText),
            processingStatus: .processed,
            sourceIdentifier: sourceIdentifier
        )

        let note = MemoryNote(
            captureID: capture.id,
            title: title,
            summary: summary.isEmpty ? rawText.trimmingCharacters(in: .whitespacesAndNewlines) : summary,
            body: body,
            themes: themes,
            emotionalTone: emotionalTone,
            createdAt: date,
            updatedAt: date,
            sourceIdentifier: sourceIdentifier
        )

        return (capture, note)
    }

    private func parseFrontmatter(_ markdown: String) -> [String: String] {
        guard markdown.hasPrefix("---\n"),
              let endRange = markdown.range(of: "\n---", range: markdown.index(markdown.startIndex, offsetBy: 4)..<markdown.endIndex) else {
            return [:]
        }

        let block = markdown[markdown.index(markdown.startIndex, offsetBy: 4)..<endRange.lowerBound]
        var values: [String: String] = [:]
        for line in block.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            values[key] = value
        }
        return values
    }

    private func markdownWithoutFrontmatter(_ markdown: String) -> String {
        guard markdown.hasPrefix("---\n"),
              let endRange = markdown.range(of: "\n---", range: markdown.index(markdown.startIndex, offsetBy: 4)..<markdown.endIndex) else {
            return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return String(markdown[endRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func headingTitle(in markdown: String) -> String? {
        markdown
            .split(separator: "\n")
            .first { $0.hasPrefix("# ") }
            .map { String($0.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
    }

    private func section(named name: String, in markdown: String) -> String? {
        let lines = markdown.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "## \(name)" }) else {
            return nil
        }

        let bodyLines = lines[(start + 1)...].prefix { !$0.hasPrefix("## ") }
        let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? nil : body
    }

    private func parseThemes(_ raw: String?) -> [String] {
        guard let raw else { return [] }
        return raw
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .split(separator: ",")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            .filter { !$0.isEmpty }
    }

    private func parseURLs(from text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        return detector
            .matches(in: text, range: nsRange)
            .compactMap(\.url)
    }

    private func dateFromFilename(_ fileURL: URL) -> Date? {
        let name = fileURL.deletingPathExtension().lastPathComponent
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        formatter.timeZone = .current
        return formatter.date(from: name)
    }

    private static func parseDate(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        return iso.date(from: value)
    }
}
