import Foundation
import Speech
import AVFoundation

class TranscriptionService: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isTranscribing: Bool = false
    @Published var error: String?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var isStoppingIntentionally = false

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    func startTranscribing() {
        // Reset state
        isStoppingIntentionally = false
        transcribedText = ""
        error = nil

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            error = "Speech recognizer is not available"
            return
        }

        // Cancel any existing task
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        do {
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else { return }

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                error = "Unable to create recognition request"
                return
            }

            recognitionRequest.shouldReportPartialResults = true
            if #available(macOS 13, iOS 16, *) {
                recognitionRequest.addsPunctuation = true
            }

            #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #endif

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            // Remove any existing tap
            inputNode.removeTap(onBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }

                var isFinal = false

                if let result = result {
                    DispatchQueue.main.async {
                        self.transcribedText = result.bestTranscription.formattedString
                    }
                    isFinal = result.isFinal
                }

                // Only show error if we didn't stop intentionally and it's not a cancellation
                if let error = error {
                    let nsError = error as NSError
                    // Error code 203 = "Retry" (normal when stopping)
                    // Error code 216 = "Canceled"
                    // Don't show these as errors to the user
                    if !self.isStoppingIntentionally && nsError.code != 203 && nsError.code != 216 {
                        DispatchQueue.main.async {
                            self.error = error.localizedDescription
                        }
                    }
                }

                if isFinal || error != nil {
                    self.cleanupAudioEngine()
                }
            }

            DispatchQueue.main.async {
                self.isTranscribing = true
                self.error = nil
            }

        } catch {
            self.error = "Failed to start transcription: \(error.localizedDescription)"
            cleanupAudioEngine()
        }
    }

    func pauseTranscribing() {
        audioEngine?.pause()
    }

    func resumeTranscribing() {
        try? audioEngine?.start()
    }

    func stopTranscribing() {
        isStoppingIntentionally = true

        // End audio first to let recognition finish processing
        recognitionRequest?.endAudio()

        // Small delay to allow final results to come through
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.cleanupAudioEngine()
            self?.recognitionTask?.finish()
            self?.recognitionTask = nil
            self?.recognitionRequest = nil

            DispatchQueue.main.async {
                self?.isTranscribing = false
            }
        }
    }

    private func cleanupAudioEngine() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
    }

    func reset() {
        isStoppingIntentionally = true
        stopTranscribing()
        DispatchQueue.main.async {
            self.transcribedText = ""
            self.error = nil
        }
    }
}
