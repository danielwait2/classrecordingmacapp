import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ClassEditorView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authService = GoogleAuthService.shared

    let classToEdit: ClassModel?

    @State private var className: String = ""
    @State private var selectedFolderURL: URL?
    @State private var saveDestination: SaveDestination = .localOnly
    @State private var selectedDriveFolder: GoogleDriveFolderInfo?
    @State private var showingFolderPicker = false
    @State private var showingDriveFolderPicker = false

    var isEditing: Bool {
        classToEdit != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Class Name Section
                Section {
                    TextField("e.g., Biology 101", text: $className)
                        .font(.body)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                } header: {
                    Label("Class Name", systemImage: "textformat")
                }

                // Save Destination Section
                Section {
                    Picker("Save PDFs to", selection: $saveDestination) {
                        ForEach(SaveDestination.allCases, id: \.self) { destination in
                            Label(destination.displayName, systemImage: destinationIcon(for: destination))
                                .tag(destination)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.navigationLink)
                    #else
                    .pickerStyle(.menu)
                    #endif
                } header: {
                    Label("Save Location", systemImage: "square.and.arrow.down")
                } footer: {
                    Text(saveDestinationFooter)
                }

                // Local Folder Section
                if saveDestination.requiresLocalFolder {
                    Section {
                        localFolderRow
                    } header: {
                        Label("Local Folder", systemImage: "folder")
                    }
                }

                // Google Drive Section
                if saveDestination.requiresGoogleDrive {
                    Section {
                        googleDriveContent
                    } header: {
                        Label("Google Drive", systemImage: "icloud")
                    }
                }

                // Configuration Warning
                if !isConfigurationComplete && !className.isEmpty {
                    Section {
                        Label(configurationWarning, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Class" : "New Class")
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
                    Button(isEditing ? "Save" : "Add") {
                        saveClass()
                    }
                    .fontWeight(.semibold)
                    .disabled(className.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let classToEdit = classToEdit {
                    className = classToEdit.name
                    selectedFolderURL = classToEdit.resolveFolder()
                    saveDestination = classToEdit.saveDestination
                    selectedDriveFolder = classToEdit.googleDriveFolder
                }
            }
            .sheet(isPresented: $showingDriveFolderPicker) {
                GoogleDriveFolderPicker(selectedFolder: $selectedDriveFolder)
            }
            #if os(iOS)
            .sheet(isPresented: $showingFolderPicker) {
                FolderPickerView(selectedURL: $selectedFolderURL)
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 420)
        #endif
    }

    // MARK: - Local Folder Row

    private var localFolderRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let url = selectedFolderURL {
                    Text(url.lastPathComponent)
                        .font(.body)
                    Text(url.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("No folder selected")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if selectedFolderURL != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

            Button("Choose") {
                selectFolder()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Google Drive Content

    @ViewBuilder
    private var googleDriveContent: some View {
        if authService.isSignedIn {
            // Drive folder selection
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let folder = selectedDriveFolder {
                        Text(folder.folderName)
                            .font(.body)
                        Text(folder.folderPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("No folder selected")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if selectedDriveFolder != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }

                Button("Choose") {
                    showingDriveFolderPicker = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Account info
            if let user = authService.currentUser {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 24, height: 24)
                        Text(String(user.name.prefix(1)).uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.blue)
                    }

                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            // Sign in prompt
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Text("Sign in to save to Google Drive")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                GoogleSignInButton {
                    Task {
                        try? await authService.signIn()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Computed Properties

    private func destinationIcon(for destination: SaveDestination) -> String {
        switch destination {
        case .localOnly: return "folder"
        case .googleDriveOnly: return "icloud"
        case .both: return "arrow.triangle.branch"
        }
    }

    private var saveDestinationFooter: String {
        switch saveDestination {
        case .localOnly:
            return "PDF transcripts will be saved to a folder on this device."
        case .googleDriveOnly:
            return "PDF transcripts will be uploaded to your Google Drive."
        case .both:
            return "PDF transcripts will be saved locally and to Google Drive."
        }
    }

    private var isConfigurationComplete: Bool {
        let hasLocalIfNeeded = !saveDestination.requiresLocalFolder || selectedFolderURL != nil
        let hasDriveIfNeeded = !saveDestination.requiresGoogleDrive || (authService.isSignedIn && selectedDriveFolder != nil)
        return hasLocalIfNeeded && hasDriveIfNeeded
    }

    private var configurationWarning: String {
        var missing: [String] = []

        if saveDestination.requiresLocalFolder && selectedFolderURL == nil {
            missing.append("local folder")
        }

        if saveDestination.requiresGoogleDrive {
            if !authService.isSignedIn {
                missing.append("Google sign-in")
            } else if selectedDriveFolder == nil {
                missing.append("Drive folder")
            }
        }

        if missing.isEmpty {
            return ""
        }

        return "Please select: \(missing.joined(separator: " and "))"
    }

    // MARK: - Actions

    private func selectFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Choose a folder to save PDF transcripts"

        if panel.runModal() == .OK {
            selectedFolderURL = panel.url
        }
        #else
        showingFolderPicker = true
        #endif
    }

    private func saveClass() {
        let trimmedName = className.trimmingCharacters(in: .whitespaces)

        if let classToEdit = classToEdit {
            classViewModel.updateClass(
                classToEdit,
                name: trimmedName,
                folderURL: selectedFolderURL,
                googleDriveFolder: selectedDriveFolder,
                saveDestination: saveDestination
            )
        } else {
            classViewModel.addClass(
                name: trimmedName,
                folderURL: selectedFolderURL,
                googleDriveFolder: selectedDriveFolder,
                saveDestination: saveDestination
            )
        }

        dismiss()
    }
}

#if os(iOS)
import UIKit

struct FolderPickerView: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FolderPickerView

        init(_ parent: FolderPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else { return }

            parent.selectedURL = url
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}
#endif

#Preview {
    ClassEditorView(classToEdit: nil)
        .environmentObject(ClassViewModel())
}
