import SwiftUI

struct ContentView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @StateObject private var recordingViewModel = RecordingViewModel()
    @State private var showingClassManagement = false
    @State private var showingAddClass = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Main recording area
                    RecordingView(recordingViewModel: recordingViewModel)
                        .frame(minHeight: max(geometry.size.height * 0.35, 300), idealHeight: geometry.size.height * 0.42)
                        .layoutPriority(1)
                        .background(Color.white)

                    // Divider with coral accent
                    Rectangle()
                        .fill(SpongeTheme.coral.opacity(0.2))
                        .frame(height: 2)

                    // Recordings list
                    RecordingsListView()
                        .environmentObject(classViewModel)
                        .frame(minHeight: 200)
                        .background(Color.white)
                }
            }
            .background(SpongeTheme.backgroundCoral.opacity(0.05))
            .navigationTitle("Sponge")
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

                        Divider()

                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
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
}

// MARK: - Color Extensions

extension Color {
    static var primaryBackground: Color {
        #if os(macOS)
        Color(NSColor.windowBackgroundColor)
        #else
        Color(UIColor.systemBackground)
        #endif
    }

    static var secondaryBackground: Color {
        #if os(macOS)
        Color(NSColor.controlBackgroundColor)
        #else
        Color(UIColor.secondarySystemBackground)
        #endif
    }

    static var tertiaryBackground: Color {
        #if os(macOS)
        Color(NSColor.textBackgroundColor)
        #else
        Color(UIColor.tertiarySystemBackground)
        #endif
    }
}

#Preview {
    ContentView()
        .environmentObject(ClassViewModel())
}
