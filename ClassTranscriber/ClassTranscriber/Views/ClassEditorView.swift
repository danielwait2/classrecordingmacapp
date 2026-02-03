import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ClassEditorView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @Environment(\.dismiss) private var dismiss

    let classToEdit: ClassModel?

    @State private var className: String = ""
    @State private var selectedFolderURL: URL?
    @State private var showingFolderPicker = false

    var isEditing: Bool {
        classToEdit != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Class Name") {
                    TextField("Enter class name", text: $className)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                }

                Section("Transcript Folder") {
                    HStack {
                        if let url = selectedFolderURL {
                            VStack(alignment: .leading) {
                                Text(url.lastPathComponent)
                                    .font(.body)
                                Text(url.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        } else {
                            Text("No folder selected")
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Choose...") {
                            selectFolder()
                        }
                    }
                }

                Section {
                    Text("PDFs will be saved to this folder after each recording.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(isEditing ? "Edit Class" : "Add Class")
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
                    .disabled(className.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let classToEdit = classToEdit {
                    className = classToEdit.name
                    selectedFolderURL = classToEdit.resolveFolder()
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showingFolderPicker) {
                FolderPickerView(selectedURL: $selectedFolderURL)
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 250)
        #endif
    }

    private func selectFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Folder"

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
            classViewModel.updateClass(classToEdit, name: trimmedName, folderURL: selectedFolderURL)
        } else {
            classViewModel.addClass(name: trimmedName, folderURL: selectedFolderURL)
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
