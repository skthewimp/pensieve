import SwiftUI
import UIKit

struct ChatView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var copiedMessageID: UUID?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    composer
                } header: {
                    Text(appModel.activeChatSession?.title ?? "Fresh Chat")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else if !appModel.isSelectedLLMConfigured {
                        Text("Configure an LLM provider in Settings to chat with notes.")
                    }
                }

                if appModel.activeChatMessages.isEmpty {
                    Section {
                        ContentUnavailableView("Ask Your Notes", systemImage: "bubble.left.and.text.bubble.right", description: Text("New chats start clean. Past sessions stay in history below."))
                    }
                }

                if !appModel.activeChatMessages.isEmpty {
                    Section("Current Chat") {
                        ForEach(appModel.activeChatMessages) { message in
                            ChatMessageRow(
                                message: message,
                                sourceNotes: notes(for: message),
                                exportMarkdown: appModel.exportMarkdown(for: message),
                                copied: copiedMessageID == message.id,
                                copy: { copyExport(for: message) }
                            )
                        }
                    }
                }

                if !appModel.visibleChatHistory.isEmpty {
                    Section("History") {
                        ForEach(appModel.visibleChatHistory) { session in
                            Button {
                                appModel.openChatSession(session)
                                errorMessage = nil
                                copiedMessageID = nil
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(session.title)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text(Self.historyFormatter.string(from: session.updatedAt))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        draft = ""
                        errorMessage = nil
                        copiedMessageID = nil
                        appModel.startNewChat()
                    } label: {
                        Label("New Chat", systemImage: "plus.bubble")
                    }
                }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask your notes", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)

            Button {
                Task { await send() }
            } label: {
                Image(systemName: isSending ? "hourglass" : "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || !appModel.isSelectedLLMConfigured)
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

    private func copyExport(for message: ChatMessage) {
        UIPasteboard.general.string = appModel.exportMarkdown(for: message)
        copiedMessageID = message.id
    }

    private static let historyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct ChatMessageRow: View {
    let message: ChatMessage
    let sourceNotes: [MemoryNote]
    let exportMarkdown: String
    let copied: Bool
    let copy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(message.role.rawValue.capitalized, systemImage: message.role == .user ? "person" : "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if message.role == .assistant {
                    Button(action: copy) {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)

                    ShareLink(item: exportMarkdown) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }

            Text(message.content)
                .textSelection(.enabled)

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
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}
