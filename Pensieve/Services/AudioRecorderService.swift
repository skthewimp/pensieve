import AVFoundation
import Foundation
import UIKit

@MainActor
final class AudioRecorderService: NSObject, ObservableObject {
    struct FinishedRecording {
        let url: URL
        let duration: TimeInterval
    }

    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var currentRecordingURL: URL?
    private var wasIdleTimerDisabled = false
    let recordingsDirectory: URL

    override init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.recordingsDirectory = documentsURL.appendingPathComponent("Recordings", isDirectory: true)
        super.init()

        try? FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() -> URL? {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)

            let audioURL = recordingsDirectory.appendingPathComponent("capture-\(Date().timeIntervalSince1970).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()

            currentRecordingURL = audioURL
            isRecording = true
            recordingDuration = 0
            wasIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.recordingDuration = self?.audioRecorder?.currentTime ?? 0
                }
            }

            return audioURL
        } catch {
            UIApplication.shared.isIdleTimerDisabled = wasIdleTimerDisabled
            currentRecordingURL = nil
            print("Failed to start recording: \(error)")
            return nil
        }
    }

    func stopRecording() -> FinishedRecording? {
        let url = currentRecordingURL
        let duration = audioRecorder?.currentTime ?? recordingDuration
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        recordingDuration = duration
        currentRecordingURL = nil
        UIApplication.shared.isIdleTimerDisabled = wasIdleTimerDisabled
        try? AVAudioSession.sharedInstance().setActive(false)
        guard let url else { return nil }
        return FinishedRecording(url: url, duration: duration)
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            audioRecorder?.pause()
        case .ended:
            guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume), isRecording {
                try? AVAudioSession.sharedInstance().setActive(true)
                audioRecorder?.record()
            }
        @unknown default:
            break
        }
    }
}

extension AudioRecorderService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
        }
    }
}
