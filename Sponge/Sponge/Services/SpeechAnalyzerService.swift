//
//  SpeechAnalyzerService.swift
//  Sponge
//
//  Voice Memos-level transcription using iOS 26+ SpeechAnalyzer API
//

import Foundation
import Speech
import AVFoundation

@available(iOS 26.0, macOS 26.0, *)
class SpeechAnalyzerService: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isTranscribing: Bool = false
    @Published var error: String?
    @Published var transcriptionProgress: Double = 0.0

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var audioEngine: AVAudioEngine?
    private var isStoppingIntentionally = false

    // Accumulates text across transcriber restarts to prevent words from disappearing
    private var baseTranscript: String = ""
    private var lastResultLength: Int = 0

    init() {
        // Initialize with current locale
        // SpeechAnalyzer will be created when transcription starts
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    func startTranscribing() {
        isStoppingIntentionally = false
        transcribedText = ""
        baseTranscript = ""
        lastResultLength = 0
        error = nil

        Task {
            do {
                print("SpeechAnalyzer: Starting transcription...")

                // Create transcriber with Voice Memos-level settings using progressive preset
                transcriber = SpeechTranscriber(
                    locale: Locale.current,
                    preset: .progressiveTranscription
                )

                guard let transcriber = transcriber else {
                    await MainActor.run {
                        self.error = "Failed to create transcriber"
                    }
                    return
                }

                print("SpeechAnalyzer: Transcriber created")

                // Create input stream
                let (inputSequence, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
                self.inputContinuation = inputContinuation

                print("SpeechAnalyzer: Input stream created")

                // Create analyzer with input sequence
                let newAnalyzer = SpeechAnalyzer(
                    inputSequence: inputSequence,
                    modules: [transcriber]
                )
                analyzer = newAnalyzer

                print("SpeechAnalyzer: Analyzer created")

                // Start processing results
                resultsTask = Task { [weak self] in
                    guard let self = self else { return }

                    do {
                        for try await result in transcriber.results {
                            let newText = String(result.text.characters)
                            await MainActor.run {
                                // SpeechAnalyzer may reset its internal state periodically
                                // If the new text is shorter than what we had, it means a restart occurred
                                // In that case, save current text and append new results
                                if newText.count < self.lastResultLength && !self.transcribedText.isEmpty {
                                    // Transcriber restarted - save accumulated text
                                    self.baseTranscript = self.transcribedText
                                }

                                // Combine base transcript with new text
                                if self.baseTranscript.isEmpty {
                                    self.transcribedText = newText
                                } else {
                                    self.transcribedText = self.baseTranscript + " " + newText
                                }

                                self.lastResultLength = newText.count
                            }
                        }
                    } catch {
                        print("SpeechAnalyzer: Results error: \(error)")
                        await MainActor.run {
                            self.error = "Transcription error: \(error.localizedDescription)"
                        }
                    }
                }

                // Prepare analyzer
                print("SpeechAnalyzer: Preparing analyzer...")
                try await newAnalyzer.prepareToAnalyze(in: nil)
                print("SpeechAnalyzer: Analyzer prepared")

                // Start audio capture
                print("SpeechAnalyzer: Starting audio capture...")
                try await startAudioCapture()
                print("SpeechAnalyzer: Audio capture started")

                await MainActor.run {
                    self.isTranscribing = true
                }

            } catch {
                print("SpeechAnalyzer: Fatal error: \(error)")
                await MainActor.run {
                    self.error = "Failed to start transcription: \(error.localizedDescription)"
                }
            }
        }
    }

    private func startAudioCapture() async throws {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // SpeechAnalyzer requires 16-bit signed integer PCM format at 16 kHz
        guard let analyzerFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "SpeechAnalyzerService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create analyzer audio format"])
        }

        // Create audio converter to convert from recording format to analyzer format
        guard let converter = AVAudioConverter(from: recordingFormat, to: analyzerFormat) else {
            throw NSError(domain: "SpeechAnalyzerService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
        }

        // Remove any existing tap
        inputNode.removeTap(onBus: 0)

        // Install tap with optimal buffer size
        inputNode.installTap(onBus: 0, bufferSize: 8192, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            // Convert to analyzer format (16-bit PCM, 16 kHz, mono)
            let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * analyzerFormat.sampleRate / recordingFormat.sampleRate)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: frameCapacity) else {
                print("SpeechAnalyzer: Failed to create converted buffer")
                return
            }

            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

            if let error = error {
                print("SpeechAnalyzer: Conversion error: \(error)")
                return
            }

            // Send converted buffer to analyzer
            self.inputContinuation?.yield(AnalyzerInput(buffer: convertedBuffer))
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func pauseTranscribing() {
        audioEngine?.pause()
    }

    func resumeTranscribing() {
        try? audioEngine?.start()
    }

    func stopTranscribing() {
        isStoppingIntentionally = true

        // Stop audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        // Finish input stream
        inputContinuation?.finish()
        inputContinuation = nil

        // Cancel results task
        resultsTask?.cancel()
        resultsTask = nil

        // Clean up analyzer and transcriber
        Task { @MainActor in
            analyzer = nil
            transcriber = nil
            isTranscribing = false
        }
    }

    func reset() {
        isStoppingIntentionally = true
        stopTranscribing()

        DispatchQueue.main.async {
            self.transcribedText = ""
            self.baseTranscript = ""
            self.lastResultLength = 0
            self.error = nil
        }
    }

    // MARK: - Post-Recording Transcription

    /// Transcribes an audio file with Voice Memos-level quality
    func transcribeAudioFile(at url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                // Reset progress
                await MainActor.run {
                    self.transcriptionProgress = 0.0
                }

                // Load audio file
                let audioFile = try AVAudioFile(forReading: url)

                // Create transcriber for file transcription
                let fileTranscriber = SpeechTranscriber(
                    locale: Locale.current,
                    preset: .transcription
                )

                // Create analyzer with modules only (no input yet)
                let fileAnalyzer = SpeechAnalyzer(
                    modules: [fileTranscriber]
                )

                // Collect results
                var finalText = ""
                let resultsTask = Task {
                    do {
                        for try await result in fileTranscriber.results {
                            let text = String(result.text.characters)
                            finalText = text

                            // Update progress
                            await MainActor.run {
                                if self.transcriptionProgress < 0.9 {
                                    self.transcriptionProgress += 0.1
                                }
                            }
                        }
                    } catch {
                        print("File transcription result error: \(error)")
                    }
                }

                // Prepare analyzer with file format
                try await fileAnalyzer.prepareToAnalyze(in: audioFile.processingFormat)

                // Analyze the sequence from file - this processes the entire file
                _ = try await fileAnalyzer.analyzeSequence(from: audioFile)

                // Wait for all results
                await resultsTask.value

                // Complete
                await MainActor.run {
                    self.transcriptionProgress = 1.0
                }

                completion(.success(finalText))

            } catch {
                print("File transcription error: \(error)")
                await MainActor.run {
                    self.transcriptionProgress = 0.0
                }
                completion(.failure(error))
            }
        }
    }
}
