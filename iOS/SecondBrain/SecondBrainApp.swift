import SwiftUI

@main
struct SecondBrainApp: App {
    @StateObject private var captureService = ThoughtCaptureService()
    @AppStorage("anthropicAPIKey") private var apiKey = ""

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(captureService)
                .task {
                    // Configure API key if saved
                    if !apiKey.isEmpty {
                        captureService.configure(apiKey: apiKey)
                    }

                    // Load Whisper model in background
                    await captureService.loadWhisperModel()
                }
        }
    }
}
