import Foundation

struct RecordingModel: Identifiable, Codable {
    let id: UUID
    let classId: UUID
    let date: Date
    var duration: TimeInterval
    let audioFileName: String
    var transcriptText: String
    var classNotes: String?
    var pdfExported: Bool
    var name: String

    init(id: UUID = UUID(), classId: UUID, date: Date = Date(), duration: TimeInterval = 0, audioFileName: String, transcriptText: String = "", classNotes: String? = nil, pdfExported: Bool = false, name: String? = nil) {
        self.id = id
        self.classId = classId
        self.date = date
        self.duration = duration
        self.audioFileName = audioFileName
        self.transcriptText = transcriptText
        self.classNotes = classNotes
        self.pdfExported = pdfExported
        // Default name will be set by the ViewModel with class name
        self.name = name ?? Self.generateDefaultName(date: date)
    }

    /// Generates a default name from class name, date, and time
    static func generateDefaultName(className: String? = nil, date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        let datePart = dateFormatter.string(from: date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        timeFormatter.amSymbol = "am"
        timeFormatter.pmSymbol = "pm"
        let timePart = timeFormatter.string(from: date)

        if let className = className {
            return "\(className), \(datePart), \(timePart)"
        } else {
            return "\(datePart), \(timePart)"
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
}
