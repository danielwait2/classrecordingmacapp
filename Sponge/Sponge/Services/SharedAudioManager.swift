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
    private var audioConverter: AVAudioConverter?
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

        // If recording, create the audio file with a standard format
        if let url = url {
            print("SharedAudioManager: Creating audio file at \(url.path)")

            // Create a standard output format: 44.1kHz mono Float32
            // This format works reliably with AVAudioFile and AVAudioConverter
            guard let standardFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false) else {
                throw NSError(domain: "SharedAudioManager", code: -3,
                             userInfo: [NSLocalizedDescriptionKey: "Failed to create standard audio format"])
            }

            outputFormat = standardFormat

            // Create converter if input format differs from output format
            if inputFormat.sampleRate != standardFormat.sampleRate || inputFormat.channelCount != standardFormat.channelCount || inputFormat.commonFormat != standardFormat.commonFormat {
                audioConverter = AVAudioConverter(from: inputFormat, to: standardFormat)
                print("SharedAudioManager: Created audio converter from \(inputFormat.sampleRate)Hz/\(inputFormat.channelCount)ch to \(standardFormat.sampleRate)Hz/\(standardFormat.channelCount)ch")
            }

            // Use explicit CAF settings that match Float32 format
            let cafSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: true
            ]

            audioFile = try AVAudioFile(forWriting: url, settings: cafSettings)
            recordingURL = url
            isRecording = true
            print("SharedAudioManager: Audio file created successfully")
        }

        // Capture input sample rate for use in tap closure
        let inputSampleRate = inputFormat.sampleRate

        // Install tap that handles both recording and transcription
        inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            // Write to file if recording
            if self.isRecording, let audioFile = self.audioFile {
                do {
                    // Convert buffer if necessary
                    if let converter = self.audioConverter, let outFormat = self.outputFormat {
                        // Calculate output frame count based on sample rate ratio
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
        audioConverter = nil
        outputFormat = nil

        return url
    }

    /// Returns the input format for transcription services to use
    var inputFormat: AVAudioFormat? {
        return audioEngine?.inputNode.outputFormat(forBus: 0)
    }
}
#endif
