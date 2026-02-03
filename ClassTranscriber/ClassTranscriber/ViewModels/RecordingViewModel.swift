import Foundation
import SwiftUI
import Combine

class RecordingViewModel: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentDuration: TimeInterval = 0
    @Published var transcribedText: String = ""
    @Published var errorMessage: String?
    @Published var permissionsGranted: Bool = false
    @Published var toastMessage: ToastMessage?

    let audioService = AudioRecordingService()
    let transcriptionService = TranscriptionService()

    private var currentAudioURL: URL?
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Bind audio service duration to our published property
        audioService.$currentDuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.currentDuration = duration
            }
            .store(in: &cancellables)

        // Bind transcription service text to our published property
        transcriptionService.$transcribedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.transcribedText = text
            }
            .store(in: &cancellables)

        // Bind transcription errors
        transcriptionService.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    self?.errorMessage = error
                }
            }
            .store(in: &cancellables)
    }

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        audioService.requestPermission { [weak self] audioGranted in
            guard audioGranted else {
                DispatchQueue.main.async {
                    self?.errorMessage = "Microphone permission denied"
                }
                completion(false)
                return
            }

            self?.transcriptionService.requestPermission { speechGranted in
                DispatchQueue.main.async {
                    if speechGranted {
                        self?.permissionsGranted = true
                        completion(true)
                    } else {
                        self?.errorMessage = "Speech recognition permission denied"
                        completion(false)
                    }
                }
            }
        }
    }

    func startRecording() {
        // Clear any previous error/state
        DispatchQueue.main.async {
            self.errorMessage = nil
            self.transcribedText = ""
        }

        guard let audioURL = audioService.startRecording() else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start recording"
            }
            return
        }

        currentAudioURL = audioURL
        transcriptionService.startTranscribing()

        DispatchQueue.main.async {
            self.isRecording = true
            self.isPaused = false
        }
    }

    func pauseRecording() {
        audioService.pauseRecording()
        transcriptionService.pauseTranscribing()
        DispatchQueue.main.async {
            self.isPaused = true
        }
    }

    func resumeRecording() {
        audioService.resumeRecording()
        transcriptionService.resumeTranscribing()
        DispatchQueue.main.async {
            self.isPaused = false
        }
    }

    func stopRecording(classModel: ClassModel, classViewModel: ClassViewModel) {
        // Capture the transcribed text before stopping
        let finalTranscript = transcribedText

        guard let result = audioService.stopRecording() else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to stop recording"
            }
            return
        }

        transcriptionService.stopTranscribing()

        let recordingDate = Date()
        let recording = RecordingModel(
            classId: classModel.id,
            date: recordingDate,
            duration: result.duration,
            audioFileName: result.url.lastPathComponent,
            transcriptText: finalTranscript,
            name: RecordingModel.generateDefaultName(className: classModel.name, date: recordingDate)
        )

        classViewModel.addRecording(recording)

        // Export PDF if class has folder configured
        if let folderURL = classModel.resolveFolder() {
            exportPDF(for: recording, className: classModel.name, to: folderURL, classViewModel: classViewModel)
        }

        reset()
    }

    func cancelRecording() {
        if let result = audioService.stopRecording() {
            try? FileManager.default.removeItem(at: result.url)
        }
        transcriptionService.stopTranscribing()
        reset()
    }

    private func exportPDF(for recording: RecordingModel, className: String, to folderURL: URL, classViewModel: ClassViewModel) {
        guard let pdfData = PDFExportService.generatePDF(
            className: className,
            date: recording.date,
            duration: recording.duration,
            transcriptText: recording.transcriptText
        ) else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to generate PDF"
            }
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let datePart = dateFormatter.string(from: recording.date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h-mma"  // 1-45PM format (using dash since colon isn't allowed in filenames)
        timeFormatter.amSymbol = "am"
        timeFormatter.pmSymbol = "pm"
        let timePart = timeFormatter.string(from: recording.date)

        let fileName = "\(className)_\(datePart)_\(timePart)"

        if PDFExportService.savePDF(data: pdfData, to: folderURL, fileName: fileName) {
            var updatedRecording = recording
            updatedRecording.pdfExported = true
            classViewModel.updateRecording(updatedRecording)

            // Show success toast
            DispatchQueue.main.async {
                self.toastMessage = ToastMessage(
                    message: "PDF saved to \(folderURL.lastPathComponent)",
                    icon: "checkmark.circle.fill",
                    type: .success
                )
            }
        } else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to save PDF to folder"
                self.toastMessage = ToastMessage(
                    message: "Failed to save PDF",
                    icon: "xmark.circle.fill",
                    type: .error
                )
            }
        }
    }

    private func reset() {
        DispatchQueue.main.async {
            self.isRecording = false
            self.isPaused = false
            self.currentDuration = 0
            self.transcribedText = ""
            self.currentAudioURL = nil
        }
    }

    var formattedDuration: String {
        let hours = Int(currentDuration) / 3600
        let minutes = (Int(currentDuration) % 3600) / 60
        let seconds = Int(currentDuration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
