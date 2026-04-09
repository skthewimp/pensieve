import Foundation

/// Writes processed voice notes as markdown files into the Obsidian vault.
///
/// The vault lives in the app's iCloud container (if available) or local Documents.
/// Obsidian on iOS can open vaults from either location.
///
/// Storage strategy:
/// - The wiki vault is stored in the app's Documents directory
/// - Obsidian on iOS can open it as a local vault (no iCloud needed)
/// - To sync to Mac: the user sets up Obsidian on both devices pointing to the same
///   iCloud folder, OR uses Obsidian's "Open folder as vault" on the Mac after
///   connecting the phone via Finder/cable to copy files
/// - Markdown files are ~2-3KB each; even years of notes fit in minimal storage
class ObsidianStorageService {

    let vaultURL: URL
    let rawDirectory: URL

    init() {
        // Use app's Documents directory as the vault root
        // This is accessible via Files app and Finder when phone is connected
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.vaultURL = documents.appendingPathComponent("SecondBrainVault")
        self.rawDirectory = vaultURL.appendingPathComponent("raw")

        // Create directory structure
        let dirs = [
            rawDirectory,
            vaultURL.appendingPathComponent("wiki"),
            vaultURL.appendingPathComponent("wiki/themes"),
            vaultURL.appendingPathComponent("wiki/tensions"),
            vaultURL.appendingPathComponent("wiki/insights")
        ]

        for dir in dirs {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // Copy CLAUDE.md and initial wiki files on first launch
        ensureWikiScaffold()
    }

    /// Save a processed thought note as a markdown file in the raw directory.
    func save(note: ThoughtNote, processed: ClaudeProcessedNote) throws -> URL {
        let fileURL = rawDirectory.appendingPathComponent(note.wikiFilename)

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withFullTime, .withTimeZone]

        let themesYAML = processed.themes.map { "\"\($0)\"" }.joined(separator: ", ")
        let summaryBullets = processed.summary.map { "- \($0)" }.joined(separator: "\n")
        let keyQuotes = processed.keyQuotes.map { "> \($0)" }.joined(separator: "\n\n")

        let markdown = """
        ---
        date: \(dateFormatter.string(from: note.recordedAt))
        duration: \(note.formattedDuration)
        themes: [\(themesYAML)]
        emotional_tone: \(processed.emotionalTone)
        title: "\(processed.title)"
        ---

        # \(processed.title)

        ## Summary
        \(summaryBullets)

        ## Key Quotes
        \(keyQuotes.isEmpty ? "*No notable quotes extracted.*" : keyQuotes)

        ## Connections
        \(processed.connections.map { "- \($0)" }.joined(separator: "\n"))

        ## Transcription
        \(note.transcription ?? "*No transcription available.*")
        """

        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    /// Check how many unprocessed raw files exist (for display purposes)
    func rawNoteCount() -> Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: rawDirectory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "md" }.count
    }

    /// Set up initial wiki structure on first launch
    private func ensureWikiScaffold() {
        let indexPath = vaultURL.appendingPathComponent("wiki/index.md")

        // Only scaffold if index doesn't exist yet
        guard !FileManager.default.fileExists(atPath: indexPath.path) else { return }

        let files: [(String, String)] = [
            ("wiki/index.md", """
            ---
            title: Index
            type: index
            last_updated: \(todayString())
            ---

            # Second Brain — Index

            ## Themes
            *Theme pages are created automatically as you record voice notes.*

            ## Tensions
            - [[contradictions]] — Shifts and contradictions in thinking over time

            ## Timeline
            - [[timeline]] — Reverse-chronological record of all thoughts
            """),
            ("wiki/log.md", """
            ---
            title: Ingestion Log
            type: log
            ---

            # Ingestion Log
            """),
            ("wiki/timeline.md", """
            ---
            title: Timeline
            type: timeline
            last_updated: \(todayString())
            ---

            # Timeline
            """),
            ("wiki/tensions/contradictions.md", """
            ---
            title: Contradictions & Shifts
            type: tension
            last_updated: \(todayString())
            source_count: 0
            ---

            # Contradictions & Shifts

            *Tracks where your thinking has shifted, reversed, or gone circular.*
            """)
        ]

        for (path, content) in files {
            let url = vaultURL.appendingPathComponent(path)
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
