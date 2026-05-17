import SwiftUI

struct WikiView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var searchText = ""

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

    private var unthemedNotes: [MemoryNote] {
        filteredNotes
            .filter { $0.themes.isEmpty }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            List {
                if !themeGroups.isEmpty {
                    Section("Themes") {
                        ForEach(themeGroups, id: \.theme) { group in
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
                } else if filteredNotes.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle("Wiki")
        }
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
