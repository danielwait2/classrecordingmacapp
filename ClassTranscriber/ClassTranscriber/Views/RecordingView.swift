import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @ObservedObject var recordingViewModel: RecordingViewModel
    @State private var showingPermissionAlert = false
    @State private var isConfirmingStop = false
    @State private var showFullTranscript = false
    @State private var ringAnimation = false

    var body: some View {
        VStack(spacing: 20) {
            // Duration display
            Text(recordingViewModel.formattedDuration)
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundColor(recordingViewModel.isRecording ? .red : .primary)

            // Live transcript preview - only shows while recording
            if recordingViewModel.isRecording {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        // Pulsing indicator when actively recording
                        if recordingViewModel.isRecording && !recordingViewModel.isPaused {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .modifier(PulsingModifier())
                        } else {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 8, height: 8)
                        }

                        Text(recordingViewModel.isRecording && !recordingViewModel.isPaused ? "Live Transcription" : "Transcription")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(wordCount) words")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Toggle to show full transcript
                        if wordCount > 50 {
                            Button {
                                showFullTranscript.toggle()
                            } label: {
                                Image(systemName: showFullTranscript ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondarySystemBackground.opacity(0.5))

                    Divider()

                    // Transcript content
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                if recordingViewModel.transcribedText.isEmpty {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Listening for speech...")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 20)
                                } else {
                                    // Show either last 50 words or full transcript
                                    Text(displayText)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .id("transcriptEnd")
                                }
                            }
                        }
                        .onChange(of: recordingViewModel.transcribedText) { _, _ in
                            if !showFullTranscript {
                                withAnimation(.easeOut(duration: 0.1)) {
                                    proxy.scrollTo("transcriptEnd", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                .frame(height: showFullTranscript ? 300 : 150)
                .background(Color.secondarySystemBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(recordingViewModel.isRecording && !recordingViewModel.isPaused ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
                )
                .animation(.easeInOut(duration: 0.2), value: showFullTranscript)
            }

            // Error message
            if let error = recordingViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            // Recording controls
            HStack(spacing: 30) {
                if recordingViewModel.isRecording {
                    if isConfirmingStop {
                        // Confirmation state - show confirm and back buttons
                        Button {
                            // Go back to normal recording controls
                            isConfirmingStop = false
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.gray)
                                Text("Back")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            // Confirm stop - save recording
                            if let selectedClass = classViewModel.selectedClass {
                                recordingViewModel.stopRecording(classModel: selectedClass, classViewModel: classViewModel)
                            }
                            isConfirmingStop = false
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.green)
                                Text("Save")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            // Discard recording
                            recordingViewModel.cancelRecording()
                            isConfirmingStop = false
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.red)
                                Text("Discard")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Normal recording state
                        // Pause/Resume button
                        Button {
                            if recordingViewModel.isPaused {
                                recordingViewModel.resumeRecording()
                            } else {
                                recordingViewModel.pauseRecording()
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: recordingViewModel.isPaused ? "play.circle.fill" : "pause.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.orange)
                                Text(recordingViewModel.isPaused ? "Resume" : "Pause")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        // Stop button - enters confirmation state
                        Button {
                            isConfirmingStop = true
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.red)
                                Text("Stop")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // Enhanced Record button when not recording
                    Button {
                        startRecordingWithPermissionCheck()
                    } label: {
                        VStack(spacing: 12) {
                            ZStack {
                                // Outer animated ring
                                Circle()
                                    .stroke(Color.red.opacity(0.2), lineWidth: 3)
                                    .frame(width: 110, height: 110)

                                // Pulsing ring animation
                                Circle()
                                    .stroke(Color.red.opacity(ringAnimation ? 0.0 : 0.4), lineWidth: 3)
                                    .frame(width: 110, height: 110)
                                    .scaleEffect(ringAnimation ? 1.3 : 1.0)

                                // Middle ring
                                Circle()
                                    .stroke(Color.red.opacity(0.5), lineWidth: 4)
                                    .frame(width: 95, height: 95)

                                // Inner filled circle
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.red, Color.red.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)

                                // Microphone icon
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.white)
                            }

                            // Class name below button - tappable to change class
                            if let selectedClass = classViewModel.selectedClass {
                                VStack(spacing: 2) {
                                    Text("Tap to Record")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Menu {
                                        ForEach(classViewModel.classes) { classModel in
                                            Button {
                                                classViewModel.selectedClass = classModel
                                            } label: {
                                                HStack {
                                                    Text(classModel.name)
                                                    if classModel.id == selectedClass.id {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(selectedClass.name)
                                                .font(.subheadline.bold())
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.primary)
                                    }
                                    .menuStyle(.borderlessButton)
                                }
                            } else {
                                Text("Select a class to record")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(classViewModel.selectedClass == nil)
                    .opacity(classViewModel.selectedClass == nil ? 0.5 : 1.0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                            ringAnimation = true
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isConfirmingStop)
            .animation(.easeInOut(duration: 0.3), value: recordingViewModel.isRecording)

            // Status text
            if recordingViewModel.isRecording {
                if isConfirmingStop {
                    Text("Save recording or discard?")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text(recordingViewModel.isPaused ? "Paused" : "Recording...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if classViewModel.selectedClass == nil {
                Text("Add a class to start recording")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if classViewModel.selectedClass?.folderBookmark == nil {
                Text("Warning: No folder set - PDF will not be saved")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .alert("Permissions Required", isPresented: $showingPermissionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enable microphone and speech recognition permissions in System Settings.")
        }
    }

    // MARK: - Computed Properties

    private var wordCount: Int {
        recordingViewModel.transcribedText.split(separator: " ").count
    }

    private var displayText: String {
        if showFullTranscript {
            return recordingViewModel.transcribedText
        }

        let words = recordingViewModel.transcribedText.split(separator: " ")
        if words.count <= 50 {
            return recordingViewModel.transcribedText
        }

        // Show last 50 words with ellipsis prefix
        let lastWords = words.suffix(50)
        return "... " + lastWords.joined(separator: " ")
    }

    // MARK: - Methods

    private func startRecordingWithPermissionCheck() {
        if recordingViewModel.permissionsGranted {
            recordingViewModel.startRecording()
        } else {
            recordingViewModel.requestPermissions { granted in
                if granted {
                    recordingViewModel.startRecording()
                } else {
                    showingPermissionAlert = true
                }
            }
        }
    }
}

// MARK: - Pulsing Animation Modifier

struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Color Extension

#if os(macOS)
extension Color {
    static var secondarySystemBackground: Color {
        Color(NSColor.controlBackgroundColor)
    }
}
#else
extension Color {
    static var secondarySystemBackground: Color {
        Color(UIColor.secondarySystemBackground)
    }
}
#endif

#Preview {
    RecordingView(recordingViewModel: RecordingViewModel())
        .environmentObject(ClassViewModel())
}
