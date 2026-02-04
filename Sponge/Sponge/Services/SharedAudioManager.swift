//
//  SharedAudioManager.swift
//  Sponge
//
//  Manages shared audio input on macOS to prevent conflicts between
//  AVAudioRecorder and AVAudioEngine when both recording and transcription
//  need microphone access simultaneously.
//

import Foundation
import AVFoundation

#if os(macOS)
/// Singleton that manages shared audio engine access on macOS
/// This prevents conflicts when both recording and transcription need the microphone
class SharedAudioManager {
    static let shared = SharedAudioManager()

    private(set) var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var isRecording = false
    private var recordingURL: URL?

    // Callbacks for transcription service to receive audio buffers
    var transcriptionBufferHandler: ((AVAudioPCMBuffer) -> Void)?

    private init() {}

    /// Starts the shared audio engine and optionally begins recording to file
    func startAudioEngine(recordingToURL url: URL?) throws {
        // Stop any existing engine
        stopAudioEngine()

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw NSError(domain: "SharedAudioManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create audio engine"])
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // If recording, create the audio file
        if let url = url {
            // Create recording format (AAC)
            let recordingSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: inputFormat.sampleRate,
                AVNumberOfChannelsKey: inputFormat.channelCount,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
                AVEncoderBitRateKey: 256000
            ]

            audioFile = try AVAudioFile(forWriting: url, settings: recordingSettings)
            recordingURL = url
            isRecording = true
        }

        // Install tap that handles both recording and transcription
        inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            // Write to file if recording
            if self.isRecording, let audioFile = self.audioFile {
                do {
                    try audioFile.write(from: buffer)
                } catch {
                    print("SharedAudioManager: Error writing to file: \(error)")
                }
            }

            // Send to transcription handler
            self.transcriptionBufferHandler?(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    /// Pauses audio capture (for pause recording functionality)
    func pauseAudioEngine() {
        audioEngine?.pause()
    }

    /// Resumes audio capture after pause
    func resumeAudioEngine() throws {
        try audioEngine?.start()
    }

    /// Stops the audio engine and finalizes any recording
    func stopAudioEngine() -> URL? {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        let url = recordingURL
        audioFile = nil
        recordingURL = nil
        isRecording = false

        return url
    }

    /// Returns the input format for transcription services to use
    var inputFormat: AVAudioFormat? {
        return audioEngine?.inputNode.outputFormat(forBus: 0)
    }
}
#endif
