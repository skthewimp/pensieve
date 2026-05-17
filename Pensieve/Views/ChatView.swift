import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack {
                List(appModel.chatMessages) { message in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.role.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(message.content)
                    }
                }

                HStack {
                    TextField("Ask your memory", text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        draft = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .overlay {
                if appModel.chatMessages.isEmpty {
                    ContentUnavailableView("No Chat Yet", systemImage: "bubble.left.and.bubble.right", description: Text("Chat will use local retrieval plus Anthropic."))
                }
            }
            .navigationTitle("Chat")
        }
    }
}
