import SwiftUI

struct ContentView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @StateObject private var recordingViewModel = RecordingViewModel()
    @State private var showingClassManagement = false
    @State private var showingAddClass = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Class selector
                if !classViewModel.classes.isEmpty {
                    classSelector
                        .padding()
                }

                Divider()

                // Recording view
                RecordingView(recordingViewModel: recordingViewModel)
                    .padding()

                Divider()

                // Recordings list
                RecordingsListView()
                    .environmentObject(classViewModel)
            }
            .navigationTitle("Class Transcriber")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingClassManagement = true
                        } label: {
                            Label("Manage Classes", systemImage: "folder.badge.gearshape")
                        }

                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingClassManagement) {
                ClassManagementView()
                    .environmentObject(classViewModel)
            }
            .sheet(isPresented: $showingAddClass) {
                ClassEditorView(classToEdit: nil)
                    .environmentObject(classViewModel)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(classViewModel)
            }
            .onAppear {
                if classViewModel.classes.isEmpty {
                    showingAddClass = true
                }
            }
            .toast($recordingViewModel.toastMessage)
        }
    }

    private var classSelector: some View {
        HStack {
            Text("Class:")
                .font(.headline)

            Picker("Select Class", selection: $classViewModel.selectedClass) {
                ForEach(classViewModel.classes) { classModel in
                    Text(classModel.name)
                        .tag(classModel as ClassModel?)
                }
            }
            #if os(macOS)
            .pickerStyle(.menu)
            #else
            .pickerStyle(.menu)
            #endif

            Spacer()

            if let selectedClass = classViewModel.selectedClass,
               selectedClass.folderBookmark != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .help("Folder configured")
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .help("No folder configured")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ClassViewModel())
}
