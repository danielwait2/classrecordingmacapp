import Foundation
import Speech
import AVFoundation

class TranscriptionService: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isTranscribing: Bool = false
    @Published var error: String?

    // macOS 26+ SpeechAnalyzer for Voice Memos-level quality (stored as Any to avoid @available on stored properties)
    private var modernAnalyzer: Any?

    // Fallback to traditional Speech Recognition for older systems
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // Thread-safe state protected by stateQueue
    private let stateQueue = DispatchQueue(label: "com.sponge.transcription.state")
    private var _isStoppingIntentionally = false
    private var _baseTranscript: String = ""
    private var _restartCount: Int = 0
    private let maxRestarts = 50

    private var isStoppingIntentionally: Bool {
        get { stateQueue.sync { _isStoppingIntentionally } }
        set { stateQueue.sync { _isStoppingIntentionally = newValue } }
    }

    private var baseTranscript: String {
        get { stateQueue.sync { _baseTranscript } }
        set { stateQueue.sync { _baseTranscript = newValue } }
    }

    private var restartCount: Int {
        get { stateQueue.sync { _restartCount } }
        set { stateQueue.sync { _restartCount = newValue } }
    }

    private var restartTimer: Timer?

    // Check if we can use the modern API
    private var useModernAPI: Bool {
        if #available(macOS 26.0, *) {
            return modernAnalyzer != nil
        }
        return false
    }

    init() {
        if #available(macOS 26.0, *) {
            // Use modern SpeechAnalyzer API (Voice Memos quality)
            let analyzer = SpeechAnalyzerService()
            modernAnalyzer = analyzer
            setupAnalyzerBindings(analyzer)
        } else {
            // Fallback to traditional Speech Recognition
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

            // Configure for better accuracy
            if #available(macOS 13, *) {
                speechRecognizer?.supportsOnDeviceRecognition = true
            }
        }
    }

    @available(macOS 26.0, *)
    private func setupAnalyzerBindings(_ analyzer: SpeechAnalyzerService) {
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
        // Use modern API if available
        if #available(macOS 26.0, *), modernAnalyzer != nil {
            startTranscribingModern()
            return
        }

        // Fallback to legacy implementation
        startTranscribingLegacy()
    }

    @available(macOS 26.0, *)
    private func startTranscribingModern() {
        guard let analyzer = modernAnalyzer as? SpeechAnalyzerService else { return }

        // Wire SharedAudioManager buffers to SpeechAnalyzerService
        SharedAudioManager.shared.transcriptionBufferHandler = { [weak analyzer] buffer in
            analyzer?.appendBuffer(buffer)
        }

        analyzer.startTranscribing()
    }

    private func startTranscribingLegacy() {
        // Reset state
        isStoppingIntentionally = false
        baseTranscript = "" // Only reset on fresh start
        restartCount = 0
        transcribedText = ""
        error = nil

        print("TranscriptionService: Starting legacy transcription")

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            error = "Speech recognizer is not available"
            print("TranscriptionService: Speech recognizer not available")
            return
        }

        print("TranscriptionService: Speech recognizer is available")

        // Cancel any existing task
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        do {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                error = "Unable to create recognition request"
                print("TranscriptionService: Failed to create recognition request")
                return
            }

            print("TranscriptionService: Recognition request created")

            recognitionRequest.shouldReportPartialResults = true

            // Voice Memos-level quality settings
            if #available(macOS 13, *) {
                recognitionRequest.addsPunctuation = true
                recognitionRequest.requiresOnDeviceRecognition = false // Server-side for best quality
            }

            // Dictation mode provides best sensitivity
            recognitionRequest.taskHint = .dictation

            // Advanced recognition features
            if #available(macOS 14, *) {
                recognitionRequest.contextualStrings = [] // Better uncommon word recognition
            }

            // On macOS, use SharedAudioManager to receive audio buffers
            // The AudioRecordingService starts the SharedAudioManager, we just hook into it
            print("TranscriptionService: Setting up buffer handler for SharedAudioManager")
            SharedAudioManager.shared.transcriptionBufferHandler = { [weak self] buffer in
                print("TranscriptionService: Received buffer with \(buffer.frameLength) frames")
                self?.recognitionRequest?.append(buffer)
            }

            print("TranscriptionService: Starting recognition task")

            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }

                var isFinal = false

                if let result = result {
                    let newText = result.bestTranscription.formattedString
                    print("TranscriptionService: Got result: \(newText.prefix(50))...")
                    DispatchQueue.main.async {
                        // Append new text to base transcript
                        if self.baseTranscript.isEmpty {
                            self.transcribedText = newText
                        } else {
                            self.transcribedText = self.baseTranscript + " " + newText
                        }
                    }
                    isFinal = result.isFinal
                }

                // Handle errors and auto-restart for continuous transcription
                if let error = error {
                    let nsError = error as NSError
                    print("TranscriptionService: Recognition error - code: \(nsError.code), message: \(error.localizedDescription)")
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

            print("TranscriptionService: Transcription started successfully")

        } catch {
            print("TranscriptionService: Failed to start - \(error.localizedDescription)")
            self.error = "Failed to start transcription: \(error.localizedDescription)"
            cleanupAudioEngine()
        }
    }

    func pauseTranscribing() {
        if #available(macOS 26.0, *), modernAnalyzer != nil {
            pauseTranscribingModern()
            return
        }
        // On macOS, SharedAudioManager handles pause via AudioRecordingService
    }

    @available(macOS 26.0, *)
    private func pauseTranscribingModern() {
        guard let analyzer = modernAnalyzer as? SpeechAnalyzerService else { return }
        analyzer.pauseTranscribing()
    }

    func resumeTranscribing() {
        if #available(macOS 26.0, *), modernAnalyzer != nil {
            resumeTranscribingModern()
            return
        }
        // On macOS, SharedAudioManager handles resume via AudioRecordingService
    }

    @available(macOS 26.0, *)
    private func resumeTranscribingModern() {
        guard let analyzer = modernAnalyzer as? SpeechAnalyzerService else { return }
        analyzer.resumeTranscribing()
    }

    func stopTranscribing() {
        if #available(macOS 26.0, *), modernAnalyzer != nil {
            stopTranscribingModern()
            return
        }

        isStoppingIntentionally = true
        restartCount = 0
        restartTimer?.invalidate()
        restartTimer = nil

        // Clear the buffer handler
        SharedAudioManager.shared.transcriptionBufferHandler = nil

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

    @available(macOS 26.0, *)
    private func stopTranscribingModern() {
        guard let analyzer = modernAnalyzer as? SpeechAnalyzerService else { return }

        // Clear buffer handler before stopping
        SharedAudioManager.shared.transcriptionBufferHandler = nil

        analyzer.stopTranscribing()
    }

    private func restartTranscription() {
        guard !isStoppingIntentionally else { return }

        restartCount += 1
        if restartCount > maxRestarts {
            print("TranscriptionService: Hit max restart limit (\(maxRestarts)). Stopping automatic restarts.")
            DispatchQueue.main.async {
                self.error = "Transcription restarted too many times. Recording continues but live transcription has stopped."
            }
            return
        }

        // Save current accumulated text to base transcript BEFORE canceling
        // This ensures we don't lose any text during the restart
        let savedTranscript = transcribedText
        baseTranscript = savedTranscript

        // Cancel existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        // Don't call startTranscribing() - continue the current session
        // Wait a moment then restart recognition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self, !self.isStoppingIntentionally else { return }

            // Ensure baseTranscript is still correct (in case of race conditions)
            if self.baseTranscript.isEmpty && !savedTranscript.isEmpty {
                self.baseTranscript = savedTranscript
            }

            do {
                // Recreate recognition request
                self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
                guard let recognitionRequest = self.recognitionRequest else { return }

                recognitionRequest.shouldReportPartialResults = true

                if #available(macOS 13, *) {
                    recognitionRequest.addsPunctuation = true
                    recognitionRequest.requiresOnDeviceRecognition = false
                }

                recognitionRequest.taskHint = .dictation

                if #available(macOS 14, *) {
                    recognitionRequest.contextualStrings = []
                }

                // Re-attach to SharedAudioManager
                SharedAudioManager.shared.transcriptionBufferHandler = { [weak self] buffer in
                    self?.recognitionRequest?.append(buffer)
                }

                // Continue using SharedAudioManager
                guard let recognizer = self.speechRecognizer else { return }

                // Capture baseTranscript at task creation time to avoid race conditions
                let currentBase = self.baseTranscript

                self.recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                    guard let self = self else { return }

                    var isFinal = false

                    if let result = result {
                        let newText = result.bestTranscription.formattedString
                        DispatchQueue.main.async {
                            // Append new text to base transcript
                            // Use the captured base to avoid race conditions
                            if currentBase.isEmpty {
                                self.transcribedText = newText
                            } else {
                                self.transcribedText = currentBase + " " + newText
                            }
                            // Update baseTranscript to match the current captured base
                            // This ensures consistency across multiple restarts
                            self.baseTranscript = currentBase
                        }
                        isFinal = result.isFinal
                    }

                    if let error = error {
                        let nsError = error as NSError
                        if !self.isStoppingIntentionally {
                            if nsError.code == 203 {
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

                    if isFinal && !self.isStoppingIntentionally {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            self?.restartTranscription()
                        }
                    }

                    if (isFinal || error != nil) && self.isStoppingIntentionally {
                        self.cleanupAudioEngine()
                    }
                }

            } catch {
                DispatchQueue.main.async {
                    self.error = "Failed to restart transcription: \(error.localizedDescription)"
                }
            }
        }
    }

    private func cleanupAudioEngine() {
        // On macOS, just clear the handler - SharedAudioManager manages the engine
        SharedAudioManager.shared.transcriptionBufferHandler = nil
    }

    func reset() {
        if #available(macOS 26.0, *), modernAnalyzer != nil {
            resetModern()
            return
        }

        isStoppingIntentionally = true
        stopTranscribing()
        DispatchQueue.main.async {
            self.transcribedText = ""
            self.baseTranscript = ""
            self.error = nil
        }
    }

    @available(macOS 26.0, *)
    private func resetModern() {
        guard let analyzer = modernAnalyzer as? SpeechAnalyzerService else { return }
        SharedAudioManager.shared.transcriptionBufferHandler = nil
        analyzer.reset()
    }
}
