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
                        RecordingRowView(recording: recording)
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
    @State private var showingTranscript = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(recording.formattedDate)
                    .font(.headline)

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
            showingTranscript = true
        }
        .sheet(isPresented: $showingTranscript) {
            TranscriptDetailView(recording: recording)
        }
    }
}

struct TranscriptDetailView: View {
    let recording: RecordingModel
    @Environment(\.dismiss) private var dismiss

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
            .navigationTitle("Transcript")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 400)
        #endif
    }
}

#Preview {
    RecordingsListView()
        .environmentObject(ClassViewModel())
}
