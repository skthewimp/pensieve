import SwiftUI

struct MindmapView: View {
    @EnvironmentObject private var appModel: AppModel

    private var themeGroups: [(theme: String, notes: [MemoryNote])] {
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
