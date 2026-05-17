import SwiftUI

struct NotesView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            List(appModel.notes) { note in
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
            .overlay {
                if appModel.notes.isEmpty {
                    ContentUnavailableView("No Notes", systemImage: "note.text", description: Text("Capture text, URLs, or voice notes to build memory."))
                }
            }
            .navigationTitle("Notes")
        }
    }
}

private struct NoteDetailView: View {
    let note: MemoryNote

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
