import Foundation
import SwiftData

@Model
final class SDClass: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var folderBookmark: Data?

    @Relationship(deleteRule: .cascade, inverse: \SDRecording.sdClass)
    var recordings: [SDRecording] = []

    init(id: UUID = UUID(), name: String, folderBookmark: Data? = nil) {
        self.id = id
        self.name = name
        self.folderBookmark = folderBookmark
    }

    // MARK: - Folder Resolution

    func resolveFolder() -> URL? {
        guard let bookmarkData = folderBookmark else { return nil }

        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData,
                              options: .withSecurityScope,
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)

            if isStale { return nil }
            return url
        } catch {
            return nil
        }
    }

    static func createBookmark(for url: URL) -> Data? {
        do {
            return try url.bookmarkData(options: .withSecurityScope,
                                         includingResourceValuesForKeys: nil,
                                         relativeTo: nil)
        } catch {
            return nil
        }
    }

    var saveDestination: SaveDestination { .localOnly }

    var isConfigurationValid: Bool {
        folderBookmark != nil && resolveFolder() != nil
    }

    var hasLocalFolder: Bool {
        folderBookmark != nil && resolveFolder() != nil
    }

    /// Convert from legacy ClassModel for migration
    convenience init(from legacy: ClassModel) {
        self.init(id: legacy.id, name: legacy.name, folderBookmark: legacy.folderBookmark)
    }
}

@Model
final class SDRecording {
    @Attribute(.unique) var id: UUID
    var classId: UUID
    var date: Date
    var duration: TimeInterval
    var audioFileName: String
    var transcriptText: String
    var userNotes: String
    var classNotes: String?
    var pdfExported: Bool
    var name: String

    // Complex types stored as JSON-encoded Data
    var intentMarkersData: Data?
    var enhancedSummaryData: Data?
    var recallPromptsData: Data?
    var catchUpSummariesData: Data?

    var sdClass: SDClass?

    init(
        id: UUID = UUID(),
        classId: UUID,
        date: Date = Date(),
        duration: TimeInterval = 0,
        audioFileName: String,
        transcriptText: String = "",
        userNotes: String = "",
        classNotes: String? = nil,
        pdfExported: Bool = false,
        name: String = "",
        intentMarkers: [IntentMarker] = [],
        enhancedSummary: EnhancedSummary? = nil,
        recallPrompts: RecallPrompts? = nil,
        catchUpSummaries: [CatchUpSummary] = []
    ) {
        self.id = id
        self.classId = classId
        self.date = date
        self.duration = duration
        self.audioFileName = audioFileName
        self.transcriptText = transcriptText
        self.userNotes = userNotes
        self.classNotes = classNotes
        self.pdfExported = pdfExported
        self.name = name
        self.intentMarkers = intentMarkers
        self.enhancedSummary = enhancedSummary
        self.recallPrompts = recallPrompts
        self.catchUpSummaries = catchUpSummaries
    }

    // MARK: - Computed accessors for complex types

    var intentMarkers: [IntentMarker] {
        get {
            guard let data = intentMarkersData else { return [] }
            return (try? JSONDecoder().decode([IntentMarker].self, from: data)) ?? []
        }
        set {
            intentMarkersData = try? JSONEncoder().encode(newValue)
        }
    }

    var enhancedSummary: EnhancedSummary? {
        get {
            guard let data = enhancedSummaryData else { return nil }
            return try? JSONDecoder().decode(EnhancedSummary.self, from: data)
        }
        set {
            enhancedSummaryData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }

    var recallPrompts: RecallPrompts? {
        get {
            guard let data = recallPromptsData else { return nil }
            return try? JSONDecoder().decode(RecallPrompts.self, from: data)
        }
        set {
            recallPromptsData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }

    var catchUpSummaries: [CatchUpSummary] {
        get {
            guard let data = catchUpSummariesData else { return [] }
            return (try? JSONDecoder().decode([CatchUpSummary].self, from: data)) ?? []
        }
        set {
            catchUpSummariesData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - Audio File

    func audioFileURL() -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsPath?.appendingPathComponent("Recordings").appendingPathComponent(audioFileName)
    }

    // MARK: - Formatting

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var formattedDate: String {
        Self.displayDateFormatter.string(from: date)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var hasConfusionMarkers: Bool {
        intentMarkers.contains { $0.type == .confused }
    }

    var hasExamMarkers: Bool {
        intentMarkers.contains { $0.type == .examRelevant || $0.type == .important }
    }

    var markerCounts: [IntentMarkerType: Int] {
        Dictionary(grouping: intentMarkers, by: { $0.type }).mapValues { $0.count }
    }

    // MARK: - Name Generation

    private static let nameDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private static let nameTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f
    }()

    static func generateDefaultName(className: String? = nil, date: Date) -> String {
        let datePart = nameDateFormatter.string(from: date)
        let timePart = nameTimeFormatter.string(from: date)

        if let className = className {
            return "\(className), \(datePart), \(timePart)"
        } else {
            return "\(datePart), \(timePart)"
        }
    }

    /// Convert from legacy RecordingModel for migration
    convenience init(from legacy: RecordingModel) {
        self.init(
            id: legacy.id,
            classId: legacy.classId,
            date: legacy.date,
            duration: legacy.duration,
            audioFileName: legacy.audioFileName,
            transcriptText: legacy.transcriptText,
            userNotes: legacy.userNotes,
            classNotes: legacy.classNotes,
            pdfExported: legacy.pdfExported,
            name: legacy.name,
            intentMarkers: legacy.intentMarkers,
            enhancedSummary: legacy.enhancedSummary,
            recallPrompts: legacy.recallPrompts,
            catchUpSummaries: legacy.catchUpSummaries
        )
    }
}
