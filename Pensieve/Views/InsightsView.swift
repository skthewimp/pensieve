import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var appModel: AppModel

    private var analyzer: CorpusAnalyzer {
        CorpusAnalyzer(notes: appModel.notes, contradictions: appModel.contradictions, insights: appModel.insights)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    HStack(spacing: 12) {
                        InsightMetric(title: "Notes", value: "\(appModel.notes.count)", systemImage: "note.text")
                        InsightMetric(title: "Themes", value: "\(analyzer.themeSummaries.count)", systemImage: "tag")
                        InsightMetric(title: "Insights", value: "\(appModel.insights.count)", systemImage: "sparkles")
                    }
                    LabeledContent("Open Loops", value: "\(analyzer.openLoopNotes.count)")
                    LabeledContent("Decisions", value: "\(analyzer.decisionNotes.count)")
                    LabeledContent("Unresolved Tensions", value: "\(analyzer.unresolvedContradictions.count)")
                }

                if !analyzer.weeklyDigests.isEmpty {
                    Section("Weekly Digests") {
                        ForEach(analyzer.weeklyDigests.prefix(4)) { insight in
                            NavigationLink {
                                GeneratedInsightDetailView(insight: insight)
                            } label: {
                                GeneratedInsightRow(insight: insight)
                            }
                        }
                    }
                }

                if !analyzer.resurfacedNotes.isEmpty {
                    Section("Rediscovered Notes") {
                        ForEach(analyzer.resurfacedNotes.prefix(8)) { item in
                            NavigationLink {
                                InsightNoteDetailView(note: item.note)
                            } label: {
                                RediscoveredNoteRow(item: item)
                            }
                        }
                    }
                }

                if !appModel.noteConnections.isEmpty {
                    Section("Retrospective Connections") {
                        ForEach(appModel.noteConnections.prefix(12)) { connection in
                            NavigationLink {
                                NoteConnectionDetailView(connection: connection)
                            } label: {
                                NoteConnectionRow(connection: connection)
                            }
                        }
                    }
                }

                let generatedInsights = appModel.insights.filter { $0.kind != .weeklyDigest }
                if !generatedInsights.isEmpty {
                    Section("Generated Insights") {
                        ForEach(generatedInsights) { insight in
                            NavigationLink {
                                GeneratedInsightDetailView(insight: insight)
                            } label: {
                                GeneratedInsightRow(insight: insight)
                            }
                        }
                    }
                }

                if !analyzer.themeSummaries.isEmpty {
                    Section("Recurring Themes") {
                        ForEach(analyzer.themeSummaries.prefix(8)) { theme in
                            NavigationLink {
                                InsightThemeDetailView(theme: theme)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(theme.name.capitalized)
                                            .font(.headline)
                                        Spacer()
                                        Text("\(theme.notes.count)")
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(theme.recentTitles)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }

                if !analyzer.recentlyActiveThemes.isEmpty {
                    Section("Recently Active") {
                        ForEach(analyzer.recentlyActiveThemes.prefix(6)) { theme in
                            NavigationLink {
                                InsightThemeDetailView(theme: theme)
                            } label: {
                                HStack {
                                    Label(theme.name.capitalized, systemImage: "clock")
                                    Spacer()
                                    Text("\(theme.recentCount)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !analyzer.openLoopNotes.isEmpty {
                    Section("Open Loops") {
                        ForEach(analyzer.openLoopNotes.prefix(8)) { note in
                            NavigationLink {
                                InsightNoteDetailView(note: note)
                            } label: {
                                InsightNoteRow(note: note, systemImage: "questionmark.circle")
                            }
                        }
                    }
                }

                if !analyzer.decisionNotes.isEmpty {
                    Section("Decisions And Plans") {
                        ForEach(analyzer.decisionNotes.prefix(8)) { note in
                            NavigationLink {
                                InsightNoteDetailView(note: note)
                            } label: {
                                InsightNoteRow(note: note, systemImage: "checkmark.circle")
                            }
                        }
                    }
                }

                if !analyzer.unresolvedContradictions.isEmpty {
                    Section("Strongest Contradictions") {
                        ForEach(analyzer.unresolvedContradictions.prefix(5)) { contradiction in
                            NavigationLink {
                                ContradictionDetailView(contradiction: contradiction)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(contradiction.topic)
                                        .font(.headline)
                                    Text(contradiction.explanation)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if appModel.notes.isEmpty {
                    ContentUnavailableView("Insights", systemImage: "chart.bar.doc.horizontal", description: Text("Capture or import notes to see patterns."))
                }
            }
            .navigationTitle("Insights")
        }
    }
}

struct NoteConnectionDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    let connection: NoteConnection

    private var sourceNotes: [MemoryNote] {
        let notesByID = Dictionary(uniqueKeysWithValues: appModel.notes.map { ($0.id, $0) })
        return connection.sourceNoteIDs.compactMap { notesByID[$0] }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Type", value: connection.kind.label)
                LabeledContent("Confidence", value: connection.confidence.formatted(.percent.precision(.fractionLength(0))))
            }

            Section("Connection") {
                Text(connection.explanation)
                    .textSelection(.enabled)

                if !connection.themes.isEmpty {
                    InsightThemeChips(items: connection.themes)
                }
            }

            if !sourceNotes.isEmpty {
                Section("Connected Notes") {
                    ForEach(sourceNotes) { note in
                        NavigationLink {
                            NoteDetailView(note: note)
                        } label: {
                            InsightNoteRow(note: note, systemImage: note.id == sourceNotes.first?.id ? "clock" : "arrow.uturn.backward")
                        }
                    }
                }
            }
        }
        .navigationTitle(connection.title)
    }
}

private struct NoteConnectionRow: View {
    let connection: NoteConnection

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(connection.kind.label, systemImage: connection.kind == .backlink ? "link" : "point.3.connected.trianglepath.dotted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(connection.confidence.formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(connection.title)
                .font(.headline)

            Text(connection.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }
}

private struct InsightMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct GeneratedInsightRow: View {
    let insight: Insight

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(insight.kind.label, systemImage: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(insight.status.label)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }

            Text(insight.title)
                .font(.headline)

            Text(insight.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }

    private var systemImage: String {
        switch insight.kind {
        case .themeSummary:
            return "tag"
        case .pattern:
            return "point.3.connected.trianglepath.dotted"
        case .openLoop:
            return "questionmark.circle"
        case .question:
            return "bubble.left"
        case .decision:
            return "checkmark.circle"
        case .beliefShift:
            return "arrow.triangle.2.circlepath"
        case .weeklyDigest:
            return "calendar.badge.clock"
        }
    }

    private var statusColor: Color {
        switch insight.status {
        case .pending:
            return .secondary
        case .accepted:
            return .green
        case .dismissed:
            return .secondary
        case .important:
            return .orange
        case .superseded:
            return .purple
        }
    }
}

struct GeneratedInsightDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    let insight: Insight

    private var sourceNotes: [MemoryNote] {
        let notesByID = Dictionary(uniqueKeysWithValues: appModel.notes.map { ($0.id, $0) })
        return insight.sourceNoteIDs.compactMap { notesByID[$0] }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Type", value: insight.kind.label)
                LabeledContent("Status", value: insight.status.label)
                if let confidence = insight.confidence {
                    LabeledContent("Confidence", value: confidence.formatted(.percent.precision(.fractionLength(0))))
                }
            }

            Section("Insight") {
                Text(insight.explanation)
                    .textSelection(.enabled)

                if !insight.themes.isEmpty {
                    InsightThemeChips(items: insight.themes)
                }
            }

            Section("Review") {
                Button {
                    Task { await appModel.updateInsight(insight, status: .accepted) }
                } label: {
                    Label("Accept", systemImage: "checkmark.circle")
                }

                Button {
                    Task { await appModel.updateInsight(insight, status: .important) }
                } label: {
                    Label("Mark Important", systemImage: "star")
                }

                Button {
                    Task { await appModel.updateInsight(insight, status: .dismissed) }
                } label: {
                    Label("Dismiss", systemImage: "xmark.circle")
                }

                Button {
                    Task { await appModel.updateInsight(insight, status: .superseded) }
                } label: {
                    Label("Mark Superseded", systemImage: "arrow.uturn.forward.circle")
                }
            }

            if !sourceNotes.isEmpty {
                Section("Source Notes") {
                    ForEach(sourceNotes) { note in
                        NavigationLink {
                            NoteDetailView(note: note)
                        } label: {
                            InsightNoteRow(note: note, systemImage: "note.text")
                        }
                    }
                }
            }
        }
        .navigationTitle(insight.title)
    }
}

private struct InsightThemeChips: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

private struct InsightThemeDetailView: View {
    let theme: ThemeSummary

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Notes", value: "\(theme.notes.count)")
                LabeledContent("Recent", value: "\(theme.recentCount)")
                if !theme.recentTitles.isEmpty {
                    Text(theme.recentTitles)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notes") {
                ForEach(theme.notes) { note in
                    NavigationLink {
                        InsightNoteDetailView(note: note)
                    } label: {
                        InsightNoteRow(note: note, systemImage: "note.text")
                    }
                }
            }
        }
        .navigationTitle(theme.name.capitalized)
    }
}

private struct InsightNoteRow: View {
    let note: MemoryNote
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 5) {
                Text(note.title)
                    .font(.headline)
                Text(note.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }
}

private struct InsightNoteDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    let note: MemoryNote

    private var relatedNotes: [MemoryNote] {
        CorpusAnalyzer(notes: appModel.notes, contradictions: appModel.contradictions)
            .relatedNotes(to: note, limit: 8)
    }

    var body: some View {
        List {
            Section("Summary") {
                Text(note.summary)

                if !note.themes.isEmpty {
                    InsightThemeChips(items: note.themes)
                }
            }

            Section("Body") {
                Text(note.body)
                    .textSelection(.enabled)
            }

            if !relatedNotes.isEmpty {
                Section("Related Notes") {
                    ForEach(relatedNotes) { relatedNote in
                        NavigationLink {
                            InsightNoteDetailView(note: relatedNote)
                        } label: {
                            InsightNoteRow(note: relatedNote, systemImage: "point.3.connected.trianglepath.dotted")
                        }
                    }
                }
            }
        }
        .navigationTitle(note.title)
    }
}

private struct RediscoveredNoteRow: View {
    let item: ResurfacedNote

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "archivebox")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.note.title)
                        .font(.headline)
                    Spacer()
                    Text(item.note.createdAt, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(item.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(item.note.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct CorpusAnalyzer {
    let notes: [MemoryNote]
    let contradictions: [Contradiction]
    let insights: [Insight]

    init(notes: [MemoryNote], contradictions: [Contradiction], insights: [Insight] = []) {
        self.notes = notes
        self.contradictions = contradictions
        self.insights = insights
    }

    private var recentCutoff: Date {
        Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
    }

    private var rediscoveryCutoff: Date {
        Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
    }

    var weeklyDigests: [Insight] {
        insights
            .filter { $0.kind == .weeklyDigest }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var themeSummaries: [ThemeSummary] {
        let pairs = notes.flatMap { note in
            note.themes.map { ($0.normalizedTheme, note) }
        }
        let grouped = Dictionary(grouping: pairs, by: { $0.0 })

        return grouped
            .map { theme, values in
                ThemeSummary(
                    name: theme,
                    notes: values.map(\.1).sorted { $0.createdAt > $1.createdAt },
                    recentCutoff: recentCutoff
                )
            }
            .filter { !$0.name.isEmpty }
            .sorted {
                if $0.notes.count == $1.notes.count {
                    return $0.name < $1.name
                }
                return $0.notes.count > $1.notes.count
            }
    }

    var recentlyActiveThemes: [ThemeSummary] {
        themeSummaries
            .filter { $0.recentCount > 0 }
            .sorted {
                if $0.recentCount == $1.recentCount {
                    return $0.notes.count > $1.notes.count
                }
                return $0.recentCount > $1.recentCount
            }
    }

    var openLoopNotes: [MemoryNote] {
        notes
            .filter { note in
                let text = note.searchableText
                return Self.openLoopSignals.contains { text.contains($0) }
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var decisionNotes: [MemoryNote] {
        notes
            .filter { note in
                let text = note.searchableText
                return Self.decisionSignals.contains { text.contains($0) }
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var unresolvedContradictions: [Contradiction] {
        contradictions
            .filter { $0.status == .unresolved }
            .sorted {
                ($0.confidence ?? 0) == ($1.confidence ?? 0)
                    ? $0.createdAt > $1.createdAt
                    : ($0.confidence ?? 0) > ($1.confidence ?? 0)
            }
    }

    var openContradictionCount: Int {
        unresolvedContradictions.count
    }

    var resurfacedNotes: [ResurfacedNote] {
        let recentThemes = Set(
            notes
                .filter { $0.createdAt >= recentCutoff }
                .flatMap(\.themes)
                .map(\.normalizedTheme)
                .filter { !$0.isEmpty }
        )

        guard !recentThemes.isEmpty else { return [] }

        return notes
            .filter { $0.createdAt < rediscoveryCutoff }
            .compactMap { note -> ResurfacedNote? in
                let matches = note.themes
                    .map(\.normalizedTheme)
                    .filter { recentThemes.contains($0) }
                guard !matches.isEmpty else { return nil }

                let reason = "Older note connected to recent \(matches.prefix(2).map(\.capitalized).joined(separator: ", ")) thinking."
                return ResurfacedNote(note: note, reason: reason, score: matches.count)
            }
            .sorted {
                if $0.score == $1.score {
                    return $0.note.createdAt > $1.note.createdAt
                }
                return $0.score > $1.score
            }
    }

    func relatedNotes(to note: MemoryNote, limit: Int) -> [MemoryNote] {
        let noteThemes = Set(note.themes.map(\.normalizedTheme).filter { !$0.isEmpty })
        let noteTerms = significantTerms(in: note.searchableText)

        let scored = notes
            .filter { $0.id != note.id }
            .map { candidate in
                let candidateThemes = Set(candidate.themes.map(\.normalizedTheme).filter { !$0.isEmpty })
                let sharedThemes = noteThemes.intersection(candidateThemes).count
                let sharedTerms = noteTerms.intersection(significantTerms(in: candidate.searchableText)).count
                let score = (sharedThemes * 4) + min(sharedTerms, 6)
                return (note: candidate, score: score)
            }
            .filter { $0.score > 0 }
            .sorted {
                if $0.score == $1.score {
                    return $0.note.createdAt > $1.note.createdAt
                }
                return $0.score > $1.score
            }

        return Array(scored.prefix(limit).map(\.note))
    }

    private func significantTerms(in text: String) -> Set<String> {
        Set(
            text
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count > 4 && !Self.stopWords.contains($0) }
        )
    }

    private static let openLoopSignals = [
        "?",
        "need to",
        "should i",
        "should we",
        "trying to",
        "figure out",
        "not sure",
        "unclear",
        "open question",
        "follow up",
        "todo",
        "to do"
    ]

    private static let decisionSignals = [
        "decided",
        "decision",
        "plan to",
        "planning to",
        "i will",
        "we will",
        "need to decide",
        "option",
        "tradeoff",
        "next step"
    ]

    private static let stopWords: Set<String> = [
        "about",
        "after",
        "again",
        "could",
        "every",
        "notes",
        "other",
        "really",
        "should",
        "their",
        "there",
        "these",
        "thing",
        "things",
        "think",
        "thought",
        "through",
        "would"
    ]
}

private struct ThemeSummary: Identifiable {
    let name: String
    let notes: [MemoryNote]
    let recentCutoff: Date

    var id: String { name }

    var recentCount: Int {
        notes.filter { $0.createdAt >= recentCutoff }.count
    }

    var recentTitles: String {
        notes.prefix(3).map(\.title).joined(separator: " · ")
    }
}

private struct ResurfacedNote: Identifiable {
    let note: MemoryNote
    let reason: String
    let score: Int

    var id: UUID { note.id }
}

private extension MemoryNote {
    var searchableText: String {
        ([title, summary, body] + themes)
            .joined(separator: " ")
            .lowercased()
    }
}

private extension String {
    var normalizedTheme: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
