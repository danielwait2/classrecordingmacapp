import Foundation

struct ClassModel: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var folderBookmark: Data?

    init(id: UUID = UUID(), name: String, folderBookmark: Data? = nil) {
        self.id = id
        self.name = name
        self.folderBookmark = folderBookmark
    }

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
}
