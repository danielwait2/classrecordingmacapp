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

    private var restartTimer: Timer?

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

        // Configure for better accuracy
        if #available(macOS 13, iOS 16, *) {
            speechRecognizer?.supportsOnDeviceRecognition = true
        }
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

            // Enhanced sensitivity settings
            if #available(macOS 13, iOS 16, *) {
                recognitionRequest.addsPunctuation = true
                recognitionRequest.requiresOnDeviceRecognition = false // Use server for better accuracy
            }

            // Configure for longer recordings with auto-restart
            recognitionRequest.taskHint = .dictation

            #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #endif

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            // Remove any existing tap
            inputNode.removeTap(onBus: 0)

            // Smaller buffer size for more responsive transcription
            inputNode.installTap(onBus: 0, bufferSize: 512, format: recordingFormat) { [weak self] buffer, _ in
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

                // Handle errors and auto-restart for continuous transcription
                if let error = error {
                    let nsError = error as NSError
                    // Error code 203 = "Retry" (normal timeout after ~1 minute)
                    // Error code 216 = "Canceled"

                    if !self.isStoppingIntentionally {
                        if nsError.code == 203 {
                            // Speech recognition timed out - restart automatically for continuous recording
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                                self?.restartTranscription()
                            }
                        } else if nsError.code != 216 {
                            DispatchQueue.main.async {
                                self.error = error.localizedDescription
                            }
                        }
                    }
                }

                // Auto-restart when recognition finishes (typically after ~1 minute)
                if isFinal && !self.isStoppingIntentionally {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.restartTranscription()
                    }
                }

                if (isFinal || error != nil) && self.isStoppingIntentionally {
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
        restartTimer?.invalidate()
        restartTimer = nil

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

    private func restartTranscription() {
        guard !isStoppingIntentionally else { return }

        // Save current text before restarting
        let currentText = transcribedText

        // Cancel existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        // Wait a moment then restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self, !self.isStoppingIntentionally else { return }

            // Restore previous text
            self.transcribedText = currentText

            // Start new recognition session
            self.startTranscribing()
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

    // MARK: - Post-Recording Transcription

    func transcribeAudioFile(at url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            completion(.failure(NSError(domain: "TranscriptionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is not available"])))
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        if #available(macOS 13, iOS 16, *) {
            request.addsPunctuation = true
        }

        recognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let result = result, result.isFinal {
                completion(.success(result.bestTranscription.formattedString))
            }
        }
    }
}
