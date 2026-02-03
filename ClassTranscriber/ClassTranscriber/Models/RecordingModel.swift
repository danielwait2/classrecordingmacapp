import Foundation

struct RecordingModel: Identifiable, Codable {
    let id: UUID
    let classId: UUID
    let date: Date
    var duration: TimeInterval
    let audioFileName: String
    var transcriptText: String
    var pdfExported: Bool

    init(id: UUID = UUID(), classId: UUID, date: Date = Date(), duration: TimeInterval = 0, audioFileName: String, transcriptText: String = "", pdfExported: Bool = false) {
        self.id = id
        self.classId = classId
        self.date = date
        self.duration = duration
        self.audioFileName = audioFileName
        self.transcriptText = transcriptText
        self.pdfExported = pdfExported
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
