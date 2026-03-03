import Foundation
import Speech
import AVFoundation

/// Wrapper service for the modern SpeechAnalyzer API (macOS 26+)
/// Now that we target macOS 26.0+, this uses only SpeechAnalyzerService
class TranscriptionService: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isTranscribing: Bool = false
    @Published var error: String?

    private let analyzer: SpeechAnalyzerService

    init() {
        analyzer = SpeechAnalyzerService()
        setupAnalyzerBindings()
    }

    private func setupAnalyzerBindings() {
        // Forward published properties from SpeechAnalyzerService
        analyzer.$transcribedText.assign(to: &$transcribedText)
        analyzer.$isTranscribing.assign(to: &$isTranscribing)
        analyzer.$error.assign(to: &$error)
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    func startTranscribing() {
        // Wire SharedAudioManager buffers to SpeechAnalyzerService
        SharedAudioManager.shared.transcriptionBufferHandler = { [weak analyzer] buffer in
            analyzer?.appendBuffer(buffer)
        }

        analyzer.startTranscribing()
    }

    func pauseTranscribing() {
        analyzer.pauseTranscribing()
    }

    func resumeTranscribing() {
        analyzer.resumeTranscribing()
    }

    func stopTranscribing() {
        // Clear buffer handler before stopping
        SharedAudioManager.shared.transcriptionBufferHandler = nil
        analyzer.stopTranscribing()
    }

    func reset() {
        SharedAudioManager.shared.transcriptionBufferHandler = nil
        analyzer.reset()
    }

    /// Transcribes an audio file from a URL using SpeechAnalyzer with the `.offlineTranscription`
    /// preset, which uses full bidirectional context for higher accuracy than the live progressive pass.
    func transcribeAudioFile(url: URL) async throws -> String {
        try await analyzer.transcribeFile(at: url)
    }
}
