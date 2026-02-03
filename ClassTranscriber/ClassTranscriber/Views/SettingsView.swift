import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(classViewModel.classes) { classModel in
                        ClassFolderRow(classModel: classModel, classViewModel: classViewModel)
                    }

                    if classViewModel.classes.isEmpty {
                        Text("No classes added yet")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } header: {
                    Text("PDF Save Locations")
                } footer: {
                    Text("Choose where PDF transcripts are saved for each class. This is typically a folder in your Google Drive.")
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
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 300)
        #endif
    }
}

struct ClassFolderRow: View {
    let classModel: ClassModel
    @ObservedObject var classViewModel: ClassViewModel
    @State private var showingFolderPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(classModel.name)
                    .font(.headline)

                Spacer()

                Button {
                    selectFolder()
                } label: {
                    Label("Change", systemImage: "folder")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            if let folderURL = classModel.resolveFolder() {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)

                    Text(folderURL.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)

                    Text("No folder selected")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
        #if os(iOS)
        .sheet(isPresented: $showingFolderPicker) {
            SettingsFolderPickerView(classModel: classModel, classViewModel: classViewModel)
        }
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
        panel.message = "Choose where to save PDF transcripts for \(classModel.name)"

        if panel.runModal() == .OK, let url = panel.url {
            classViewModel.updateClass(classModel, name: classModel.name, folderURL: url)
        }
        #else
        showingFolderPicker = true
        #endif
    }
}

#if os(iOS)
import UIKit

struct SettingsFolderPickerView: UIViewControllerRepresentable {
    let classModel: ClassModel
    @ObservedObject var classViewModel: ClassViewModel
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
        let parent: SettingsFolderPickerView

        init(_ parent: SettingsFolderPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else { return }

            parent.classViewModel.updateClass(parent.classModel, name: parent.classModel.name, folderURL: url)
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}
#endif

#Preview {
    SettingsView()
        .environmentObject(ClassViewModel())
}
