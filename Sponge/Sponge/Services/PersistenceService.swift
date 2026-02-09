import Foundation
import SwiftData
import os

@MainActor
class PersistenceService {
    static let shared = PersistenceService()

    let modelContainer: ModelContainer
    private let logger = Logger(subsystem: "com.sponge.app", category: "Persistence")
    private let migrationKey = "hasCompletedSwiftDataMigration"

    private init() {
        do {
            let schema = Schema([SDClass.self, SDRecording.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var modelContext: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - Migration from UserDefaults

    func migrateFromUserDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let classesKey = "savedClasses"
        let recordingsKey = "savedRecordings"

        // Check if there's any legacy data to migrate
        let hasClasses = UserDefaults.standard.data(forKey: classesKey) != nil
        let hasRecordings = UserDefaults.standard.data(forKey: recordingsKey) != nil

        guard hasClasses || hasRecordings else {
            // No legacy data, mark migration as complete
            UserDefaults.standard.set(true, forKey: migrationKey)
            logger.info("No legacy UserDefaults data found, skipping migration")
            return
        }

        logger.info("Starting migration from UserDefaults to SwiftData")

        var migratedClassCount = 0
        var migratedRecordingCount = 0

        // Migrate classes
        if let classData = UserDefaults.standard.data(forKey: classesKey) {
            do {
                let legacyClasses = try JSONDecoder().decode([ClassModel].self, from: classData)
                for legacyClass in legacyClasses {
                    let sdClass = SDClass(from: legacyClass)
                    modelContext.insert(sdClass)
                    migratedClassCount += 1
                }
            } catch {
                logger.error("Failed to decode legacy classes: \(error.localizedDescription)")
            }
        }

        // Migrate recordings
        if let recordingData = UserDefaults.standard.data(forKey: recordingsKey) {
            do {
                let legacyRecordings = try JSONDecoder().decode([RecordingModel].self, from: recordingData)
                for legacyRecording in legacyRecordings {
                    let sdRecording = SDRecording(from: legacyRecording)

                    // Try to link to the corresponding SDClass
                    let classId = legacyRecording.classId
                    let descriptor = FetchDescriptor<SDClass>(predicate: #Predicate { $0.id == classId })
                    if let sdClass = try? modelContext.fetch(descriptor).first {
                        sdRecording.sdClass = sdClass
                    }

                    modelContext.insert(sdRecording)
                    migratedRecordingCount += 1
                }
            } catch {
                logger.error("Failed to decode legacy recordings: \(error.localizedDescription)")
            }
        }

        // Save
        do {
            try modelContext.save()

            // Clear legacy data after successful migration
            UserDefaults.standard.removeObject(forKey: classesKey)
            UserDefaults.standard.removeObject(forKey: recordingsKey)
            UserDefaults.standard.set(true, forKey: migrationKey)

            logger.info("Migration complete: \(migratedClassCount) classes, \(migratedRecordingCount) recordings")
        } catch {
            logger.error("Failed to save migrated data: \(error.localizedDescription)")
        }
    }

    // MARK: - Class Operations

    func fetchClasses() -> [SDClass] {
        let descriptor = FetchDescriptor<SDClass>(sortBy: [SortDescriptor(\.name)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func addClass(name: String, folderURL: URL?) -> SDClass {
        var bookmark: Data?
        if let url = folderURL {
            bookmark = SDClass.createBookmark(for: url)
        }
        let sdClass = SDClass(name: name, folderBookmark: bookmark)
        modelContext.insert(sdClass)
        try? modelContext.save()
        return sdClass
    }

    func updateClass(_ sdClass: SDClass, name: String, folderURL: URL?) {
        sdClass.name = name
        if let url = folderURL {
            sdClass.folderBookmark = SDClass.createBookmark(for: url)
        }
        try? modelContext.save()
    }

    func deleteClass(_ sdClass: SDClass) {
        modelContext.delete(sdClass)
        try? modelContext.save()
    }

    // MARK: - Recording Operations

    func fetchRecordings(for classId: UUID) -> [SDRecording] {
        let descriptor = FetchDescriptor<SDRecording>(
            predicate: #Predicate { $0.classId == classId },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchAllRecordings() -> [SDRecording] {
        let descriptor = FetchDescriptor<SDRecording>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func addRecording(_ recording: SDRecording) {
        modelContext.insert(recording)
        try? modelContext.save()
    }

    func saveContext() {
        try? modelContext.save()
    }

    func deleteRecording(_ recording: SDRecording) {
        // Delete audio file
        if let audioURL = recording.audioFileURL() {
            try? FileManager.default.removeItem(at: audioURL)
        }
        modelContext.delete(recording)
        try? modelContext.save()
    }
}
