import SwiftUI

struct RecordingsListView: View {
    @EnvironmentObject var classViewModel: ClassViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recordings")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)

            if classViewModel.selectedClass == nil {
                emptyStateView(message: "Select a class to view recordings")
            } else if classViewModel.recordingsForSelectedClass().isEmpty {
                emptyStateView(message: "No recordings yet")
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

    private func emptyStateView(message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deleteRecordings(at offsets: IndexSet) {
        let recordings = classViewModel.recordingsForSelectedClass()
        for index in offsets {
            classViewModel.deleteRecording(recordings[index])
        }
    }
}

struct RecordingRowView: View {
    let recording: RecordingModel
    @ObservedObject var classViewModel: ClassViewModel
    @State private var showingDetail = false
    @State private var showingEditSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(recording.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(recording.formattedDuration)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if recording.pdfExported {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }

            Text(recording.transcriptText.prefix(100) + (recording.transcriptText.count > 100 ? "..." : ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .contextMenu {
            Button {
                showingEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }

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
                Label("Edit", systemImage: "pencil")
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

struct TranscriptDetailView: View {
    let recording: RecordingModel
    @ObservedObject var classViewModel: ClassViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Date:")
                                .fontWeight(.semibold)
                            Text(recording.formattedDate)
                        }

                        HStack {
                            Text("Duration:")
                                .fontWeight(.semibold)
                            Text(recording.formattedDuration)
                        }

                        if recording.pdfExported {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("PDF exported")
                            }
                        }
                    }
                    .font(.subheadline)

                    Divider()

                    // Transcript
                    Text(recording.transcriptText.isEmpty ? "No transcript available" : recording.transcriptText)
                        .font(.body)
                        .textSelection(.enabled)
                }
                .padding()
            }
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
        .frame(minWidth: 500, minHeight: 400)
        #endif
    }
}

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
                } header: {
                    Text("Name")
                }

                Section {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(recording.formattedDate)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(recording.formattedDuration)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("PDF Exported")
                        Spacer()
                        Image(systemName: recording.pdfExported ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(recording.pdfExported ? .green : .secondary)
                    }
                } header: {
                    Text("Details")
                }

                Section {
                    Text(recording.transcriptText.isEmpty ? "No transcript available" : String(recording.transcriptText.prefix(500)) + (recording.transcriptText.count > 500 ? "..." : ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Transcript Preview")
                }
            }
            .navigationTitle("Edit Recording")
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
