import SwiftUI
import AppKit

struct ClassEditorView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @Environment(\.dismiss) private var dismiss

    let classToEdit: SDClass?

    @State private var className: String = ""
    @State private var selectedFolderURL: URL?

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
                } header: {
                    Label("Class Name", systemImage: "textformat")
                }

                // Local Folder Section
                Section {
                    localFolderRow
                } header: {
                    Label("Save Location", systemImage: "folder")
                } footer: {
                    Text("PDF transcripts will be saved to this folder on your device.")
                }

                // Configuration Warning
                if selectedFolderURL == nil && !className.isEmpty {
                    Section {
                        Label("Please select a local folder", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Class" : "New Class")
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
                }
            }
        }
        .frame(minWidth: 480, minHeight: 300)
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
                        .help(url.path)
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

    // MARK: - Actions

    private func selectFolder() {
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
    }

    private func saveClass() {
        let trimmedName = className.trimmingCharacters(in: .whitespaces)

        if let classToEdit = classToEdit {
            classViewModel.updateClass(
                classToEdit,
                name: trimmedName,
                folderURL: selectedFolderURL
            )
        } else {
            classViewModel.addClass(
                name: trimmedName,
                folderURL: selectedFolderURL
            )
        }

        dismiss()
    }
}

#Preview {
    ClassEditorView(classToEdit: nil)
        .environmentObject(ClassViewModel())
}
