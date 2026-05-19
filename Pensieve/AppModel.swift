import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var captures: [Capture] = []
    @Published var notes: [MemoryNote] = []
    @Published var contradictions: [Contradiction] = []
    @Published var insights: [Insight] = []
    @Published var wikiTopics: [WikiTopic] = []
    @Published var chatMessages: [ChatMessage] = []
    @Published var lastTopicCleanupDiagnostics: TopicCleanupDiagnostics?
    @Published var isAnthropicConfigured: Bool

    let audioRecorder = AudioRecorderService()
    let transcriptionService = TranscriptionService()
    let captureService: CaptureService
    let localStore: LocalStore
    private let keychain: KeychainService
    private let llmProvider: LLMProvider
    private let importService: SecondBrainImportService
    private var cancellables = Set<AnyCancellable>()

    init() {
        let store = FileLocalStore()
        let keychain = KeychainService()
        self.localStore = store
        self.keychain = keychain
        self.isAnthropicConfigured = keychain.hasAnthropicAPIKey()
        self.llmProvider = AnthropicProvider(keychain: keychain)
        self.importService = SecondBrainImportService(store: store)
        self.captureService = CaptureService(
            store: store,
            llmProvider: llmProvider,
            transcriptionService: transcriptionService
        )

        audioRecorder.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        transcriptionService.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        Task {
            await refresh()
            await transcriptionService.loadModel()
        }
    }

    func refresh() async {
        captures = await localStore.loadCaptures()
        notes = await localStore.loadNotes()
        contradictions = await localStore.loadContradictions()
        insights = await localStore.loadInsights()
        wikiTopics = await localStore.loadWikiTopics()
        chatMessages = await localStore.loadChatMessages()
    }

    func saveAnthropicAPIKey(_ apiKey: String) throws {
        try keychain.saveAnthropicAPIKey(apiKey)
        isAnthropicConfigured = keychain.hasAnthropicAPIKey()
    }

    func sendChatMessage(_ content: String) async throws {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: trimmed)
        await localStore.saveChatMessage(userMessage)
        await refresh()

        let context = notesForQuery(trimmed)
        let response = try await llmProvider.chat(
            ChatRequest(question: trimmed, contextNotes: context)
        )
        let assistantMessage = ChatMessage(
            role: .assistant,
            content: response.answer,
            contextNoteIDs: response.contextNoteIDs
        )
        await localStore.saveChatMessage(assistantMessage)
        await refresh()
    }

    func importSecondBrainRawFolder(_ folderURL: URL) async throws -> SecondBrainImportResult {
        let result = try await importService.importRawFolder(folderURL)
        await refresh()
        return result
    }

    func generateContradictions() async throws -> Int {
        let existing = await localStore.loadContradictions()
        let existingFingerprints = Set(existing.map(Self.contradictionFingerprint))
        let generated = try await findContradictionsWithRetry()

        var savedCount = 0
        for contradiction in generated where !existingFingerprints.contains(Self.contradictionFingerprint(contradiction)) {
            await localStore.saveContradiction(contradiction)
            savedCount += 1
        }

        await refresh()
        return savedCount
    }

    func updateContradiction(_ contradiction: Contradiction, status: ContradictionStatus) async {
        var updated = contradiction
        updated.status = status
        updated.updatedAt = Date()
        await localStore.saveContradiction(updated)
        await refresh()
    }

    func analyzeCorpus() async throws -> Int {
        let existing = await localStore.loadInsights()
        let existingFingerprints = Set(existing.map(Self.insightFingerprint))
        let generated = try await analyzeCorpusWithRetry()

        var savedCount = 0
        for insight in generated where !existingFingerprints.contains(Self.insightFingerprint(insight)) {
            await localStore.saveInsight(insight)
            savedCount += 1
        }

        await refresh()
        return savedCount
    }

    func updateInsight(_ insight: Insight, status: InsightStatus) async {
        var updated = insight
        updated.status = status
        updated.updatedAt = Date()
        await localStore.saveInsight(updated)
        await refresh()
    }

    func prepareTopicCleanupPreview() async throws -> TopicCleanupPreview {
        let (result, source, fallbackReason) = try await buildTopicCleanupPlan()
        return TopicCleanupPreview(
            result: result,
            diagnostics: Self.topicCleanupDiagnostics(
                for: result,
                notes: notes,
                source: source,
                fallbackReason: fallbackReason,
                runAt: Date()
            )
        )
    }

    func applyTopicCleanupPreview(_ preview: TopicCleanupPreview) async throws -> TopicCleanupDiagnostics {
        let diagnostics = try await applyTopicCleanupResult(preview.result, source: preview.diagnostics.source)
        lastTopicCleanupDiagnostics = diagnostics
        return diagnostics
    }

    func cleanUpTopics() async throws -> TopicCleanupDiagnostics {
        let preview = try await prepareTopicCleanupPreview()
        return try await applyTopicCleanupPreview(preview)
    }

    func refreshWikiTopic(_ topic: WikiTopic) async throws {
        let notesByID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        let topicNotes = topic.sourceNoteIDs.compactMap { notesByID[$0] }
        var refreshedTopic = try await llmProvider.generateWikiTopicPage(topic: topic, notes: topicNotes)
        refreshedTopic.status = .pending
        await localStore.saveWikiTopic(refreshedTopic)
        await refresh()
    }

    func updateWikiTopic(_ topic: WikiTopic, status: WikiTopicStatus) async {
        var updated = topic
        updated.status = status
        updated.updatedAt = Date()
        await localStore.saveWikiTopic(updated)
        await refresh()
    }

    private func buildTopicCleanupPlan() async throws -> (result: TopicCleanupResult, source: TopicCleanupSource, fallbackReason: String?) {
        do {
            let taxonomy = try await llmProvider.cleanUpTopics(notes)
            if !taxonomy.topics.isEmpty {
                return (Self.buildTopicCleanup(from: notes, topics: taxonomy.topics), .llm, nil)
            }

            return (
                Self.buildLocalTopicCleanup(from: notes),
                .localFallback,
                "Anthropic returned no usable topics."
            )
        } catch {
            return (
                Self.buildLocalTopicCleanup(from: notes),
                .localFallback,
                error.localizedDescription
            )
        }
    }

    private func applyTopicCleanupResult(_ result: TopicCleanupResult, source: TopicCleanupSource) async throws -> TopicCleanupDiagnostics {
        let diagnostics = Self.topicCleanupDiagnostics(
            for: result,
            notes: notes,
            source: source,
            runAt: Date()
        )
        let notesByID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        let assignmentByNoteID = Dictionary(uniqueKeysWithValues: result.assignments.map { ($0.noteID, $0.themes) })

        for noteID in notesByID.keys {
            guard var note = notesByID[noteID] else { continue }
            let assignedThemes = assignmentByNoteID[noteID] ?? ["general"]
            let cleanedThemes = Self.cleanedThemes(assignedThemes)
            guard !cleanedThemes.isEmpty, note.themes != cleanedThemes else { continue }
            note.themes = cleanedThemes
            note.updatedAt = Date()
            await localStore.saveNote(note)
        }

        await localStore.deleteWikiTopics()
        let refreshedNotes = await localStore.loadNotes()
        let refreshedNotesByID = Dictionary(uniqueKeysWithValues: refreshedNotes.map { ($0.id, $0) })
        for topic in result.topics.prefix(16) where !topic.sourceNoteIDs.isEmpty {
            let topicNotes = topic.sourceNoteIDs.compactMap { refreshedNotesByID[$0] }
            let generatedTopic = (try? await llmProvider.generateWikiTopicPage(topic: topic, notes: topicNotes)) ?? topic
            await localStore.saveWikiTopic(generatedTopic)
        }

        await refresh()
        return diagnostics
    }

    private func findContradictionsWithRetry() async throws -> [Contradiction] {
        do {
            return try await llmProvider.findContradictions(in: notes)
        } catch {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return try await llmProvider.findContradictions(in: notes)
        }
    }

    private func analyzeCorpusWithRetry() async throws -> [Insight] {
        do {
            return try await llmProvider.analyzeCorpus(notes)
        } catch {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return try await llmProvider.analyzeCorpus(notes)
        }
    }

    func exportBackupData() async throws -> Data {
        try await localStore.exportBackupData()
    }

    func restoreBackupData(_ data: Data) async throws {
        try await localStore.restoreBackupData(data)
        await refresh()
    }

    func backupFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "pensieve-backup-\(formatter.string(from: Date()))"
    }

    private static func contradictionFingerprint(_ contradiction: Contradiction) -> String {
        [
            contradiction.topic.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            contradiction.beforeNoteID?.uuidString ?? "",
            contradiction.afterNoteID?.uuidString ?? ""
        ].joined(separator: "|")
    }

    private static func insightFingerprint(_ insight: Insight) -> String {
        [
            insight.kind.rawValue,
            insight.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            insight.sourceNoteIDs.map(\.uuidString).sorted().joined(separator: ",")
        ].joined(separator: "|")
    }

    private static func cleanedThemes(_ themes: [String]) -> [String] {
        let uniqueThemes = Array(
            Set(
                themes
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()

        return Array(uniqueThemes.prefix(4))
    }

    private static func topicCleanupDiagnostics(
        for result: TopicCleanupResult,
        notes: [MemoryNote],
        source: TopicCleanupSource,
        fallbackReason: String? = nil,
        runAt: Date
    ) -> TopicCleanupDiagnostics {
        let notesByID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        let assignmentByNoteID = Dictionary(uniqueKeysWithValues: result.assignments.map { ($0.noteID, $0.themes) })
        let updatedNoteCount = notes.reduce(0) { count, note in
            let assignedThemes = assignmentByNoteID[note.id] ?? ["general"]
            let normalizedThemes = Self.cleanedThemes(assignedThemes)
            return note.themes == normalizedThemes ? count : count + 1
        }
        let largestGroups = result.topics
            .map { TopicCleanupGroupSummary(theme: $0.canonicalTheme, noteCount: $0.sourceNoteIDs.filter { notesByID[$0] != nil }.count) }
            .filter { $0.noteCount > 0 }
            .sorted {
                if $0.noteCount == $1.noteCount {
                    return $0.theme < $1.theme
                }
                return $0.noteCount > $1.noteCount
            }

        return TopicCleanupDiagnostics(
            source: source,
            fallbackReason: fallbackReason,
            updatedNoteCount: updatedNoteCount,
            generatedTopicCount: result.topics.filter { !$0.sourceNoteIDs.isEmpty }.count,
            largestGroups: Array(largestGroups.prefix(5)),
            runAt: runAt
        )
    }

    private static func buildLocalTopicCleanup(from notes: [MemoryNote]) -> TopicCleanupResult {
        let assignments = notes.map { note in
            TopicThemeAssignment(noteID: note.id, themes: localCanonicalThemes(for: note))
        }

        let noteThemes = Dictionary(uniqueKeysWithValues: assignments.map { ($0.noteID, $0.themes) })
        let pairs = notes.flatMap { note in
            (noteThemes[note.id] ?? ["general"]).map { ($0, note) }
        }
        let grouped = Dictionary(grouping: pairs, by: { $0.0 })

        let topics = grouped
            .map { theme, values in
                buildLocalWikiTopic(theme: theme, notes: values.map(\.1), allAssignments: noteThemes)
            }
            .sorted {
                if $0.sourceNoteIDs.count == $1.sourceNoteIDs.count {
                    return $0.title < $1.title
                }
                return $0.sourceNoteIDs.count > $1.sourceNoteIDs.count
            }

        return TopicCleanupResult(topics: topics, assignments: assignments)
    }

    private static func buildTopicCleanup(from notes: [MemoryNote], topics: [WikiTopic]) -> TopicCleanupResult {
        let assignments = notes.map { note in
            TopicThemeAssignment(noteID: note.id, themes: inferCanonicalThemes(for: note, topics: topics))
        }

        let notesByID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        let sourceIDsByTheme = Dictionary(grouping: assignments.flatMap { assignment in
            assignment.themes.map { (theme: $0, noteID: assignment.noteID) }
        }, by: { $0.theme })

        let mergedTopics = topics.map { topic in
            let sourceIDs = (sourceIDsByTheme[topic.canonicalTheme]?.map(\.noteID) ?? topic.sourceNoteIDs)
                .filter { notesByID[$0] != nil }
            var updated = topic
            updated.sourceNoteIDs = Array(Set(sourceIDs)).sorted {
                (notesByID[$0]?.createdAt ?? .distantPast) > (notesByID[$1]?.createdAt ?? .distantPast)
            }
            if updated.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated.summary = notesByID[updated.sourceNoteIDs.first ?? UUID()]?.summary ?? "Notes grouped around \(updated.canonicalTheme)."
            }
            if updated.currentUnderstanding.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated.currentUnderstanding = updated.summary
            }
            return updated
        }

        return TopicCleanupResult(topics: mergedTopics, assignments: assignments)
    }

    private static func localCanonicalThemes(for note: MemoryNote) -> [String] {
        let rawThemes = note.themes.map(normalizedTheme)
        let text = ([note.title, note.summary] + rawThemes).joined(separator: " ").lowercased()
        var themes = rawThemes.map(canonicalTheme)

        for signal in localTextSignals where text.contains(signal.key) {
            themes.append(signal.value)
        }

        let cleaned = cleanedThemes(themes.filter { $0 != "general" })
        return cleaned.isEmpty ? ["general"] : cleaned
    }

    private static func canonicalTheme(_ theme: String) -> String {
        if let exact = canonicalThemeAliases[theme] {
            return exact
        }

        for alias in canonicalThemeAliases where theme.contains(alias.key) {
            return alias.value
        }

        return "ideas"
    }

    private static func inferCanonicalThemes(for note: MemoryNote, topics: [WikiTopic]) -> [String] {
        let searchable = ([note.title, note.summary, note.body] + note.themes)
            .joined(separator: " ")
            .lowercased()
        let rawThemes = note.themes.map(normalizedTheme)
        let localThemes = Set(localCanonicalThemes(for: note))

        let scored = topics.map { topic in
            (theme: topic.canonicalTheme, score: topicScore(topic, searchable: searchable, rawThemes: rawThemes, localThemes: localThemes))
        }
        .filter { $0.score > 0 }
        .sorted {
            if $0.score == $1.score {
                return $0.theme < $1.theme
            }
            return $0.score > $1.score
        }

        let inferred = cleanedThemes(scored.prefix(3).map(\.theme))
        if !inferred.isEmpty {
            return inferred
        }

        if let localMatch = topics.first(where: { localThemes.contains($0.canonicalTheme) }) {
            return [localMatch.canonicalTheme]
        }

        if let ideas = topics.first(where: { $0.canonicalTheme == "ideas" }) {
            return [ideas.canonicalTheme]
        }

        return topics.first.map { [$0.canonicalTheme] } ?? ["general"]
    }

    private static func topicScore(_ topic: WikiTopic, searchable: String, rawThemes: [String], localThemes: Set<String>) -> Int {
        let phrases = topicPhrases(topic)
        let words = topicWords(topic)
        var score = 0

        if localThemes.contains(topic.canonicalTheme) {
            score += 6
        }

        for theme in rawThemes {
            if phrases.contains(theme) {
                score += 5
            }

            if let canonical = canonicalThemeAliases[theme], canonical == topic.canonicalTheme {
                score += 4
            }
        }

        for phrase in phrases where phrase.count > 2 && searchable.contains(phrase) {
            score += 3
        }

        for word in words where searchable.contains(word) {
            score += 1
        }

        return score
    }

    private static func topicPhrases(_ topic: WikiTopic) -> Set<String> {
        Set(([topic.canonicalTheme, topic.title] + topic.aliases + topic.relatedThemes)
            .map(normalizedTheme)
            .filter { !$0.isEmpty })
    }

    private static func topicWords(_ topic: WikiTopic) -> Set<String> {
        let text = topicPhrases(topic).joined(separator: " ")
        return Set(text
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 3 })
    }

    private static func buildLocalWikiTopic(theme: String, notes: [MemoryNote], allAssignments: [UUID: [String]]) -> WikiTopic {
        let sortedNotes = notes.sorted { $0.createdAt > $1.createdAt }
        let title = theme.capitalized
        let sourceNoteIDs = sortedNotes.map(\.id)
        let aliases = aliasesForCanonicalTheme(theme, notes: notes)
        let summaries = sortedNotes.prefix(4).map(\.summary).filter { !$0.isEmpty }
        let summary = summaries.first ?? "Notes grouped around \(theme)."
        let currentUnderstanding = summaries.isEmpty
            ? "This topic collects notes tagged around \(theme)."
            : summaries.joined(separator: "\n\n")
        let subthemes = recurringSubthemes(for: theme, notes: notes)
        let questions = sortedNotes
            .filter { ($0.title + " " + $0.summary + " " + $0.body).contains("?") }
            .prefix(4)
            .map { $0.title }
        let related = relatedThemes(for: sourceNoteIDs, theme: theme, allAssignments: allAssignments)

        return WikiTopic(
            title: title,
            canonicalTheme: theme,
            aliases: aliases,
            summary: summary,
            currentUnderstanding: currentUnderstanding,
            recurringSubthemes: subthemes,
            openQuestions: Array(questions),
            sourceNoteIDs: sourceNoteIDs,
            relatedThemes: related
        )
    }

    private static func aliasesForCanonicalTheme(_ theme: String, notes: [MemoryNote]) -> [String] {
        let aliases = notes
            .flatMap(\.themes)
            .map(normalizedTheme)
            .filter { canonicalTheme($0) == theme && $0 != theme }
        return Array(Set(aliases)).sorted()
    }

    private static func recurringSubthemes(for theme: String, notes: [MemoryNote]) -> [String] {
        let counts = Dictionary(
            grouping: notes.flatMap(\.themes).map(normalizedTheme).filter { canonicalTheme($0) != theme },
            by: { $0 }
        )
        return counts
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
            .prefix(6)
            .map(\.0)
    }

    private static func relatedThemes(for noteIDs: [UUID], theme: String, allAssignments: [UUID: [String]]) -> [String] {
        let counts = Dictionary(
            grouping: noteIDs.flatMap { allAssignments[$0] ?? [] }.filter { $0 != theme },
            by: { $0 }
        )
        return counts
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map(\.0)
    }

    private static func normalizedTheme(_ theme: String) -> String {
        theme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static let canonicalThemeAliases: [String: String] = [
        "ai": "ai tools",
        "artificial intelligence": "ai tools",
        "llm": "ai tools",
        "llms": "ai tools",
        "tools": "ai tools",
        "technology": "ai tools",
        "tech": "ai tools",
        "automation": "ai tools",
        "software": "ai tools",
        "app": "product",
        "career": "career",
        "work": "career",
        "consulting": "career",
        "freelance": "career",
        "job": "career",
        "business": "career",
        "client": "career",
        "babbage": "career",
        "writing": "writing",
        "blog": "writing",
        "blogging": "writing",
        "substack": "writing",
        "content": "writing",
        "essay": "writing",
        "newsletter": "writing",
        "health": "health",
        "mental health": "health",
        "anxiety": "health",
        "stress": "health",
        "emotion": "health",
        "emotions": "health",
        "mood": "health",
        "fitness": "health",
        "sleep": "health",
        "money": "money",
        "finance": "money",
        "finances": "money",
        "invoice": "money",
        "pricing": "money",
        "relationships": "relationships",
        "relationship": "relationships",
        "family": "relationships",
        "friends": "relationships",
        "social": "relationships",
        "productivity": "productivity",
        "priorities": "productivity",
        "habits": "productivity",
        "time": "productivity",
        "planning": "productivity",
        "routine": "productivity",
        "focus": "productivity",
        "decision": "productivity",
        "decisions": "productivity",
        "learning": "learning",
        "books": "learning",
        "reading": "learning",
        "research": "learning",
        "study": "learning",
        "politics": "politics",
        "elections": "politics",
        "election": "politics",
        "india": "politics",
        "bangalore": "places",
        "travel": "places",
        "place": "places",
        "places": "places",
        "home": "places",
        "pensieve": "pensieve",
        "second brain": "pensieve",
        "memory": "pensieve",
        "product": "product",
        "design": "product",
        "ux": "product",
        "feature": "product",
        "features": "product",
        "data": "data",
        "analysis": "data",
        "analytics": "data",
        "chart": "data",
        "charts": "data",
        "visualization": "data",
        "ideas": "ideas",
        "idea": "ideas",
        "creativity": "ideas",
        "reflection": "ideas",
        "philosophy": "ideas"
    ]

    private static let localTextSignals: [String: String] = [
        "claude": "ai tools",
        "openai": "ai tools",
        "chatgpt": "ai tools",
        "codex": "ai tools",
        "swift": "product",
        "ios": "product",
        "client": "career",
        "consulting": "career",
        "invoice": "money",
        "essay": "writing",
        "post": "writing",
        "blog": "writing",
        "workout": "health",
        "sleep": "health",
        "anxious": "health",
        "stress": "health",
        "deadline": "productivity",
        "decision": "productivity",
        "relationship": "relationships",
        "election": "politics",
        "politics": "politics",
        "data": "data",
        "chart": "data",
        "travel": "places",
        "bangalore": "places"
    ]

    private func notesForQuery(_ query: String) -> [MemoryNote] {
        let queryTerms = Set(
            query
                .lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count > 2 }
        )

        let scored = notes.map { note in
            let haystack = ([note.title, note.summary, note.body] + note.themes)
                .joined(separator: " ")
                .lowercased()
            let score = queryTerms.reduce(0) { partial, term in
                partial + (haystack.contains(term) ? 1 : 0)
            }
            return (note: note, score: score)
        }

        let matched = scored
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .map(\.note)

        return Array((matched.isEmpty ? notes : matched).prefix(8))
    }
}
