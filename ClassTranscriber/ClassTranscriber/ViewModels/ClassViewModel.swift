import Foundation
import SwiftUI

class ClassViewModel: ObservableObject {
    @Published var classes: [ClassModel] = []
    @Published var recordings: [RecordingModel] = []
    @Published var selectedClass: ClassModel?

    private let classesKey = "savedClasses"
    private let recordingsKey = "savedRecordings"

    init() {
        loadClasses()
        loadRecordings()
    }

    // MARK: - Class Management

    func addClass(
        name: String,
        folderURL: URL?,
        googleDriveFolder: GoogleDriveFolderInfo? = nil,
        saveDestination: SaveDestination = .localOnly
    ) {
        var bookmark: Data?
        if let url = folderURL {
            bookmark = ClassModel.createBookmark(for: url)
        }

        let newClass = ClassModel(
            name: name,
            folderBookmark: bookmark,
            googleDriveFolder: googleDriveFolder,
            saveDestination: saveDestination
        )
        classes.append(newClass)
        saveClasses()

        if selectedClass == nil {
            selectedClass = newClass
        }
    }

    func updateClass(
        _ classModel: ClassModel,
        name: String,
        folderURL: URL?,
        googleDriveFolder: GoogleDriveFolderInfo? = nil,
        saveDestination: SaveDestination? = nil
    ) {
        guard let index = classes.firstIndex(where: { $0.id == classModel.id }) else { return }

        var bookmark: Data?
        if let url = folderURL {
            bookmark = ClassModel.createBookmark(for: url)
        }

        classes[index].name = name
        classes[index].folderBookmark = bookmark
        classes[index].googleDriveFolder = googleDriveFolder

        if let destination = saveDestination {
            classes[index].saveDestination = destination
        }

        saveClasses()

        if selectedClass?.id == classModel.id {
            selectedClass = classes[index]
        }
    }

    func deleteClass(_ classModel: ClassModel) {
        classes.removeAll { $0.id == classModel.id }
        recordings.removeAll { $0.classId == classModel.id }

        saveClasses()
        saveRecordings()

        if selectedClass?.id == classModel.id {
            selectedClass = classes.first
        }
    }

    // MARK: - Recording Management

    func addRecording(_ recording: RecordingModel) {
        recordings.append(recording)
        saveRecordings()
    }

    func updateRecording(_ recording: RecordingModel) {
        guard let index = recordings.firstIndex(where: { $0.id == recording.id }) else { return }
        recordings[index] = recording
        saveRecordings()
    }

    func deleteRecording(_ recording: RecordingModel) {
        // Delete audio file
        if let audioURL = recording.audioFileURL() {
            try? FileManager.default.removeItem(at: audioURL)
        }

        recordings.removeAll { $0.id == recording.id }
        saveRecordings()
    }

    func recordingsForSelectedClass() -> [RecordingModel] {
        guard let selectedClass = selectedClass else { return [] }
        return recordings.filter { $0.classId == selectedClass.id }.sorted { $0.date > $1.date }
    }

    func className(for classId: UUID) -> String {
        return classes.first { $0.id == classId }?.name ?? "Unknown Class"
    }

    // MARK: - Persistence

    private func saveClasses() {
        if let encoded = try? JSONEncoder().encode(classes) {
            UserDefaults.standard.set(encoded, forKey: classesKey)
        }
    }

    private func loadClasses() {
        if let data = UserDefaults.standard.data(forKey: classesKey),
           let decoded = try? JSONDecoder().decode([ClassModel].self, from: data) {
            classes = decoded
            selectedClass = classes.first
        }
    }

    private func saveRecordings() {
        if let encoded = try? JSONEncoder().encode(recordings) {
            UserDefaults.standard.set(encoded, forKey: recordingsKey)
        }
    }

    private func loadRecordings() {
        if let data = UserDefaults.standard.data(forKey: recordingsKey),
           let decoded = try? JSONDecoder().decode([RecordingModel].self, from: data) {
            recordings = decoded
        }
    }
}
