import SwiftUI

struct ContradictionsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            List(appModel.contradictions) { contradiction in
                VStack(alignment: .leading, spacing: 6) {
                    Text(contradiction.topic)
                        .font(.headline)
                    Text(contradiction.explanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(contradiction.status.rawValue.capitalized)
                        .font(.caption)
                }
            }
            .overlay {
                if appModel.contradictions.isEmpty {
                    ContentUnavailableView("No Contradictions", systemImage: "arrow.triangle.2.circlepath", description: Text("Source-backed shifts will appear here after memory processing is wired."))
                }
            }
            .navigationTitle("Contradictions")
        }
    }
}
