import SwiftUI

struct RecordingsListView: View {
    @EnvironmentObject var classViewModel: ClassViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Recordings")
                    .font(.headline)

                Spacer()

                if let selectedClass = classViewModel.selectedClass {
                    Text(selectedClass.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.05))

            // Content
            if classViewModel.selectedClass == nil {
                emptyStateView(
                    icon: "folder",
                    title: "No Class Selected",
                    message: "Select a class to view its recordings"
                )
            } else if classViewModel.recordingsForSelectedClass().isEmpty {
                emptyStateView(
                    icon: "waveform",
                    title: "No Recordings",
                    message: "Start recording to create your first transcript"
                )
            } else {
                List {
                    ForEach(classViewModel.recordingsForSelectedClass()) { recording in
                        RecordingRowView(recording: recording, classViewModel: classViewModel)
                    }
                    .onDelete(perform: deleteRecordings)
                }
                .listStyle(.plain)
            }
        }
    }

    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func deleteRecordings(at offsets: IndexSet) {
        let recordings = classViewModel.recordingsForSelectedClass()
        for index in offsets {
            classViewModel.deleteRecording(recordings[index])
        }
    }
}

// MARK: - Recording Row View

struct RecordingRowView: View {
    let recording: RecordingModel
    @ObservedObject var classViewModel: ClassViewModel
    @State private var showingDetail = false
    @State private var showingEditSheet = false

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 40, height: 40)

                    Image(systemName: "doc.text")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(recording.name)
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        Text(recording.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }

                    HStack {
                        Text(recording.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if recording.pdfExported {
                            Label("Exported", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }

                        Spacer()

                        Text("\(recording.transcriptText.split(separator: " ").count) words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                showingEditSheet = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                classViewModel.deleteRecording(recording)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                classViewModel.deleteRecording(recording)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                showingEditSheet = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .sheet(isPresented: $showingDetail) {
            TranscriptDetailView(recording: recording, classViewModel: classViewModel)
        }
        .sheet(isPresented: $showingEditSheet) {
            RecordingEditorView(recording: recording, classViewModel: classViewModel)
        }
    }
}

// MARK: - Transcript Detail View

struct TranscriptDetailView: View {
    let recording: RecordingModel
    @ObservedObject var classViewModel: ClassViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Metadata card
                    VStack(spacing: 12) {
                        MetadataRow(label: "Date", value: recording.formattedDate)
                        Divider()
                        MetadataRow(label: "Duration", value: recording.formattedDuration)
                        Divider()
                        MetadataRow(label: "Words", value: "\(recording.transcriptText.split(separator: " ").count)")

                        if recording.pdfExported {
                            Divider()
                            HStack {
                                Text("Status")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Label("PDF Exported", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(16)
                    .background(Color.secondaryBackground)
                    .cornerRadius(12)

                    // Transcript
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transcript")
                            .font(.headline)

                        Text(recording.transcriptText.isEmpty ? "No transcript available" : recording.transcriptText)
                            .font(.body)
                            .foregroundColor(recording.transcriptText.isEmpty ? .secondary : .primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            .background(Color.primaryBackground)
            .navigationTitle(recording.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                RecordingEditorView(recording: recording, classViewModel: classViewModel)
            }
        }
        #if os(macOS)
        .frame(minWidth: 550, minHeight: 450)
        #endif
    }
}

// MARK: - Metadata Row

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .font(.subheadline)
    }
}

// MARK: - Recording Editor View

struct RecordingEditorView: View {
    let recording: RecordingModel
    @ObservedObject var classViewModel: ClassViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Recording Name", text: $name)
                        .font(.body)
                } header: {
                    Text("Name")
                }

                Section {
                    MetadataRow(label: "Date", value: recording.formattedDate)
                    MetadataRow(label: "Duration", value: recording.formattedDuration)
                    MetadataRow(label: "Words", value: "\(recording.transcriptText.split(separator: " ").count)")

                    HStack {
                        Text("PDF Exported")
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: recording.pdfExported ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(recording.pdfExported ? .green : .secondary)
                    }
                    .font(.subheadline)
                } header: {
                    Text("Details")
                }

                Section {
                    Text(recording.transcriptText.isEmpty ? "No transcript available" : String(recording.transcriptText.prefix(300)) + (recording.transcriptText.count > 300 ? "…" : ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(6)
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("Rename Recording")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                name = recording.name
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 350)
        #endif
    }

    private func saveChanges() {
        var updatedRecording = recording
        updatedRecording.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        classViewModel.updateRecording(updatedRecording)
        dismiss()
    }
}

#Preview {
    RecordingsListView()
        .environmentObject(ClassViewModel())
}
