import SwiftUI

struct ClassManagementView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddClass = false
    @State private var classToEdit: ClassModel?

    var body: some View {
        NavigationStack {
            List {
                if classViewModel.classes.isEmpty {
                    Text("No classes yet. Add your first class to get started.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(classViewModel.classes) { classModel in
                        ClassRowView(classModel: classModel) {
                            classToEdit = classModel
                        }
                    }
                    .onDelete(perform: deleteClasses)
                }
            }
            .navigationTitle("Manage Classes")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddClass = true
                    } label: {
                        Label("Add Class", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddClass) {
                ClassEditorView(classToEdit: nil)
                    .environmentObject(classViewModel)
            }
            .sheet(item: $classToEdit) { classModel in
                ClassEditorView(classToEdit: classModel)
                    .environmentObject(classViewModel)
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        #endif
    }

    private func deleteClasses(at offsets: IndexSet) {
        for index in offsets {
            classViewModel.deleteClass(classViewModel.classes[index])
        }
    }
}

struct ClassRowView: View {
    let classModel: ClassModel
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(classModel.name)
                    .font(.headline)

                if let folderURL = classModel.resolveFolder() {
                    Text(folderURL.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No folder configured")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil.circle")
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ClassManagementView()
        .environmentObject(ClassViewModel())
}
