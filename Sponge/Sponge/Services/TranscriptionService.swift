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

    /// Transcribes an audio file from a URL (used for battery save mode)
    func transcribeAudioFile(url: URL) async throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(domain: "TranscriptionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio file not found"])
        }

        let recognizer = SFSpeechRecognizer()
        guard let recognizer = recognizer else {
            throw NSError(domain: "TranscriptionService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
        }

        guard recognizer.isAvailable else {
            throw NSError(domain: "TranscriptionService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
