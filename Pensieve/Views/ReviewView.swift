import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var topicRefreshError: String?

    private var pendingInsights: [Insight] {
        appModel.insights
            .filter { $0.status == .pending || $0.status == .important }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var unresolvedContradictions: [Contradiction] {
        appModel.contradictions
            .filter { $0.status == .unresolved }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var tensionsToInspect: [Contradiction] {
        Array(unresolvedContradictions.prefix(5))
    }

    private var topicUpdates: [WikiTopic] {
        appModel.wikiTopics
            .filter { topic in
                topic.status == .pending || topic.status == .stale || topic.status == .needsRefresh
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var openLoopNotes: [MemoryNote] {
        appModel.notes
            .filter { note in
                let text = ([note.title, note.summary, note.body] + note.themes)
                    .joined(separator: " ")
                    .lowercased()
                return Self.openLoopSignals.contains { text.contains($0) }
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var totalReviewCount: Int {
        pendingInsights.count + tensionsToInspect.count + topicUpdates.count + openLoopNotes.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    LabeledContent("Total", value: "\(totalReviewCount)")
                    LabeledContent("Topic Pages", value: "\(topicUpdates.count)")
                    LabeledContent("Insights", value: "\(pendingInsights.count)")
                    LabeledContent("Open Loops", value: "\(openLoopNotes.count)")
                    LabeledContent("Tensions", value: "\(tensionsToInspect.count)")
                }

                if !pendingInsights.isEmpty {
                    Section("Pending Insights") {
                        ForEach(pendingInsights.prefix(20)) { insight in
                            NavigationLink {
                                GeneratedInsightDetailView(insight: insight)
                            } label: {
                                ReviewInsightRow(insight: insight)
                            }
                            .swipeActions {
                                Button {
                                    Task { await appModel.updateInsight(insight, status: .accepted) }
                                } label: {
                                    Label("Accept", systemImage: "checkmark")
                                }
                                .tint(.green)

                                Button(role: .destructive) {
                                    Task { await appModel.updateInsight(insight, status: .dismissed) }
                                } label: {
                                    Label("Dismiss", systemImage: "xmark")
                                }
                            }
                        }
                    }
                }

                if !openLoopNotes.isEmpty {
                    Section("Open Loops") {
                        ForEach(openLoopNotes.prefix(16)) { note in
                            NavigationLink {
                                NoteDetailView(note: note)
                            } label: {
                                ReviewNoteRow(note: note)
                            }
                        }
                    }
                }

                if !topicUpdates.isEmpty {
                    Section("Topic Pages") {
                        ForEach(topicUpdates.prefix(16)) { topic in
                            NavigationLink {
                                WikiTopicView(topic: topic)
                            } label: {
                                ReviewTopicRow(topic: topic)
                            }
                            .swipeActions {
                                Button {
                                    Task { await appModel.updateWikiTopic(topic, status: .useful) }
                                } label: {
                                    Label("Useful", systemImage: "checkmark")
                                }
                                .tint(.green)

                                Button {
                                    refreshTopic(topic)
                                } label: {
                                    Label("Refresh Now", systemImage: "arrow.clockwise")
                                }
                                .tint(.orange)

                                Button {
                                    Task { await appModel.updateWikiTopic(topic, status: .needsRefresh) }
                                } label: {
                                    Label("Mark for Refresh", systemImage: "flag")
                                }
                                .tint(.yellow)

                                Button(role: .destructive) {
                                    Task { await appModel.updateWikiTopic(topic, status: .dismissed) }
                                } label: {
                                    Label("Dismiss", systemImage: "xmark")
                                }
                            }
                        }
                    }
                }

                if !tensionsToInspect.isEmpty {
                    Section {
                        ForEach(tensionsToInspect) { contradiction in
                            NavigationLink {
                                ContradictionDetailView(contradiction: contradiction)
                            } label: {
                                ReviewContradictionRow(contradiction: contradiction)
                            }
                            .swipeActions {
                                Button {
                                    Task { await appModel.updateContradiction(contradiction, status: .reviewed) }
                                } label: {
                                    Label("Seen", systemImage: "checkmark")
                                }
                                .tint(.green)

                                Button(role: .destructive) {
                                    Task { await appModel.updateContradiction(contradiction, status: .dismissed) }
                                } label: {
                                    Label("Dismiss", systemImage: "xmark")
                                }
                            }
                        }
                    } header: {
                        Text("Tensions To Inspect")
                    } footer: {
                        Text("These can stay unresolved. Mark Seen to clear one from Review without dismissing it.")
                    }

                    if unresolvedContradictions.count > tensionsToInspect.count {
                        NavigationLink {
                            ContradictionsView()
                        } label: {
                            Label("Show all \(unresolvedContradictions.count) contradictions", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                }
            }
            .overlay {
                if totalReviewCount == 0 {
                    ContentUnavailableView(
                        "Review",
                        systemImage: "checklist",
                        description: Text("Run analysis from Settings to create reviewable insights, topics, and open loops.")
                    )
                }
            }
            .navigationTitle("Review")
            .alert("Could not refresh topic", isPresented: Binding(
                get: { topicRefreshError != nil },
                set: { isPresented in
                    if !isPresented {
                        topicRefreshError = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(topicRefreshError ?? "")
            }
        }
    }

    private func refreshTopic(_ topic: WikiTopic) {
        Task {
            do {
                try await appModel.refreshWikiTopic(topic)
            } catch {
                await MainActor.run {
                    topicRefreshError = error.localizedDescription
                }
            }
        }
    }

    private static let openLoopSignals = [
        "todo",
        "to do",
        "need to",
        "follow up",
        "follow-up",
        "next step",
        "open question",
        "should i",
        "pending",
        "remember to"
    ]
}

private struct ReviewInsightRow: View {
    let insight: Insight

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(insight.kind.label, systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(insight.status.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(insight.title)
                .font(.headline)
            Text(insight.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }
}

private struct ReviewContradictionRow: View {
    let contradiction: Contradiction

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Tension", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(contradiction.topic)
                .font(.headline)
            Text(contradiction.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }
}

private struct ReviewTopicRow: View {
    let topic: WikiTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Topic", systemImage: "book.closed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(topic.status.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(topic.title)
                .font(.headline)
            Text(topic.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text("\(topic.sourceNoteIDs.count) notes")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct ReviewNoteRow: View {
    let note: MemoryNote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Open Loop", systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(note.title)
                .font(.headline)
            Text(note.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}
