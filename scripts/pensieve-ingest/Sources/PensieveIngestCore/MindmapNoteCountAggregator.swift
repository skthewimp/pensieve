import Foundation

public enum MindmapNoteCountAggregator {
    /// Walks `wiki/themes/*.md`, parses YAML frontmatter, returns `themeSlug -> source_count`.
    /// Files without `source_count` or with unparseable frontmatter are silently omitted.
    public static func countsFromThemesDir(_ themesDir: URL) throws -> [String: Int] {
        guard FileManager.default.fileExists(atPath: themesDir.path) else { return [:] }
        var out: [String: Int] = [:]
        let files = try FileManager.default.contentsOfDirectory(
            at: themesDir, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "md" }

        for url in files {
            let slug = url.deletingPathExtension().lastPathComponent
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if let count = parseSourceCount(content) {
                out[slug] = count
            }
        }
        return out
    }

    private static func parseSourceCount(_ content: String) -> Int? {
        guard content.hasPrefix("---\n") else { return nil }
        let rest = content.dropFirst(4)
        guard let endRange = rest.range(of: "\n---\n") else { return nil }
        let fmBlock = rest[..<endRange.lowerBound]
        for line in fmBlock.split(separator: "\n") {
            let s = String(line)
            if s.hasPrefix("source_count:") {
                let v = s.replacingOccurrences(of: "source_count:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                return Int(v)
            }
        }
        return nil
    }
}
