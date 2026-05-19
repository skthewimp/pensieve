import SwiftUI

struct WikiView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var searchText = ""
    @State private var showAllThemes = false

    private var filteredNotes: [MemoryNote] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return appModel.notes }

        return appModel.notes.filter { note in
            let haystack = ([note.title, note.summary, note.body] + note.themes)
                .joined(separator: " ")
                .lowercased()
            return haystack.contains(query)
        }
    }

    private var themeGroups: [(theme: String, notes: [MemoryNote])] {
        let pairs = filteredNotes.flatMap { note in
            note.themes.map { ($0, note) }
        }
        let grouped = Dictionary(grouping: pairs, by: { $0.0 })
        return grouped
            .map { (theme: $0.key, notes: $0.value.map(\.1).sorted { $0.createdAt > $1.createdAt }) }
            .sorted {
                if $0.notes.count == $1.notes.count {
                    return $0.theme < $1.theme
                }
                return $0.notes.count > $1.notes.count
            }
    }

    private var visibleThemeGroups: [(theme: String, notes: [MemoryNote])] {
        if showAllThemes || !searchText.isEmpty {
            return themeGroups
        }

        return themeGroups.filter { $0.notes.count > 1 }
    }

    private var hiddenThemeCount: Int {
        max(themeGroups.count - visibleThemeGroups.count, 0)
    }

    private var repeatedThemeCount: Int {
        themeGroups.filter { $0.notes.count > 1 }.count
    }

    private var unthemedNotes: [MemoryNote] {
        filteredNotes
            .filter { $0.themes.isEmpty }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var filteredTopics: [WikiTopic] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return appModel.wikiTopics }

        return appModel.wikiTopics.filter { topic in
            let haystack = ([topic.title, topic.canonicalTheme, topic.summary, topic.currentUnderstanding] + topic.aliases + topic.recurringSubthemes + topic.openQuestions + topic.relatedThemes)
                .joined(separator: " ")
                .lowercased()
            return haystack.contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !appModel.notes.isEmpty || !appModel.wikiTopics.isEmpty {
                    Section("Summary") {
                        LabeledContent(searchText.isEmpty ? "Notes" : "Matching Notes", value: "\(filteredNotes.count)")
                        LabeledContent(searchText.isEmpty ? "Topics" : "Matching Topics", value: "\(filteredTopics.count)")
                        LabeledContent("Themes", value: "\(themeGroups.count)")
                        LabeledContent("Repeated Themes", value: "\(repeatedThemeCount)")
                        if !unthemedNotes.isEmpty {
                            LabeledContent("Unthemed", value: "\(unthemedNotes.count)")
                        }
                    }
                }

                if !filteredTopics.isEmpty {
                    Section("Topics") {
                        ForEach(filteredTopics) { topic in
                            NavigationLink {
                                WikiTopicView(topic: topic)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Label(topic.title, systemImage: "book.closed")
                                        Spacer()
                                        Text("\(topic.sourceNoteIDs.count)")
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(topic.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                } else if !visibleThemeGroups.isEmpty {
                    Section {
                        ForEach(visibleThemeGroups, id: \.theme) { group in
                            NavigationLink {
                                WikiThemeView(theme: group.theme, notes: group.notes)
                            } label: {
                                HStack {
                                    Label(group.theme.capitalized, systemImage: "folder")
                                    Spacer()
                                    Text("\(group.notes.count)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if hiddenThemeCount > 0 {
                            Button {
                                showAllThemes = true
                            } label: {
                                Label("Show \(hiddenThemeCount) one-off themes", systemImage: "ellipsis.circle")
                            }
                        }
                    } header: {
                        Text(showAllThemes || !searchText.isEmpty ? "Themes" : "Repeated Themes")
                    }
                }

                Section(searchText.isEmpty ? "Recent Notes" : "Matching Notes") {
                    ForEach(filteredNotes.sorted { $0.createdAt > $1.createdAt }) { note in
                        NavigationLink {
                            WikiNoteDetailView(note: note)
                        } label: {
                            WikiNoteRow(note: note)
                        }
                    }
                }

                if !unthemedNotes.isEmpty {
                    Section("Unthemed") {
                        ForEach(unthemedNotes) { note in
                            NavigationLink {
                                WikiNoteDetailView(note: note)
                            } label: {
                                WikiNoteRow(note: note)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .overlay {
                if appModel.notes.isEmpty {
                    ContentUnavailableView("Wiki", systemImage: "books.vertical", description: Text("Imported and captured notes will appear here."))
                } else if filteredNotes.isEmpty && filteredTopics.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle("Wiki")
        }
    }
}

struct WikiTopicView: View {
    @EnvironmentObject private var appModel: AppModel
    let topic: WikiTopic
    @State private var isRefreshing = false
    @State private var refreshMessage: String?

    private var currentTopic: WikiTopic {
        appModel.wikiTopics.first { $0.id == topic.id }
            ?? appModel.wikiTopics.first { $0.canonicalTheme == topic.canonicalTheme }
            ?? topic
    }

    private var sourceNotes: [MemoryNote] {
        let notesByID = Dictionary(uniqueKeysWithValues: appModel.notes.map { ($0.id, $0) })
        return currentTopic.sourceNoteIDs.compactMap { notesByID[$0] }
    }

    private var relatedInsights: [Insight] {
        let sourceIDs = Set(currentTopic.sourceNoteIDs)
        let topicTerms = Set(([currentTopic.canonicalTheme, currentTopic.title] + currentTopic.aliases + currentTopic.relatedThemes).map(normalized))
        return appModel.insights
            .filter { insight in
                !sourceIDs.isDisjoint(with: insight.sourceNoteIDs)
                    || !topicTerms.isDisjoint(with: insight.themes.map(normalized))
            }
            .sorted { lhs, rhs in
                if lhs.status == rhs.status {
                    return lhs.createdAt > rhs.createdAt
                }
                return insightStatusRank(lhs.status) < insightStatusRank(rhs.status)
            }
    }

    private var relatedContradictions: [Contradiction] {
        let sourceIDs = Set(currentTopic.sourceNoteIDs)
        let topicTerms = Set(([currentTopic.canonicalTheme, currentTopic.title] + currentTopic.aliases + currentTopic.relatedThemes).map(normalized))
        return appModel.contradictions
            .filter { contradiction in
                contradiction.beforeNoteID.map(sourceIDs.contains) == true
                    || contradiction.afterNoteID.map(sourceIDs.contains) == true
                    || topicTerms.contains(normalized(contradiction.topic))
            }
            .sorted { lhs, rhs in
                if lhs.status == rhs.status {
                    return lhs.createdAt > rhs.createdAt
                }
                return contradictionStatusRank(lhs.status) < contradictionStatusRank(rhs.status)
            }
    }

    var body: some View {
        List {
            if isRefreshing || refreshMessage != nil {
                Section {
                    if isRefreshing {
                        ProgressView("Refreshing topic...")
                    }

                    if let refreshMessage {
                        Text(refreshMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Summary") {
                LabeledContent("Status", value: currentTopic.status.label)
                LabeledContent("Source Notes", value: "\(sourceNotes.count)")
                LabeledContent("Related Insights", value: "\(relatedInsights.count)")
                LabeledContent("Related Tensions", value: "\(relatedContradictions.count)")
                if !currentTopic.openQuestions.isEmpty {
                    LabeledContent("Open Questions", value: "\(currentTopic.openQuestions.count)")
                }
            }

            Section {
                Text(currentTopic.currentUnderstanding)
                    .textSelection(.enabled)

                if !currentTopic.aliases.isEmpty {
                    LabeledContent("Aliases", value: currentTopic.aliases.joined(separator: ", "))
                }
            } header: {
                Text(currentTopic.summary)
            }

            Section("Review") {
                Button {
                    refreshTopic()
                } label: {
                    Label("Refresh Now", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing || !appModel.isAnthropicConfigured)

                Button {
                    updateTopicStatus(.useful)
                } label: {
                    Label("Mark Useful", systemImage: "checkmark.circle")
                }

                Button {
                    updateTopicStatus(.needsRefresh)
                } label: {
                    Label("Mark for Refresh", systemImage: "flag")
                }

                Button(role: .destructive) {
                    updateTopicStatus(.dismissed)
                } label: {
                    Label("Dismiss From Review", systemImage: "xmark.circle")
                }
            }

            if !currentTopic.recurringSubthemes.isEmpty {
                Section("Recurring Subthemes") {
                    ForEach(currentTopic.recurringSubthemes, id: \.self) { subtheme in
                        Text(subtheme)
                    }
                }
            }

            if !currentTopic.openQuestions.isEmpty {
                Section("Open Questions") {
                    ForEach(currentTopic.openQuestions, id: \.self) { question in
                        Text(question)
                    }
                }
            }

            if !currentTopic.relatedThemes.isEmpty {
                Section("Related Topics") {
                    ForEach(currentTopic.relatedThemes, id: \.self) { theme in
                        Text(theme.capitalized)
                    }
                }
            }

            if !relatedInsights.isEmpty {
                Section("Related Insights") {
                    ForEach(relatedInsights.prefix(8)) { insight in
                        NavigationLink {
                            GeneratedInsightDetailView(insight: insight)
                        } label: {
                            WikiInsightRow(insight: insight)
                        }
                    }
                }
            }

            if !relatedContradictions.isEmpty {
                Section("Related Contradictions") {
                    ForEach(relatedContradictions.prefix(8)) { contradiction in
                        NavigationLink {
                            ContradictionDetailView(contradiction: contradiction)
                        } label: {
                            WikiContradictionRow(contradiction: contradiction)
                        }
                    }
                }
            }

            Section("Source Notes") {
                ForEach(sourceNotes) { note in
                    NavigationLink {
                        WikiNoteDetailView(note: note)
                    } label: {
                        WikiNoteRow(note: note)
                    }
                }
            }
        }
        .navigationTitle(currentTopic.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    refreshTopic()
                } label: {
                    Label("Refresh Now", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing || !appModel.isAnthropicConfigured)
            }
        }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func insightStatusRank(_ status: InsightStatus) -> Int {
        switch status {
        case .pending:
            return 0
        case .important:
            return 1
        case .accepted:
            return 2
        case .superseded:
            return 3
        case .dismissed:
            return 4
        }
    }

    private func contradictionStatusRank(_ status: ContradictionStatus) -> Int {
        switch status {
        case .unresolved:
            return 0
        case .reviewed:
            return 1
        case .dismissed:
            return 2
        }
    }

    private func refreshTopic() {
        isRefreshing = true
        refreshMessage = nil

        Task {
            do {
                try await appModel.refreshWikiTopic(currentTopic)
                await MainActor.run {
                    refreshMessage = "Topic refreshed."
                    isRefreshing = false
                }
            } catch {
                await MainActor.run {
                    refreshMessage = error.localizedDescription
                    isRefreshing = false
                }
            }
        }
    }

    private func updateTopicStatus(_ status: WikiTopicStatus) {
        Task {
            await appModel.updateWikiTopic(currentTopic, status: status)
            await MainActor.run {
                refreshMessage = "Status: \(status.label)."
            }
        }
    }
}

private struct WikiInsightRow: View {
    let insight: Insight

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(insight.title)
                    .font(.headline)
                Spacer()
                Text(insight.status.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(insight.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }
}

private struct WikiContradictionRow: View {
    let contradiction: Contradiction

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(contradiction.topic)
                    .font(.headline)
                Spacer()
                Text(contradiction.status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(contradiction.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }
}

private struct WikiThemeView: View {
    let theme: String
    let notes: [MemoryNote]

    private var latestDate: Date? {
        notes.map(\.createdAt).max()
    }

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Notes", value: "\(notes.count)")
                if let latestDate {
                    LabeledContent("Latest", value: latestDate.formatted(date: .abbreviated, time: .omitted))
                }
            }

            Section("Notes") {
                ForEach(notes) { note in
                    NavigationLink {
                        WikiNoteDetailView(note: note)
                    } label: {
                        WikiNoteRow(note: note)
                    }
                }
            }
        }
        .navigationTitle(theme.capitalized)
    }
}

private struct WikiNoteRow: View {
    let note: MemoryNote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.title)
                .font(.headline)
            Text(note.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if !note.themes.isEmpty {
                Text(note.themes.prefix(4).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }
}

private struct WikiNoteDetailView: View {
    let note: MemoryNote

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(note.summary)
                    .font(.headline)

                if !note.themes.isEmpty {
                    FlowLayout(items: note.themes)
                }

                Divider()

                Text(note.body)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(note.title)
    }
}

private struct FlowLayout: View {
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
