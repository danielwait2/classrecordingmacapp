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

/// Singleton that manages shared audio engine access on macOS
/// This prevents conflicts when both recording and transcription need the microphone
class SharedAudioManager {
    static let shared = SharedAudioManager()

    private(set) var audioEngine: AVAudioEngine?

    // Thread-safe state protected by audioStateQueue (accessed from audio thread via installTap)
    private let audioStateQueue = DispatchQueue(label: "com.sponge.sharedaudio.state")
    private var _audioFile: AVAudioFile?
    private var _isRecording = false
    private var _outputFormat: AVAudioFormat?

    private var audioFile: AVAudioFile? {
        get { audioStateQueue.sync { _audioFile } }
        set { audioStateQueue.sync { _audioFile = newValue } }
    }
    private var isRecording: Bool {
        get { audioStateQueue.sync { _isRecording } }
        set { audioStateQueue.sync { _isRecording = newValue } }
    }
    private var outputFormat: AVAudioFormat? {
        get { audioStateQueue.sync { _outputFormat } }
        set { audioStateQueue.sync { _outputFormat = newValue } }
    }

    private var recordingURL: URL?
    private var audioConverter: AVAudioConverter?

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

            // Use M4A/AAC format which works better with sandboxed apps
            // This avoids the HAL proxy issues with PCM recording
            let fileSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey: 128000
            ]

            print("SharedAudioManager: File settings: \(fileSettings)")

            // Create a processing format for writing - must be PCM for the tap
            guard let processingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false) else {
                throw NSError(domain: "SharedAudioManager", code: -3,
                             userInfo: [NSLocalizedDescriptionKey: "Failed to create processing format"])
            }

            outputFormat = processingFormat

            // Create converter from input format to processing format
            if inputFormat.sampleRate != processingFormat.sampleRate || inputFormat.channelCount != processingFormat.channelCount {
                audioConverter = AVAudioConverter(from: inputFormat, to: processingFormat)
                print("SharedAudioManager: Created audio converter")
            }

            audioFile = try AVAudioFile(forWriting: url, settings: fileSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
            recordingURL = url
            isRecording = true
            print("SharedAudioManager: Audio file created successfully")
        }

        // Capture values for closure
        let inputSampleRate = inputFormat.sampleRate

        // Install tap that handles both recording and transcription
        inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            // Snapshot thread-safe state once per callback
            let (recording, file, outFormat): (Bool, AVAudioFile?, AVAudioFormat?) = self.audioStateQueue.sync {
                (self._isRecording, self._audioFile, self._outputFormat)
            }

            // Write to file if recording
            if recording, let audioFile = file, let outFormat = outFormat {
                do {
                    // Convert buffer if necessary
                    if let converter = self.audioConverter {
                        let ratio = outFormat.sampleRate / inputSampleRate
                        let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
                        guard frameCount > 0,
                              let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: frameCount) else { return }

                        var error: NSError?
                        var hasData = true
                        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                            if hasData {
                                hasData = false
                                outStatus.pointee = .haveData
                                return buffer
                            } else {
                                outStatus.pointee = .noDataNow
                                return nil
                            }
                        }

                        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

                        if let error = error {
                            print("SharedAudioManager: Conversion error: \(error)")
                        } else if convertedBuffer.frameLength > 0 {
                            try audioFile.write(from: convertedBuffer)
                        }
                    } else {
                        try audioFile.write(from: buffer)
                    }
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
        audioConverter = nil

        return url
    }

    /// Returns the input format for transcription services to use
    var inputFormat: AVAudioFormat? {
        return audioEngine?.inputNode.outputFormat(forBus: 0)
    }
}
