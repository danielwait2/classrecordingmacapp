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
    private var outputFormat: AVAudioFormat?

    // Callbacks for transcription service to receive audio buffers
    var transcriptionBufferHandler: ((AVAudioPCMBuffer) -> Void)?

    private init() {}

    /// Starts the shared audio engine and optionally begins recording to file
    func startAudioEngine(recordingToURL url: URL?) throws {
        // Stop any existing engine
        _ = stopAudioEngine()

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw NSError(domain: "SharedAudioManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create audio engine"])
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        print("SharedAudioManager: Input format - sampleRate: \(inputFormat.sampleRate), channels: \(inputFormat.channelCount)")

        // Validate input format
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            throw NSError(domain: "SharedAudioManager", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid input format - sampleRate: \(inputFormat.sampleRate), channels: \(inputFormat.channelCount)"])
        }

        // If recording, create the audio file
        if let url = url {
            print("SharedAudioManager: Creating audio file at \(url.path)")
            print("SharedAudioManager: Input format details - sampleRate: \(inputFormat.sampleRate), channels: \(inputFormat.channelCount), commonFormat: \(inputFormat.commonFormat.rawValue), interleaved: \(inputFormat.isInterleaved)")
            print("SharedAudioManager: Input format settings: \(inputFormat.settings)")

            // Use the input format's processing format for the file
            outputFormat = inputFormat

            // Determine bit depth based on common format
            let bitDepth: Int
            let isFloat: Bool
            switch inputFormat.commonFormat {
            case .pcmFormatFloat32:
                bitDepth = 32
                isFloat = true
            case .pcmFormatFloat64:
                bitDepth = 64
                isFloat = true
            case .pcmFormatInt16:
                bitDepth = 16
                isFloat = false
            case .pcmFormatInt32:
                bitDepth = 32
                isFloat = false
            default:
                bitDepth = 32
                isFloat = true
            }

            // Build settings explicitly from the input format properties
            let fileSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: inputFormat.sampleRate,
                AVNumberOfChannelsKey: Int(inputFormat.channelCount),
                AVLinearPCMBitDepthKey: bitDepth,
                AVLinearPCMIsFloatKey: isFloat,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: !inputFormat.isInterleaved
            ]

            print("SharedAudioManager: File settings: \(fileSettings)")

            audioFile = try AVAudioFile(forWriting: url, settings: fileSettings)
            recordingURL = url
            isRecording = true
            print("SharedAudioManager: Audio file created successfully")
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

        print("SharedAudioManager: Audio engine started successfully")
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
    @discardableResult
    func stopAudioEngine() -> URL? {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        let url = recordingURL
        audioFile = nil
        recordingURL = nil
        isRecording = false
        outputFormat = nil

        return url
    }

    /// Returns the input format for transcription services to use
    var inputFormat: AVAudioFormat? {
        return audioEngine?.inputNode.outputFormat(forBus: 0)
    }
}
#endif
