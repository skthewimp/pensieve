import SwiftUI

struct MindmapView: View {
    @EnvironmentObject private var appModel: AppModel

    private var themeGroups: [(theme: String, notes: [MemoryNote])] {
        if !appModel.wikiTopics.isEmpty {
            let notesByID = Dictionary(uniqueKeysWithValues: appModel.notes.map { ($0.id, $0) })
            return appModel.wikiTopics.map { topic in
                (
                    theme: topic.title,
                    notes: topic.sourceNoteIDs.compactMap { notesByID[$0] }
                )
            }
            .filter { !$0.notes.isEmpty }
            .sorted {
                if $0.notes.count == $1.notes.count {
                    return $0.theme < $1.theme
                }
                return $0.notes.count > $1.notes.count
            }
        }

        let pairs = appModel.notes.flatMap { note in
            note.themes.map { ($0, note) }
        }
        let grouped = Dictionary(grouping: pairs, by: { $0.0 })
        return grouped
            .map { (theme: $0.key, notes: $0.value.map(\.1)) }
            .sorted { $0.notes.count > $1.notes.count }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    LabeledContent("Groups", value: "\(themeGroups.count)")
                    LabeledContent("Notes", value: "\(themeGroups.reduce(0) { $0 + $1.notes.count })")
                    LabeledContent("Source", value: appModel.wikiTopics.isEmpty ? "Themes" : "Topic Pages")
                }

                ForEach(themeGroups, id: \.theme) { group in
                    Section {
                        ForEach(group.notes) { note in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title)
                                    .font(.headline)
                                Text(note.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    } header: {
                        HStack {
                            Text(group.theme.capitalized)
                            Spacer()
                            Text("\(group.notes.count)")
                        }
                    }
                }
            }
            .overlay {
                if themeGroups.isEmpty {
                    ContentUnavailableView("Mindmap", systemImage: "point.3.connected.trianglepath.dotted", description: Text("Themes will appear after captures are processed."))
                }
            }
            .navigationTitle("Mindmap")
        }
    }
}
