import Foundation

/// Enhanced summaries generated from transcript with optional marker-focused content
struct EnhancedSummary: Codable {
    var generalOverview: String?
    var confusionFocused: String?      // Only if confused markers exist
    var examOriented: String?          // Only if exam/important markers exist

    init(generalOverview: String? = nil, confusionFocused: String? = nil, examOriented: String? = nil) {
        self.generalOverview = generalOverview
        self.confusionFocused = confusionFocused
        self.examOriented = examOriented
    }
}

/// Types of recall questions for varied testing
enum RecallQuestionType: String, Codable, CaseIterable, Identifiable {
    case definition
    case conceptual
    case applied
    case connection

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .definition:
            return "Definition"
        case .conceptual:
            return "Conceptual"
        case .applied:
            return "Applied"
        case .connection:
            return "Connection"
        }
    }

    var icon: String {
        switch self {
        case .definition:
            return "text.book.closed"
        case .conceptual:
            return "lightbulb"
        case .applied:
            return "hammer"
        case .connection:
            return "link"
        }
    }

    var description: String {
        switch self {
        case .definition:
            return "What is...?"
        case .conceptual:
            return "Why/How does...?"
        case .applied:
            return "How would you use...?"
        case .connection:
            return "How does X relate to Y?"
        }
    }
}

/// A single recall question for post-lecture review
struct RecallQuestion: Identifiable, Codable {
    let id: UUID
    let question: String
    let type: RecallQuestionType
    let suggestedAnswer: String?

    init(id: UUID = UUID(), question: String, type: RecallQuestionType, suggestedAnswer: String? = nil) {
        self.id = id
        self.question = question
        self.type = type
        self.suggestedAnswer = suggestedAnswer
    }
}

/// Container for recall prompts generated for a recording
struct RecallPrompts: Codable {
    var questions: [RecallQuestion]

    init(questions: [RecallQuestion] = []) {
        self.questions = questions
    }

    /// Groups questions by type for organized display
    var questionsByType: [RecallQuestionType: [RecallQuestion]] {
        Dictionary(grouping: questions, by: { $0.type })
    }
}

/// A catch-up summary generated when user requests "What did I miss?"
struct CatchUpSummary: Identifiable, Codable {
    let id: UUID
    let requestedAt: TimeInterval
    let coveringFrom: TimeInterval
    let summary: String

    init(id: UUID = UUID(), requestedAt: TimeInterval, coveringFrom: TimeInterval, summary: String) {
        self.id = id
        self.requestedAt = requestedAt
        self.coveringFrom = coveringFrom
        self.summary = summary
    }

    /// Formats the time range covered
    var formattedRange: String {
        let fromMinutes = Int(coveringFrom) / 60
        let fromSeconds = Int(coveringFrom) % 60
        let toMinutes = Int(requestedAt) / 60
        let toSeconds = Int(requestedAt) % 60
        return String(format: "%d:%02d - %d:%02d", fromMinutes, fromSeconds, toMinutes, toSeconds)
    }
}
