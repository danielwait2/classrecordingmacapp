import Foundation

/// Defines where PDF transcripts should be saved for a class.
/// Simplified to local-only after removing Google Drive integration.
enum SaveDestination: String, Codable, CaseIterable {
    case localOnly = "local"

    var displayName: String {
        return "Local Folder"
    }

    var shortName: String {
        return "Local"
    }

    var requiresLocalFolder: Bool {
        return true
    }

    // Backward-compatible decoder: maps old Google Drive values to localOnly
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        // Old values "drive" and "both" map to localOnly
        self = SaveDestination(rawValue: raw) ?? .localOnly
    }
}
