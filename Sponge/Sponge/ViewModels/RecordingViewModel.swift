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
    @Published var isGeneratingNotes: Bool = false
    @Published var userNotes: String = ""
    @Published var userNotesTitle: String = ""

    // Intent Markers and Catch-Up
    @Published var intentMarkers: [IntentMarker] = []
    @Published var isCatchUpLoading: Bool = false
    @Published var lastCatchUpSummary: CatchUpSummary?

    let audioService = AudioRecordingService()
    let transcriptionService = TranscriptionService()
    private let driveService = GoogleDriveService.shared
    private let geminiService = GeminiService.shared

    private var currentAudioURL: URL?
    private var cancellables = Set<AnyCancellable>()

    @AppStorage("autoGenerateClassNotes") private var autoGenerateClassNotes = false
    @AppStorage("realtimeTranscription") private var realtimeTranscription = true
    @AppStorage("generateRecallPrompts") private var generateRecallPrompts = true

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

        // On macOS, start transcription FIRST so the buffer handler is set up
        // before SharedAudioManager starts sending audio buffers
        #if os(macOS)
        if realtimeTranscription {
            transcriptionService.startTranscribing()
        }
        #endif

        guard let audioURL = audioService.startRecording() else {
            DispatchQueue.main.async {
                self.errorMessage = self.audioService.lastError ?? "Failed to start recording"
            }
            // Stop transcription if recording failed
            #if os(macOS)
            if realtimeTranscription {
                transcriptionService.stopTranscribing()
            }
            #endif
            return
        }

        currentAudioURL = audioURL

        // On iOS, start transcription after recording (works alongside AVAudioRecorder)
        #if os(iOS)
        if realtimeTranscription {
            transcriptionService.startTranscribing()
        }
        #endif

        DispatchQueue.main.async {
            self.isRecording = true
            self.isPaused = false
        }
    }

    func pauseRecording() {
        audioService.pauseRecording()
        if realtimeTranscription {
            transcriptionService.pauseTranscribing()
        }
        DispatchQueue.main.async {
            self.isPaused = true
        }
    }

    func resumeRecording() {
        audioService.resumeRecording()
        if realtimeTranscription {
            transcriptionService.resumeTranscribing()
        }
        DispatchQueue.main.async {
            self.isPaused = false
        }
    }

    func stopRecording(classModel: ClassModel, classViewModel: ClassViewModel) {
        guard let result = audioService.stopRecording() else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to stop recording"
            }
            return
        }

        if realtimeTranscription {
            transcriptionService.stopTranscribing()
        }

        let recordingDate = Date()
        let audioURL = result.url
        let finalTranscript = transcribedText // Use live transcript directly
        // Combine title with notes if title exists
        let finalUserNotes: String
        if !userNotesTitle.isEmpty {
            finalUserNotes = "# \(userNotesTitle)\n\n\(userNotes)"
        } else {
            finalUserNotes = userNotes
        }

        // Capture intent markers and catch-up summaries
        let finalIntentMarkers = intentMarkers
        let finalCatchUpSummaries = lastCatchUpSummary.map { [$0] } ?? []

        processRecording(
            classId: classModel.id,
            date: recordingDate,
            duration: result.duration,
            audioFileName: audioURL.lastPathComponent,
            transcript: finalTranscript,
            userNotes: finalUserNotes,
            intentMarkers: finalIntentMarkers,
            catchUpSummaries: finalCatchUpSummaries,
            classModel: classModel,
            classViewModel: classViewModel
        )

        reset()
    }

    private func processRecording(
        classId: UUID,
        date: Date,
        duration: TimeInterval,
        audioFileName: String,
        transcript: String,
        userNotes: String,
        intentMarkers: [IntentMarker],
        catchUpSummaries: [CatchUpSummary],
        classModel: ClassModel,
        classViewModel: ClassViewModel
    ) {
        var recording = RecordingModel(
            classId: classId,
            date: date,
            duration: duration,
            audioFileName: audioFileName,
            transcriptText: transcript,
            userNotes: userNotes,
            name: RecordingModel.generateDefaultName(className: classModel.name, date: date),
            intentMarkers: intentMarkers,
            catchUpSummaries: catchUpSummaries
        )

        classViewModel.addRecording(recording)

        // Generate class notes and enhanced summaries if enabled
        if autoGenerateClassNotes && !transcript.isEmpty {
            Task {
                await generateEnhancedContent(for: &recording, classModel: classModel, classViewModel: classViewModel)
            }
        } else {
            // Export PDF immediately if notes generation is disabled
            exportPDF(for: recording, classModel: classModel, classViewModel: classViewModel)
        }
    }

    // MARK: - Enhanced Content Generation

    private func generateEnhancedContent(for recording: inout RecordingModel, classModel: ClassModel, classViewModel: ClassViewModel) async {
        await MainActor.run {
            self.isGeneratingNotes = true
        }

        // Capture values to avoid referencing inout parameter in concurrent code
        let transcriptText = recording.transcriptText
        let userNotesText = recording.userNotes
        let markers = recording.intentMarkers

        // Get user preferences for note style and summary length
        let noteStyleRaw = UserDefaults.standard.string(forKey: "noteStyle") ?? NoteStyle.detailed.rawValue
        let summaryLengthRaw = UserDefaults.standard.string(forKey: "summaryLength") ?? SummaryLength.comprehensive.rawValue
        let noteStyle = NoteStyle(rawValue: noteStyleRaw) ?? .detailed
        let summaryLength = SummaryLength(rawValue: summaryLengthRaw) ?? .comprehensive

        var updatedRecording = recording

        do {
            // Generate traditional class notes (for PDF compatibility)
            let classNotes = try await geminiService.generateClassNotes(
                from: transcriptText,
                userNotes: userNotesText,
                noteStyle: noteStyle,
                summaryLength: summaryLength
            )
            updatedRecording.classNotes = classNotes

            // Generate enhanced summaries with marker-focused content
            let enhancedSummary = try await geminiService.generateEnhancedSummaries(
                from: transcriptText,
                markers: markers,
                userNotes: userNotesText
            )
            updatedRecording.enhancedSummary = enhancedSummary

            // Generate recall prompts if enabled
            if generateRecallPrompts {
                let recallPrompts = try await geminiService.generateRecallPrompts(
                    from: transcriptText,
                    markers: markers
                )
                updatedRecording.recallPrompts = recallPrompts
            }

            recording = updatedRecording

            // Create a local copy for use in MainActor closure
            let finalRecording = updatedRecording

            await MainActor.run {
                classViewModel.updateRecording(finalRecording)
                self.isGeneratingNotes = false

                // Export PDF with class notes
                self.exportPDF(for: finalRecording, classModel: classModel, classViewModel: classViewModel)
            }

        } catch {
            // Create a local copy for use in MainActor closure
            let finalRecording = recording

            // On error, show message but keep original transcript and export without notes
            await MainActor.run {
                self.isGeneratingNotes = false
                self.errorMessage = error.localizedDescription

                // Still export PDF with just the transcript
                self.exportPDF(for: finalRecording, classModel: classModel, classViewModel: classViewModel)
            }
        }
    }

    func cancelRecording() {
        if let result = audioService.stopRecording() {
            try? FileManager.default.removeItem(at: result.url)
        }
        transcriptionService.stopTranscribing()

        // Clear any pending toast message when canceling
        DispatchQueue.main.async {
            self.toastMessage = nil
        }

        reset()
    }

    // MARK: - Intent Markers

    /// Adds an intent marker at the current timestamp
    func addIntentMarker(type: IntentMarkerType) {
        let snapshot = getRecentTranscriptSnapshot(wordCount: 30)
        let marker = IntentMarker(
            type: type,
            timestamp: currentDuration,
            transcriptSnapshot: snapshot
        )

        DispatchQueue.main.async {
            self.intentMarkers.append(marker)
        }

        // Haptic feedback on iOS
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }

    /// Gets the last N words from the transcript
    private func getRecentTranscriptSnapshot(wordCount: Int) -> String? {
        let words = transcribedText.split(separator: " ")
        guard !words.isEmpty else { return nil }

        let recentWords = words.suffix(wordCount)
        return recentWords.joined(separator: " ")
    }

    // MARK: - Catch-Up Summary

    /// Requests a catch-up summary for what was missed recently
    func requestCatchUpSummary() async {
        // Need at least some transcript to summarize
        guard !transcribedText.isEmpty else { return }

        await MainActor.run {
            self.isCatchUpLoading = true
        }

        // Estimate transcript coverage - assume ~150 words per minute
        // Get last ~2.5 minutes worth (roughly 375 words)
        let words = transcribedText.split(separator: " ")
        let recentWordCount = min(375, words.count)
        let contextWordCount = min(200, max(0, words.count - recentWordCount))

        let recentWords = words.suffix(recentWordCount)
        let contextWords = words.dropLast(recentWordCount).suffix(contextWordCount)

        let recentTranscript = recentWords.joined(separator: " ")
        let previousContext = contextWords.joined(separator: " ")

        // Calculate time coverage
        let requestedAt = currentDuration
        let estimatedCoverageTime = Double(recentWordCount) / 150.0 * 60.0 // seconds
        let coveringFrom = max(0, requestedAt - estimatedCoverageTime)

        do {
            let summary = try await geminiService.generateCatchUpSummary(
                recentTranscript: recentTranscript,
                previousContext: previousContext
            )

            let catchUpSummary = CatchUpSummary(
                requestedAt: requestedAt,
                coveringFrom: coveringFrom,
                summary: summary
            )

            await MainActor.run {
                self.lastCatchUpSummary = catchUpSummary
                self.isCatchUpLoading = false
            }
        } catch {
            await MainActor.run {
                self.isCatchUpLoading = false
                self.errorMessage = "Failed to generate catch-up summary: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - PDF Export

    private func exportPDF(for recording: RecordingModel, classModel: ClassModel, classViewModel: ClassViewModel) {
        // Check if any export is needed
        guard classModel.saveDestination.requiresLocalFolder || classModel.saveDestination.requiresGoogleDrive else {
            return
        }

        // Generate PDF data (with user notes and class notes if available)
        guard let pdfData = PDFExportService.generatePDF(
            className: classModel.name,
            date: recording.date,
            duration: recording.duration,
            transcriptText: recording.transcriptText,
            userNotes: recording.userNotes,
            classNotes: recording.classNotes
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
            self.userNotes = ""
            self.userNotesTitle = ""
            self.currentAudioURL = nil
            self.errorMessage = nil
            self.intentMarkers = []
            self.lastCatchUpSummary = nil
            self.isCatchUpLoading = false
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
