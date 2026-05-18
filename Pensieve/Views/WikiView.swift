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

private struct WikiTopicView: View {
    @EnvironmentObject private var appModel: AppModel
    let topic: WikiTopic

    private var sourceNotes: [MemoryNote] {
        let notesByID = Dictionary(uniqueKeysWithValues: appModel.notes.map { ($0.id, $0) })
        return topic.sourceNoteIDs.compactMap { notesByID[$0] }
    }

    var body: some View {
        List {
            Section {
                Text(topic.currentUnderstanding)
                    .textSelection(.enabled)

                if !topic.aliases.isEmpty {
                    LabeledContent("Aliases", value: topic.aliases.joined(separator: ", "))
                }
            } header: {
                Text(topic.summary)
            }

            if !topic.recurringSubthemes.isEmpty {
                Section("Recurring Subthemes") {
                    ForEach(topic.recurringSubthemes, id: \.self) { subtheme in
                        Text(subtheme)
                    }
                }
            }

            if !topic.openQuestions.isEmpty {
                Section("Open Questions") {
                    ForEach(topic.openQuestions, id: \.self) { question in
                        Text(question)
                    }
                }
            }

            if !topic.relatedThemes.isEmpty {
                Section("Related Topics") {
                    ForEach(topic.relatedThemes, id: \.self) { theme in
                        Text(theme.capitalized)
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
        .navigationTitle(topic.title)
    }
}

private struct WikiThemeView: View {
    let theme: String
    let notes: [MemoryNote]

    var body: some View {
        List(notes) { note in
            NavigationLink {
                WikiNoteDetailView(note: note)
            } label: {
                WikiNoteRow(note: note)
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
