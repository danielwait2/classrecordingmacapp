import Foundation
import AVFoundation

enum RecordingState {
    case idle
    case recording
    case paused
}

class AudioRecordingService: NSObject, ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var currentDuration: TimeInterval = 0
    @Published var lastError: String?

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var pausedDuration: TimeInterval = 0
    private var recordingStartTime: Date?

    private var currentFileURL: URL?

    override init() {
        super.init()
        setupRecordingsDirectory()
    }

    private func setupRecordingsDirectory() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsPath = documentsPath.appendingPathComponent("Recordings")

        if !FileManager.default.fileExists(atPath: recordingsPath.path) {
            try? FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        }
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        #if os(macOS)
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
        #else
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
        #endif
    }

    func startRecording() -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsPath = documentsPath.appendingPathComponent("Recordings")

        #if os(macOS)
        // On macOS, use .wav format which is widely compatible
        let fileName = "recording_\(Date().timeIntervalSince1970).wav"
        let fileURL = recordingsPath.appendingPathComponent(fileName)

        print("AudioRecordingService: Attempting to start recording to \(fileURL.path)")

        // Use SharedAudioManager to avoid conflicts with transcription's AVAudioEngine
        do {
            try SharedAudioManager.shared.startAudioEngine(recordingToURL: fileURL)

            currentFileURL = fileURL
            recordingState = .recording
            recordingStartTime = Date()
            pausedDuration = 0
            startTimer()

            print("AudioRecordingService: Recording started successfully")
            return fileURL
        } catch {
            let errorMessage = "Failed to start recording: \(error.localizedDescription)"
            print("AudioRecordingService: \(errorMessage)")
            lastError = errorMessage
            return nil
        }
        #else
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let fileURL = recordingsPath.appendingPathComponent(fileName)
        // iOS uses AVAudioRecorder which works alongside AVAudioEngine
        // High-quality settings matching Apple Voice Memos exactly
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48000.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
            AVEncoderBitRateKey: 256000,
            AVLinearPCMBitDepthKey: 16
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)

            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            currentFileURL = fileURL
            recordingState = .recording
            recordingStartTime = Date()
            pausedDuration = 0
            startTimer()

            return fileURL
        } catch {
            print("Failed to start recording: \(error)")
            return nil
        }
        #endif
    }

    func pauseRecording() {
        guard recordingState == .recording else { return }

        #if os(macOS)
        SharedAudioManager.shared.pauseAudioEngine()
        #else
        audioRecorder?.pause()
        #endif

        recordingState = .paused
        stopTimer()

        if recordingStartTime != nil {
            pausedDuration = currentDuration
        }
    }

    func resumeRecording() {
        guard recordingState == .paused else { return }

        #if os(macOS)
        try? SharedAudioManager.shared.resumeAudioEngine()
        #else
        audioRecorder?.record()
        #endif

        recordingState = .recording
        recordingStartTime = Date()
        startTimer()
    }

    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        #if os(macOS)
        guard let fileURL = SharedAudioManager.shared.stopAudioEngine() ?? currentFileURL else { return nil }

        stopTimer()
        let finalDuration = currentDuration

        recordingState = .idle
        currentDuration = 0
        pausedDuration = 0
        recordingStartTime = nil
        currentFileURL = nil

        return (fileURL, finalDuration)
        #else
        guard let recorder = audioRecorder, let fileURL = currentFileURL else { return nil }

        recorder.stop()
        stopTimer()

        let finalDuration = currentDuration

        try? AVAudioSession.sharedInstance().setActive(false)

        recordingState = .idle
        currentDuration = 0
        pausedDuration = 0
        recordingStartTime = nil

        audioRecorder = nil
        currentFileURL = nil

        return (fileURL, finalDuration)
        #endif
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            self.currentDuration = self.pausedDuration + Date().timeIntervalSince(startTime)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension AudioRecordingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording finished unsuccessfully")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording encode error: \(error)")
        }
    }
}
