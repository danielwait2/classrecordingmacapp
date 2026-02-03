import SwiftUI

/// A view for browsing and selecting a folder from Google Drive
struct GoogleDriveFolderPicker: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var driveService = GoogleDriveService.shared
    @ObservedObject private var authService = GoogleAuthService.shared

    @Binding var selectedFolder: GoogleDriveFolderInfo?

    @State private var currentFolderId: String = "root"
    @State private var currentFolderName: String = "My Drive"
    @State private var folderStack: [(id: String, name: String)] = []
    @State private var folders: [DriveFolder] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Breadcrumb navigation
                breadcrumbView
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.05))

                Divider()

                // Content
                if !authService.isSignedIn {
                    notSignedInView
                } else if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    folderListView
                }
            }
            .navigationTitle("Choose Folder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Select") {
                        selectCurrentFolder()
                    }
                    .fontWeight(.semibold)
                    .disabled(!authService.isSignedIn)
                }
            }
            .onAppear {
                if authService.isSignedIn {
                    loadFolders()
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 450, minHeight: 450)
        #endif
    }

    // MARK: - Breadcrumb View

    private var breadcrumbView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Home button
                Button {
                    navigateToRoot()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "house.fill")
                            .font(.caption)
                        Text("My Drive")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(folderStack.isEmpty ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)

                ForEach(Array(folderStack.enumerated()), id: \.offset) { index, folder in
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button {
                        navigateToIndex(index)
                    } label: {
                        Text(folder.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if !folderStack.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(currentFolderName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    // MARK: - Not Signed In View

    private var notSignedInView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "icloud.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            VStack(spacing: 8) {
                Text("Sign in Required")
                    .font(.title3.weight(.semibold))

                Text("Sign in to your Google account to browse and select a Drive folder")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            GoogleSignInButton {
                Task {
                    try? await authService.signIn()
                    if authService.isSignedIn {
                        loadFolders()
                    }
                }
            }

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading folders...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("Unable to Load Folders")
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                loadFolders()
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Folder List View

    private var folderListView: some View {
        VStack(spacing: 0) {
            // Current selection card
            currentSelectionCard
                .padding(16)

            Divider()

            // Subfolders list
            if folders.isEmpty {
                emptyFoldersView
            } else {
                List {
                    ForEach(folders) { folder in
                        Button {
                            navigateToFolder(folder)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 32, height: 32)

                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                }

                                Text(folder.name)
                                    .font(.body)
                                    .foregroundColor(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Current Selection Card

    private var currentSelectionCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Selected Folder")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(currentFolderName)
                    .font(.body.weight(.medium))

                Text(currentFolderPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }

    // MARK: - Empty Folders View

    private var emptyFoldersView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "folder")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No Subfolders")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("This folder doesn't contain any subfolders")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Navigation

    private var currentFolderPath: String {
        if folderStack.isEmpty {
            return currentFolderName
        }
        let path = folderStack.map { $0.name }.joined(separator: "/")
        return "\(path)/\(currentFolderName)"
    }

    private func loadFolders() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let loadedFolders = try await driveService.listFolders(parentId: currentFolderId)
                await MainActor.run {
                    folders = loadedFolders
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func navigateToFolder(_ folder: DriveFolder) {
        folderStack.append((id: currentFolderId, name: currentFolderName))
        currentFolderId = folder.id
        currentFolderName = folder.name
        loadFolders()
    }

    private func navigateToRoot() {
        folderStack.removeAll()
        currentFolderId = "root"
        currentFolderName = "My Drive"
        loadFolders()
    }

    private func navigateToIndex(_ index: Int) {
        if index < folderStack.count {
            let targetFolder = folderStack[index]
            folderStack = Array(folderStack.prefix(index))
            currentFolderId = targetFolder.id
            currentFolderName = targetFolder.name
            loadFolders()
        }
    }

    private func selectCurrentFolder() {
        selectedFolder = GoogleDriveFolderInfo(
            folderId: currentFolderId,
            folderName: currentFolderName,
            folderPath: currentFolderPath
        )
        dismiss()
    }
}

#Preview {
    GoogleDriveFolderPicker(selectedFolder: .constant(nil))
}
