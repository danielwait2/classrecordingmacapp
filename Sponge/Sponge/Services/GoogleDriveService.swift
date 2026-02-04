import Foundation

/// Errors that can occur during Google Drive operations
enum GoogleDriveError: Error, LocalizedError {
    case notAuthenticated
    case uploadFailed(String)
    case folderNotFound
    case networkError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to Google Drive"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .folderNotFound:
            return "Google Drive folder not found"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from Google Drive"
        }
    }
}

/// Represents a folder in Google Drive
struct DriveFolder: Identifiable, Equatable {
    let id: String
    let name: String
    let parentId: String?
}

/// Service for interacting with Google Drive API
class GoogleDriveService: ObservableObject {
    static let shared = GoogleDriveService()

    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0

    private let authService = GoogleAuthService.shared
    private let baseURL = "https://www.googleapis.com/drive/v3"
    private let uploadURL = "https://www.googleapis.com/upload/drive/v3"

    private init() {}

    // MARK: - Folder Operations

    /// Lists folders in a given parent folder
    /// - Parameter parentId: The ID of the parent folder ("root" for My Drive root)
    /// - Returns: Array of DriveFolder objects
    func listFolders(parentId: String = "root") async throws -> [DriveFolder] {
        let token = try await authService.getAccessToken()

        var components = URLComponents(string: "\(baseURL)/files")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "'\(parentId)' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false"),
            URLQueryItem(name: "fields", value: "files(id,name,parents)"),
            URLQueryItem(name: "orderBy", value: "name"),
            URLQueryItem(name: "pageSize", value: "100")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleDriveError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw GoogleDriveError.notAuthenticated
        }

        guard httpResponse.statusCode == 200 else {
            throw GoogleDriveError.networkError(NSError(domain: "GoogleDrive", code: httpResponse.statusCode))
        }

        let result = try JSONDecoder().decode(FileListResponse.self, from: data)

        return result.files.map { file in
            DriveFolder(
                id: file.id,
                name: file.name,
                parentId: file.parents?.first
            )
        }
    }

    /// Gets information about a specific folder
    /// - Parameter folderId: The ID of the folder
    /// - Returns: DriveFolder object
    func getFolder(folderId: String) async throws -> DriveFolder {
        let token = try await authService.getAccessToken()

        var components = URLComponents(string: "\(baseURL)/files/\(folderId)")!
        components.queryItems = [
            URLQueryItem(name: "fields", value: "id,name,parents")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GoogleDriveError.folderNotFound
        }

        let file = try JSONDecoder().decode(DriveFile.self, from: data)

        return DriveFolder(
            id: file.id,
            name: file.name,
            parentId: file.parents?.first
        )
    }

    // MARK: - File Upload

    /// Uploads a PDF file to Google Drive
    /// - Parameters:
    ///   - data: The PDF data to upload
    ///   - fileName: The name for the file (without extension)
    ///   - folderId: The ID of the folder to upload to
    /// - Returns: The ID of the uploaded file
    func uploadPDF(data: Data, fileName: String, toFolderId folderId: String) async throws -> String {
        let token = try await authService.getAccessToken()

        await MainActor.run {
            self.isUploading = true
            self.uploadProgress = 0
        }

        defer {
            Task { @MainActor in
                self.isUploading = false
            }
        }

        // Create multipart upload request
        let boundary = UUID().uuidString

        var request = URLRequest(url: URL(string: "\(uploadURL)/files?uploadType=multipart&fields=id,name,webViewLink")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()

        // Metadata part
        let metadata: [String: Any] = [
            "name": "\(fileName).pdf",
            "mimeType": "application/pdf",
            "parents": [folderId]
        ]

        let metadataData = try JSONSerialization.data(withJSONObject: metadata)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metadataData)
        body.append("\r\n".data(using: .utf8)!)

        // File part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Perform upload
        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleDriveError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw GoogleDriveError.notAuthenticated
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw GoogleDriveError.uploadFailed(errorMessage)
        }

        let uploadedFile = try JSONDecoder().decode(DriveFile.self, from: responseData)

        await MainActor.run {
            self.uploadProgress = 1.0
        }

        return uploadedFile.id
    }

    /// Checks if the user has access to a specific folder
    /// - Parameter folderId: The ID of the folder to check
    /// - Returns: True if the folder exists and is accessible
    func canAccessFolder(folderId: String) async -> Bool {
        do {
            _ = try await getFolder(folderId: folderId)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Response Types

private struct FileListResponse: Codable {
    let files: [DriveFile]
}

private struct DriveFile: Codable {
    let id: String
    let name: String
    let parents: [String]?
    let webViewLink: String?
}
