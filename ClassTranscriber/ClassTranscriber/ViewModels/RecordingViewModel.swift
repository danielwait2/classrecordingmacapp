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
    @Published var isExporting: Bool = false

    let audioService = AudioRecordingService()
    let transcriptionService = TranscriptionService()
    private let driveService = GoogleDriveService.shared

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

        // Export PDF based on class configuration
        exportPDF(for: recording, classModel: classModel, classViewModel: classViewModel)

        reset()
    }

    func cancelRecording() {
        if let result = audioService.stopRecording() {
            try? FileManager.default.removeItem(at: result.url)
        }
        transcriptionService.stopTranscribing()
        reset()
    }

    // MARK: - PDF Export

    private func exportPDF(for recording: RecordingModel, classModel: ClassModel, classViewModel: ClassViewModel) {
        // Check if any export is needed
        guard classModel.saveDestination.requiresLocalFolder || classModel.saveDestination.requiresGoogleDrive else {
            return
        }

        // Generate PDF data
        guard let pdfData = PDFExportService.generatePDF(
            className: classModel.name,
            date: recording.date,
            duration: recording.duration,
            transcriptText: recording.transcriptText
        ) else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to generate PDF"
            }
            return
        }

        let fileName = generateFileName(className: classModel.name, date: recording.date)

        DispatchQueue.main.async {
            self.isExporting = true
        }

        // Create a task group to handle exports
        Task {
            // Track export results
            var localSuccess = false
            var driveSuccess = false

            // Export to local folder if configured
            if classModel.saveDestination.requiresLocalFolder {
                if let folderURL = classModel.resolveFolder() {
                    localSuccess = PDFExportService.savePDF(data: pdfData, to: folderURL, fileName: fileName)
                }
            }

            // Export to Google Drive if configured
            if classModel.saveDestination.requiresGoogleDrive {
                if let driveFolder = classModel.googleDriveFolder {
                    do {
                        _ = try await driveService.uploadPDF(
                            data: pdfData,
                            fileName: fileName,
                            toFolderId: driveFolder.folderId
                        )
                        driveSuccess = true
                    } catch {
                        print("Drive upload failed: \(error)")
                    }
                }
            }

            // Capture final values for main thread
            let finalLocalSuccess = localSuccess
            let finalDriveSuccess = driveSuccess

            // Update recording and show toast on main thread
            await MainActor.run {
                self.isExporting = false

                // Update recording with export status
                var updatedRecording = recording
                updatedRecording.pdfExported = finalLocalSuccess || finalDriveSuccess
                classViewModel.updateRecording(updatedRecording)

                // Show appropriate toast
                let message = self.createExportMessage(
                    saveDestination: classModel.saveDestination,
                    localSuccess: finalLocalSuccess,
                    driveSuccess: finalDriveSuccess,
                    localFolderName: classModel.resolveFolder()?.lastPathComponent,
                    driveFolderName: classModel.googleDriveFolder?.folderName
                )

                let overallSuccess = self.isExportSuccessful(
                    saveDestination: classModel.saveDestination,
                    localSuccess: finalLocalSuccess,
                    driveSuccess: finalDriveSuccess
                )

                self.toastMessage = ToastMessage(
                    message: message,
                    icon: overallSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    type: overallSuccess ? .success : .error
                )
            }
        }
    }

    private func generateFileName(className: String, date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let datePart = dateFormatter.string(from: date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h-mma"  // 1-45PM format (using dash since colon isn't allowed in filenames)
        timeFormatter.amSymbol = "am"
        timeFormatter.pmSymbol = "pm"
        let timePart = timeFormatter.string(from: date)

        return "\(className)_\(datePart)_\(timePart)"
    }

    private func createExportMessage(
        saveDestination: SaveDestination,
        localSuccess: Bool,
        driveSuccess: Bool,
        localFolderName: String?,
        driveFolderName: String?
    ) -> String {
        switch saveDestination {
        case .localOnly:
            if localSuccess {
                return "PDF saved to \(localFolderName ?? "folder")"
            } else {
                return "Failed to save PDF locally"
            }

        case .googleDriveOnly:
            if driveSuccess {
                return "PDF uploaded to \(driveFolderName ?? "Google Drive")"
            } else {
                return "Failed to upload PDF to Drive"
            }

        case .both:
            switch (localSuccess, driveSuccess) {
            case (true, true):
                return "PDF saved locally and uploaded to Drive"
            case (true, false):
                return "PDF saved locally (Drive upload failed)"
            case (false, true):
                return "PDF uploaded to Drive (local save failed)"
            case (false, false):
                return "Failed to save PDF"
            }
        }
    }

    private func isExportSuccessful(
        saveDestination: SaveDestination,
        localSuccess: Bool,
        driveSuccess: Bool
    ) -> Bool {
        switch saveDestination {
        case .localOnly:
            return localSuccess
        case .googleDriveOnly:
            return driveSuccess
        case .both:
            // Success if at least one destination worked
            return localSuccess || driveSuccess
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
