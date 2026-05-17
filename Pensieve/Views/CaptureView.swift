import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var text = ""
    @State private var urlText = ""
    @State private var urlNote = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Voice") {
                    Button {
                        // Voice recording will be wired after the app shell is stable.
                    } label: {
                        Label("Record Voice Note", systemImage: "mic.fill")
                    }
                }

                Section("Text") {
                    TextEditor(text: $text)
                        .frame(minHeight: 120)

                    Button {
                        Task { await submitText() }
                    } label: {
                        Label("Save Text", systemImage: "tray.and.arrow.down")
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }

                Section("URL") {
                    TextField("https://example.com", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                    TextField("Optional note", text: $urlNote, axis: .vertical)

                    Button {
                        Task { await submitURL() }
                    } label: {
                        Label("Save URL", systemImage: "link")
                    }
                    .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Capture")
        }
    }

    private func submitText() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await appModel.captureService.submitText(text)
            text = ""
            await appModel.refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitURL() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await appModel.captureService.submitURL(urlText, note: urlNote)
            urlText = ""
            urlNote = ""
            await appModel.refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
