import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @ObservedObject var recordingViewModel: RecordingViewModel
    @State private var showingPermissionAlert = false
    @State private var isConfirmingStop = false
    @State private var showFullTranscript = false
    @State private var ringAnimation = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            // Recording controls area
            if recordingViewModel.isRecording {
                recordingActiveView
            } else {
                recordingIdleView
            }

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 24)
        .alert("Permissions Required", isPresented: $showingPermissionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enable microphone and speech recognition permissions in System Settings.")
        }
    }

    // MARK: - Recording Active View

    private var recordingActiveView: some View {
        VStack(spacing: 20) {
            // Duration display with recording indicator
            HStack(spacing: 12) {
                // Pulsing recording dot
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .modifier(PulsingModifier(isActive: !recordingViewModel.isPaused))

                Text(recordingViewModel.formattedDuration)
                    .font(.system(size: 44, weight: .light, design: .monospaced))
                    .foregroundColor(.primary)
            }

            // Live transcript preview
            transcriptPreview

            // Control buttons
            recordingControls
                .padding(.top, 8)

            // Status text
            statusText
        }
    }

    // MARK: - Recording Idle View

    private var recordingIdleView: some View {
        VStack(spacing: 20) {
            // Duration (shows 00:00:00 when idle)
            Text(recordingViewModel.formattedDuration)
                .font(.system(size: 44, weight: .light, design: .monospaced))
                .foregroundColor(.secondary)

            // Record button
            recordButton

            // Status/warning text
            statusText
        }
    }

    // MARK: - Transcript Preview

    private var transcriptPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Circle()
                    .fill(recordingViewModel.isPaused ? Color.gray : Color.red)
                    .frame(width: 8, height: 8)
                    .modifier(PulsingModifier(isActive: !recordingViewModel.isPaused))

                Text(recordingViewModel.isPaused ? "Paused" : "Live Transcription")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(wordCount) words")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)

                if wordCount > 50 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showFullTranscript.toggle()
                        }
                    } label: {
                        Image(systemName: showFullTranscript ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.05))

            Divider()

            // Transcript content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if recordingViewModel.transcribedText.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Listening...")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                        } else {
                            Text(displayText)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
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
        .frame(height: showFullTranscript ? 280 : 140)
        .background(Color.secondaryBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(recordingViewModel.isPaused ? Color.clear : Color.red.opacity(0.3), lineWidth: 1.5)
        )
    }

    // MARK: - Recording Controls

    private var recordingControls: some View {
        HStack(spacing: 40) {
            if isConfirmingStop {
                // Back button
                ControlButton(
                    icon: "arrow.uturn.backward",
                    label: "Back",
                    color: .secondary,
                    size: 48
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isConfirmingStop = false
                    }
                }

                // Save button
                ControlButton(
                    icon: "checkmark",
                    label: "Save",
                    color: .green,
                    size: 56,
                    isPrimary: true
                ) {
                    if let selectedClass = classViewModel.selectedClass {
                        recordingViewModel.stopRecording(classModel: selectedClass, classViewModel: classViewModel)
                    }
                    isConfirmingStop = false
                }

                // Discard button
                ControlButton(
                    icon: "trash",
                    label: "Discard",
                    color: .red,
                    size: 48
                ) {
                    recordingViewModel.cancelRecording()
                    isConfirmingStop = false
                }
            } else {
                // Pause/Resume button
                ControlButton(
                    icon: recordingViewModel.isPaused ? "play.fill" : "pause.fill",
                    label: recordingViewModel.isPaused ? "Resume" : "Pause",
                    color: .orange,
                    size: 52
                ) {
                    if recordingViewModel.isPaused {
                        recordingViewModel.resumeRecording()
                    } else {
                        recordingViewModel.pauseRecording()
                    }
                }

                // Stop button
                ControlButton(
                    icon: "stop.fill",
                    label: "Stop",
                    color: .red,
                    size: 52
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isConfirmingStop = true
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isConfirmingStop)
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button {
            startRecordingWithPermissionCheck()
        } label: {
            VStack(spacing: 16) {
                ZStack {
                    // Outer pulsing ring
                    Circle()
                        .stroke(Color.red.opacity(ringAnimation ? 0.0 : 0.3), lineWidth: 2)
                        .frame(width: 100, height: 100)
                        .scaleEffect(ringAnimation ? 1.4 : 1.0)

                    // Middle ring
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 3)
                        .frame(width: 100, height: 100)

                    // Inner filled circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)

                    // Microphone icon
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }

                // Class selector
                if let selectedClass = classViewModel.selectedClass {
                    classSelector(for: selectedClass)
                } else {
                    Text("Select a class to record")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(classViewModel.selectedClass == nil)
        .opacity(classViewModel.selectedClass == nil ? 0.5 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                ringAnimation = true
            }
        }
    }

    private func classSelector(for selectedClass: ClassModel) -> some View {
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
            HStack(spacing: 6) {
                Text(selectedClass.name)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Status Text

    @ViewBuilder
    private var statusText: some View {
        if recordingViewModel.isRecording {
            if isConfirmingStop {
                Label("Save or discard this recording?", systemImage: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            } else {
                Text(recordingViewModel.isPaused ? "Recording paused" : "Recording in progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        } else if let error = recordingViewModel.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundColor(.red)
        } else if classViewModel.selectedClass == nil {
            Label("Add a class to start recording", systemImage: "plus.circle")
                .font(.subheadline)
                .foregroundColor(.orange)
        } else if let selectedClass = classViewModel.selectedClass, !selectedClass.isConfigurationValid {
            Label("Configure save location in Settings", systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundColor(.orange)
        } else {
            Text("Tap to start recording")
                .font(.subheadline)
                .foregroundColor(.secondary)
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

        let lastWords = words.suffix(50)
        return "… " + lastWords.joined(separator: " ")
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

// MARK: - Control Button

struct ControlButton: View {
    let icon: String
    let label: String
    let color: Color
    var size: CGFloat = 52
    var isPrimary: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isPrimary ? color : color.opacity(0.15))
                        .frame(width: size, height: size)

                    Image(systemName: icon)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundColor(isPrimary ? .white : color)
                }

                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pulsing Animation Modifier

struct PulsingModifier: ViewModifier {
    var isActive: Bool = true
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isActive && isPulsing ? 0.4 : 1.0)
            .onAppear {
                if isActive {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                } else {
                    isPulsing = false
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
