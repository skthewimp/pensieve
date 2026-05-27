import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            CaptureView()
                .tabItem {
                    Label("Capture", systemImage: "mic.circle")
                }

            MemoryHubView()
                .tabItem {
                    Label("Memory", systemImage: "books.vertical")
                }

            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }

            ReviewHubView()
                .tabItem {
                    Label("Review", systemImage: "checklist")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

private enum MemorySection: String, CaseIterable, Identifiable {
    case notes = "Notes"
    case topics = "Topics"
    case map = "Map"

    var id: String { rawValue }
}

private struct MemoryHubView: View {
    @State private var selection: MemorySection = .notes

    var body: some View {
        VStack(spacing: 0) {
            Picker("Memory", selection: $selection) {
                ForEach(MemorySection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])
            .padding(.bottom, 8)

            Divider()

            switch selection {
            case .notes:
                NotesView()
            case .topics:
                WikiView()
            case .map:
                MindmapView()
            }
        }
    }
}

private enum ReviewSection: String, CaseIterable, Identifiable {
    case queue = "Queue"
    case insights = "Insights"
    case tensions = "Tensions"

    var id: String { rawValue }
}

private struct ReviewHubView: View {
    @State private var selection: ReviewSection = .queue

    var body: some View {
        VStack(spacing: 0) {
            Picker("Review", selection: $selection) {
                ForEach(ReviewSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])
            .padding(.bottom, 8)

            Divider()

            switch selection {
            case .queue:
                ReviewView()
            case .insights:
                InsightsView()
            case .tensions:
                ContradictionsView()
            }
        }
    }
}
