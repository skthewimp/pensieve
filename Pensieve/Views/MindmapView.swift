import SwiftUI

struct MindmapView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Mindmap", systemImage: "point.3.connected.trianglepath.dotted", description: Text("The first graph will connect notes, themes, and contradictions."))
                .navigationTitle("Mindmap")
        }
    }
}
