import Foundation

struct ClassModel: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var folderBookmark: Data?
    var saveDestination: SaveDestination

    init(
        id: UUID = UUID(),
        name: String,
        folderBookmark: Data? = nil,
        saveDestination: SaveDestination = .localOnly
    ) {
        self.id = id
        self.name = name
        self.folderBookmark = folderBookmark
        self.saveDestination = saveDestination
    }

    // MARK: - Codable

    // Custom decoding to handle migration from old data that had Google fields
    enum CodingKeys: String, CodingKey {
        case id, name, folderBookmark, googleDriveFolder, saveDestination
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        folderBookmark = try container.decodeIfPresent(Data.self, forKey: .folderBookmark)
        // Ignore old googleDriveFolder field if present
        saveDestination = try container.decodeIfPresent(SaveDestination.self, forKey: .saveDestination) ?? .localOnly
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(folderBookmark, forKey: .folderBookmark)
        try container.encode(saveDestination, forKey: .saveDestination)
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
            return try url.bookmarkData(options: .withSecurityScope,
                                         includingResourceValuesForKeys: nil,
                                         relativeTo: nil)
        } catch {
            print("Failed to create bookmark: \(error)")
            return nil
        }
    }

    // MARK: - Validation

    /// Checks if the class has a valid local folder configured
    var isConfigurationValid: Bool {
        folderBookmark != nil && resolveFolder() != nil
    }

    /// Checks if local folder is configured
    var hasLocalFolder: Bool {
        folderBookmark != nil && resolveFolder() != nil
    }
}
