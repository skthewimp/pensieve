import SwiftUI

struct ContradictionsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            List(appModel.contradictions) { contradiction in
                NavigationLink {
                    ContradictionDetailView(contradiction: contradiction)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(contradiction.topic)
                                .font(.headline)
                            Spacer()
                            Text(contradiction.status.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(statusColor(contradiction.status))
                        }
                        Text(contradiction.explanation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }
            .overlay {
                if appModel.contradictions.isEmpty {
                    ContentUnavailableView("No Contradictions", systemImage: "arrow.triangle.2.circlepath", description: Text("Run analysis from Settings to find source-backed shifts."))
                }
            }
            .navigationTitle("Contradictions")
        }
    }

    private func statusColor(_ status: ContradictionStatus) -> Color {
        switch status {
        case .unresolved:
            return .orange
        case .reviewed:
            return .green
        case .dismissed:
            return .secondary
        }
    }
}

struct ContradictionDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    let contradiction: Contradiction

    private var currentContradiction: Contradiction {
        appModel.contradictions.first(where: { $0.id == contradiction.id }) ?? contradiction
    }

    private var beforeNote: MemoryNote? {
        note(with: currentContradiction.beforeNoteID)
    }

    private var afterNote: MemoryNote? {
        note(with: currentContradiction.afterNoteID)
    }

    var body: some View {
        List {
            Section {
                Text(currentContradiction.explanation)
                    .textSelection(.enabled)

                if let confidence = currentContradiction.confidence {
                    LabeledContent("Confidence", value: confidence.formatted(.percent.precision(.fractionLength(0))))
                }
            } header: {
                Text("Explanation")
            }

            Section("Review") {
                Picker("Status", selection: statusBinding) {
                    ForEach(ContradictionStatus.allCases) { status in
                        Text(status.rawValue.capitalized).tag(status)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Earlier Note") {
                if let beforeNote {
                    NavigationLink {
                        ContradictionSourceNoteView(note: beforeNote)
                    } label: {
                        SourceNoteRow(note: beforeNote)
                    }
                } else {
                    Text("No earlier source note linked.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Later Note") {
                if let afterNote {
                    NavigationLink {
                        ContradictionSourceNoteView(note: afterNote)
                    } label: {
                        SourceNoteRow(note: afterNote)
                    }
                } else {
                    Text("No later source note linked.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(currentContradiction.topic)
    }

    private var statusBinding: Binding<ContradictionStatus> {
        Binding(
            get: { currentContradiction.status },
            set: { status in
                Task {
                    await appModel.updateContradiction(currentContradiction, status: status)
                }
            }
        )
    }

    private func note(with id: UUID?) -> MemoryNote? {
        guard let id else { return nil }
        return appModel.notes.first { $0.id == id }
    }
}

private struct SourceNoteRow: View {
    let note: MemoryNote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.title)
                .font(.headline)
            Text(note.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text(note.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct ContradictionSourceNoteView: View {
    let note: MemoryNote

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(note.summary)
                    .font(.headline)

                if !note.themes.isEmpty {
                    Text(note.themes.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
