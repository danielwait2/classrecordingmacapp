import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authService = GoogleAuthService.shared

    @AppStorage("autoGenerateClassNotes") private var autoGenerateClassNotes = false
    @AppStorage("realtimeTranscription") private var realtimeTranscription = true
    @State private var geminiAPIKey: String = ""
    @State private var showingAPIKeyAlert = false

    var body: some View {
        NavigationStack {
            Form {
                // Google Account Section
                Section {
                    googleAccountContent
                } header: {
                    Label("Google Account", systemImage: "person.circle")
                }

                // Recording Options Section
                Section {
                    recordingOptionsContent
                } header: {
                    Label("Recording Options", systemImage: "waveform")
                } footer: {
                    Text("Post-recording transcription saves battery by transcribing after you finish recording instead of in real-time.")
                }

                // AI Class Notes Section
                Section {
                    aiClassNotesContent
                } header: {
                    Label("AI Class Notes", systemImage: "brain")
                } footer: {
                    Text("Automatically generate comprehensive class notes from transcriptions using Gemini AI. Get your free API key at ai.google.dev")
                }

                // Class Save Locations Section
                Section {
                    if classViewModel.classes.isEmpty {
                        emptyClassesView
                    } else {
                        ForEach(classViewModel.classes) { classModel in
                            ClassFolderRow(classModel: classModel, classViewModel: classViewModel)
                        }
                    }
                } header: {
                    Label("Class Save Locations", systemImage: "folder")
                } footer: {
                    Text("Configure where PDF transcripts are saved for each class. Tap Edit to change settings.")
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadGeminiAPIKey()
            }
            .alert("API Key Updated", isPresented: $showingAPIKeyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your Gemini API key has been securely saved.")
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 450)
        #endif
    }

    // MARK: - Recording Options Content

    @ViewBuilder
    private var recordingOptionsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Real-time transcription", isOn: $realtimeTranscription)

            if !realtimeTranscription {
                HStack(spacing: 8) {
                    Image(systemName: "battery.100")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Battery saver mode - transcription happens after recording")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - AI Class Notes Content

    @ViewBuilder
    private var aiClassNotesContent: some View {
        // Auto-generate toggle
        Toggle("Auto-generate class notes", isOn: $autoGenerateClassNotes)

        // API Key input
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SecureField("Gemini API Key", text: $geminiAPIKey)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    #endif

                if !geminiAPIKey.isEmpty {
                    Button("Save") {
                        saveGeminiAPIKey()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if geminiAPIKey.isEmpty && KeychainHelper.shared.getGeminiAPIKey() != nil {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("API key is saved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Link("Get a free API key →", destination: URL(string: "https://ai.google.dev")!)
                .font(.caption)
        }
    }

    // MARK: - Google Account Content

    @ViewBuilder
    private var googleAccountContent: some View {
        if authService.isSignedIn, let user = authService.currentUser {
            // Signed in state
            HStack(spacing: 12) {
                // Profile icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Text(String(user.name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.headline)
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Sign Out") {
                    authService.signOut()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.vertical, 4)
        } else {
            // Signed out state
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "cloud")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Not signed in")
                            .font(.headline)
                        Text("Sign in to save transcripts to Google Drive")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                GoogleSignInButton {
                    Task {
                        try? await authService.signIn()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty State

    private var emptyClassesView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.title)
                    .foregroundColor(.secondary)
                Text("No classes added yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Add a class to configure save locations")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }

    // MARK: - Helper Methods

    private func loadGeminiAPIKey() {
        // Don't show the actual key for security, just check if it exists
        if KeychainHelper.shared.getGeminiAPIKey() != nil {
            geminiAPIKey = ""
        }
    }

    private func saveGeminiAPIKey() {
        let trimmedKey = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty {
            _ = KeychainHelper.shared.deleteGeminiAPIKey()
        } else {
            _ = KeychainHelper.shared.saveGeminiAPIKey(trimmedKey)
            showingAPIKeyAlert = true
        }
        geminiAPIKey = ""
    }
}

// MARK: - Class Folder Row

struct ClassFolderRow: View {
    let classModel: ClassModel
    @ObservedObject var classViewModel: ClassViewModel
    @State private var showingClassEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row with class name and edit button
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(classModel.name)
                        .font(.headline)

                    // Save destination label
                    Label(classModel.saveDestination.displayName, systemImage: destinationIcon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Configuration status indicator
                if classModel.isConfigurationValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                }

                Button("Edit") {
                    showingClassEditor = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Folder details
            VStack(alignment: .leading, spacing: 6) {
                // Local folder status
                if classModel.saveDestination.requiresLocalFolder {
                    folderStatusRow(
                        icon: "folder.fill",
                        label: "Local:",
                        isConfigured: classModel.hasLocalFolder,
                        detail: classModel.resolveFolder()?.lastPathComponent ?? "Not set"
                    )
                }

                // Drive folder status
                if classModel.saveDestination.requiresGoogleDrive {
                    folderStatusRow(
                        icon: "icloud.fill",
                        label: "Drive:",
                        isConfigured: classModel.hasGoogleDriveFolder,
                        detail: classModel.googleDriveFolder?.folderPath ?? "Not set"
                    )
                }
            }
            .padding(.leading, 4)
        }
        .padding(.vertical, 6)
        .sheet(isPresented: $showingClassEditor) {
            ClassEditorView(classToEdit: classModel)
                .environmentObject(classViewModel)
        }
    }

    private var destinationIcon: String {
        switch classModel.saveDestination {
        case .localOnly:
            return "folder"
        case .googleDriveOnly:
            return "icloud"
        case .both:
            return "arrow.triangle.branch"
        }
    }

    private func folderStatusRow(icon: String, label: String, isConfigured: Bool, detail: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(isConfigured ? .blue : .secondary)
                .frame(width: 16)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)

            if isConfigured {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .italic()
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ClassViewModel())
}
