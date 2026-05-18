import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack {
                List(appModel.chatMessages) { message in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.role.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(message.content)

                        let sourceNotes = notes(for: message)
                        if !sourceNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Sources")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                ForEach(sourceNotes) { note in
                                    NavigationLink {
                                        NoteDetailView(note: note)
                                    } label: {
                                        Label(note.title, systemImage: "note.text")
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }

                HStack {
                    TextField("Ask your memory", text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task { await send() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || !appModel.isAnthropicConfigured)
                }
                .padding()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
            .overlay {
                if appModel.chatMessages.isEmpty {
                    ContentUnavailableView("No Chat Yet", systemImage: "bubble.left.and.bubble.right", description: Text("Chat will use local retrieval plus Anthropic."))
                }
            }
            .navigationTitle("Chat")
        }
    }

    private func send() async {
        let message = draft
        draft = ""
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            try await appModel.sendChatMessage(message)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func notes(for message: ChatMessage) -> [MemoryNote] {
        guard message.role == .assistant else { return [] }
        let notesByID = Dictionary(uniqueKeysWithValues: appModel.notes.map { ($0.id, $0) })
        return message.contextNoteIDs.compactMap { notesByID[$0] }
    }
}
