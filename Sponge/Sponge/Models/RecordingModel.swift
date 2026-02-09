import Foundation

struct RecordingModel: Identifiable, Codable {
    let id: UUID
    let classId: UUID
    let date: Date
    var duration: TimeInterval
    let audioFileName: String
    var transcriptText: String
    var userNotes: String
    var classNotes: String?
    var pdfExported: Bool
    var name: String

    // New fields for Intent Markers, Enhanced Summaries, and Recall Prompts
    var intentMarkers: [IntentMarker]
    var enhancedSummary: EnhancedSummary?
    var recallPrompts: RecallPrompts?
    var catchUpSummaries: [CatchUpSummary]

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
        name: String? = nil,
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
        // Default name will be set by the ViewModel with class name
        self.name = name ?? Self.generateDefaultName(date: date)
        self.intentMarkers = intentMarkers
        self.enhancedSummary = enhancedSummary
        self.recallPrompts = recallPrompts
        self.catchUpSummaries = catchUpSummaries
    }

    // Custom decoder for backward compatibility with existing recordings
    enum CodingKeys: String, CodingKey {
        case id, classId, date, duration, audioFileName, transcriptText
        case userNotes, classNotes, pdfExported, name
        case intentMarkers, enhancedSummary, recallPrompts, catchUpSummaries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        classId = try container.decode(UUID.self, forKey: .classId)
        date = try container.decode(Date.self, forKey: .date)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        audioFileName = try container.decode(String.self, forKey: .audioFileName)
        transcriptText = try container.decode(String.self, forKey: .transcriptText)
        userNotes = try container.decode(String.self, forKey: .userNotes)
        classNotes = try container.decodeIfPresent(String.self, forKey: .classNotes)
        pdfExported = try container.decode(Bool.self, forKey: .pdfExported)
        name = try container.decode(String.self, forKey: .name)

        // New fields with backward compatibility - default to empty/nil if not present
        intentMarkers = try container.decodeIfPresent([IntentMarker].self, forKey: .intentMarkers) ?? []
        enhancedSummary = try container.decodeIfPresent(EnhancedSummary.self, forKey: .enhancedSummary)
        recallPrompts = try container.decodeIfPresent(RecallPrompts.self, forKey: .recallPrompts)
        catchUpSummaries = try container.decodeIfPresent([CatchUpSummary].self, forKey: .catchUpSummaries) ?? []
    }

    // Cached formatters to avoid expensive re-creation
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

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// Generates a default name from class name, date, and time
    static func generateDefaultName(className: String? = nil, date: Date) -> String {
        let datePart = nameDateFormatter.string(from: date)
        let timePart = nameTimeFormatter.string(from: date)

        if let className = className {
            return "\(className), \(datePart), \(timePart)"
        } else {
            return "\(datePart), \(timePart)"
        }
    }

    var formattedDate: String {
        return Self.displayDateFormatter.string(from: date)
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

    func audioFileURL() -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsPath?.appendingPathComponent("Recordings").appendingPathComponent(audioFileName)
    }

    // MARK: - Computed Properties for Marker Analysis

    /// Returns true if there are any confusion markers
    var hasConfusionMarkers: Bool {
        intentMarkers.contains { $0.type == .confused }
    }

    /// Returns true if there are any exam-relevant or important markers
    var hasExamMarkers: Bool {
        intentMarkers.contains { $0.type == .examRelevant || $0.type == .important }
    }

    /// Count of markers by type
    var markerCounts: [IntentMarkerType: Int] {
        Dictionary(grouping: intentMarkers, by: { $0.type }).mapValues { $0.count }
    }
}
