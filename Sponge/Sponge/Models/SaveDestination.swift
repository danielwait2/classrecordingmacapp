import Foundation

/// Defines where PDF transcripts should be saved for a class
enum SaveDestination: String, Codable, CaseIterable {
    case localOnly = "local"
    case googleDriveOnly = "drive"
    case both = "both"

    var displayName: String {
        switch self {
        case .localOnly: return "Local Folder Only"
        case .googleDriveOnly: return "Google Drive Only"
        case .both: return "Both Local and Google Drive"
        }
    }

    var shortName: String {
        switch self {
        case .localOnly: return "Local"
        case .googleDriveOnly: return "Drive"
        case .both: return "Both"
        }
    }

    var requiresLocalFolder: Bool {
        self == .localOnly || self == .both
    }

    var requiresGoogleDrive: Bool {
        self == .googleDriveOnly || self == .both
    }
}

/// Information about a selected Google Drive folder
struct GoogleDriveFolderInfo: Codable, Equatable, Hashable {
    let folderId: String
    let folderName: String
    let folderPath: String  // e.g., "My Drive/Classes/Math 101"

    init(folderId: String, folderName: String, folderPath: String) {
        self.folderId = folderId
        self.folderName = folderName
        self.folderPath = folderPath
    }
}
