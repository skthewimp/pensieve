import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            CaptureView()
                .tabItem {
                    Label("Capture", systemImage: "mic.circle")
                }

            NotesView()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }

            WikiView()
                .tabItem {
                    Label("Wiki", systemImage: "books.vertical")
                }

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.doc.horizontal")
                }

            ReviewView()
                .tabItem {
                    Label("Review", systemImage: "checklist")
                }

            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }

            ContradictionsView()
                .tabItem {
                    Label("Contradictions", systemImage: "arrow.triangle.2.circlepath")
                }

            MindmapView()
                .tabItem {
                    Label("Mindmap", systemImage: "point.3.connected.trianglepath.dotted")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
