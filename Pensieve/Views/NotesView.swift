import SwiftUI

struct NotesView: View {
    @EnvironmentObject private var appModel: AppModel

    private var themeCount: Int {
        Set(appModel.notes.flatMap(\.themes)).count
    }

    private var latestDate: Date? {
        appModel.notes.map(\.createdAt).max()
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    LabeledContent("Notes", value: "\(appModel.notes.count)")
                    LabeledContent("Themes", value: "\(themeCount)")
                    if let latestDate {
                        LabeledContent("Latest", value: latestDate.formatted(date: .abbreviated, time: .omitted))
                    }
                }

                Section("Notes") {
                    ForEach(appModel.notes) { note in
                        NavigationLink {
                            NoteDetailView(note: note)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(note.title)
                                    .font(.headline)
                                Text(note.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .overlay {
                if appModel.notes.isEmpty {
                    ContentUnavailableView("No Notes", systemImage: "note.text", description: Text("Capture text, URLs, or voice notes to build memory."))
                }
            }
            .navigationTitle("Notes")
        }
    }
}

struct NoteDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    let note: MemoryNote

    private var relatedNotes: [MemoryNote] {
        let noteThemes = Set(note.themes.map(normalizedTheme).filter { !$0.isEmpty })
        let noteTerms = significantTerms(in: searchableText(for: note))

        let scored = appModel.notes
            .filter { $0.id != note.id }
            .map { candidate in
                let candidateThemes = Set(candidate.themes.map(normalizedTheme).filter { !$0.isEmpty })
                let sharedThemes = noteThemes.intersection(candidateThemes).count
                let sharedTerms = noteTerms.intersection(significantTerms(in: searchableText(for: candidate))).count
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

        return Array(scored.prefix(8).map(\.note))
    }

    private var backlinks: [NoteConnection] {
        appModel.noteConnections
            .filter { $0.sourceNoteIDs.contains(note.id) }
            .sorted {
                if $0.confidence == $1.confidence {
                    return $0.createdAt > $1.createdAt
                }
                return $0.confidence > $1.confidence
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(note.summary)
                    .font(.headline)

                Text(note.body)

                if !note.themes.isEmpty {
                    Divider()
                    Text("Themes")
                        .font(.headline)
                    FlowLayout(items: note.themes)
                }

                if !backlinks.isEmpty {
                    Divider()
                    Text("Backlinks")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(backlinks.prefix(6)) { connection in
                            NavigationLink {
                                NoteConnectionDetailView(connection: connection)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(connection.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(connection.explanation)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !relatedNotes.isEmpty {
                    Divider()
                    Text("Related Notes")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(relatedNotes) { relatedNote in
                            NavigationLink {
                                NoteDetailView(note: relatedNote)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(relatedNote.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(relatedNote.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(note.title)
    }

    private func searchableText(for note: MemoryNote) -> String {
        ([note.title, note.summary, note.body] + note.themes)
            .joined(separator: " ")
            .lowercased()
    }

    private func significantTerms(in text: String) -> Set<String> {
        Set(
            text
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count > 4 && !Self.stopWords.contains($0) }
        )
    }

    private func normalizedTheme(_ theme: String) -> String {
        theme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

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
