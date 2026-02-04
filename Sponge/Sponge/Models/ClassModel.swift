import Foundation

struct ClassModel: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var folderBookmark: Data?
    var googleDriveFolder: GoogleDriveFolderInfo?
    var saveDestination: SaveDestination

    init(
        id: UUID = UUID(),
        name: String,
        folderBookmark: Data? = nil,
        googleDriveFolder: GoogleDriveFolderInfo? = nil,
        saveDestination: SaveDestination = .localOnly
    ) {
        self.id = id
        self.name = name
        self.folderBookmark = folderBookmark
        self.googleDriveFolder = googleDriveFolder
        self.saveDestination = saveDestination
    }

    // MARK: - Codable

    // Custom decoding to handle migration from old data without new fields
    enum CodingKeys: String, CodingKey {
        case id, name, folderBookmark, googleDriveFolder, saveDestination
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        folderBookmark = try container.decodeIfPresent(Data.self, forKey: .folderBookmark)
        googleDriveFolder = try container.decodeIfPresent(GoogleDriveFolderInfo.self, forKey: .googleDriveFolder)
        // Default to localOnly for existing data that doesn't have saveDestination
        saveDestination = try container.decodeIfPresent(SaveDestination.self, forKey: .saveDestination) ?? .localOnly
    }

    // MARK: - Folder Resolution

    func resolveFolder() -> URL? {
        guard let bookmarkData = folderBookmark else { return nil }

        var isStale = false
        do {
            #if os(macOS)
            let url = try URL(resolvingBookmarkData: bookmarkData,
                              options: .withSecurityScope,
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            #else
            let url = try URL(resolvingBookmarkData: bookmarkData,
                              options: [],
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            #endif

            if isStale {
                return nil
            }
            return url
        } catch {
            print("Failed to resolve bookmark: \(error)")
            return nil
        }
    }

    static func createBookmark(for url: URL) -> Data? {
        do {
            #if os(macOS)
            return try url.bookmarkData(options: .withSecurityScope,
                                         includingResourceValuesForKeys: nil,
                                         relativeTo: nil)
            #else
            return try url.bookmarkData(options: .minimalBookmark,
                                         includingResourceValuesForKeys: nil,
                                         relativeTo: nil)
            #endif
        } catch {
            print("Failed to create bookmark: \(error)")
            return nil
        }
    }

    // MARK: - Validation

    /// Checks if the class has all required destinations configured
    var isConfigurationValid: Bool {
        switch saveDestination {
        case .localOnly:
            return folderBookmark != nil && resolveFolder() != nil
        case .googleDriveOnly:
            return googleDriveFolder != nil
        case .both:
            return (folderBookmark != nil && resolveFolder() != nil) && googleDriveFolder != nil
        }
    }

    /// Checks if local folder is configured (when needed)
    var hasLocalFolder: Bool {
        folderBookmark != nil && resolveFolder() != nil
    }

    /// Checks if Google Drive folder is configured (when needed)
    var hasGoogleDriveFolder: Bool {
        googleDriveFolder != nil
    }
}
