# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sponge is a macOS lecture recording and AI-powered transcription app for students. It records lectures, transcribes them in real-time using Apple Speech Recognition, generates AI-enhanced study materials via Google Gemini API, and exports everything to PDF.

**Tech Stack:** SwiftUI + SwiftData (macOS 14+)

## Building & Running

```bash
cd Sponge

# Build for macOS
xcodebuild -scheme Sponge -configuration Debug

# Build and run
xcodebuild -scheme Sponge -configuration Debug -destination "platform=macOS"

# Clean build
xcodebuild -scheme Sponge clean build
```

No external package managers are required (no CocoaPods, SPM dependencies that need installation).

## Architecture & Key Systems

### Core Models (SwiftData)

The app uses SwiftData for persistent storage:

- **SDClass**: A class/course. Stores a unique ID, name, and optional folder bookmark for sandboxed file access.
- **SDRecording**: A lecture recording. Contains audio filename, transcript, user notes, class notes, and metadata.
  - Complex types (IntentMarker, EnhancedSummary, RecallPrompts) are stored as JSON-encoded `Data` fields with computed property accessors
- **Legacy models** (ClassModel, RecordingModel) are kept for migration purposes only; new code targets SwiftData models

Location: `Sponge/Sponge/Models/`

### Audio System

**SharedAudioManager** (singleton) coordinates recording and transcription:
- Manages a single `AVAudioEngine` instance shared between recording and transcription
- Installs a tap on the microphone input to feed audio to speech recognition
- Runs on audio thread for performance; must snapshot state atomically when accessing from other threads
- Uses thread-safe tuple destructuring pattern: `let (a, b) = queue.sync { (self._a, self._b) }`

**Key Files:**
- `SharedAudioManager.swift` — Core audio management
- `AudioRecordingService.swift` — Recording-specific logic
- `TranscriptionService.swift` — Speech recognition integration
- `SpeechAnalyzerService.swift` — Modern transcription mode with text accumulation

**Thread Safety Notes:**
- Audio callbacks run on the audio thread; snapshot state atomically
- Use serial DispatchQueues for safe mutations
- Retry timers: set to 1.0s (was 0.1s, increased for stability)

### AI Integration

**GeminiService** (singleton) generates study materials:
- Generates class notes from transcripts using Google Gemini 2.5 Flash
- Creates enhanced summaries (key concepts, connections to prior knowledge)
- Generates recall prompts for spaced repetition
- Retrieves API key from Keychain (KeychainHelper)
- Stores API responses in SwiftData (JSON-encoded Data fields)

Customizable via:
- Note style (detailed, concise, outline)
- Summary length (brief, comprehensive)

**File:** `Services/GeminiService.swift`

### Data Persistence

**PersistenceService** wraps SwiftData:
- Single shared ModelContainer instance
- Lazy initialization on first access
- Thread-safe configuration

**File:** `Services/PersistenceService.swift`

### PDF Export

**PDFExportService**:
- Exports transcripts, user notes, and AI-generated materials as PDF
- Runs on background queue; uses Main Actor for UI updates
- Handles folder resolution with sandboxed file access

**File:** `Services/PDFExportService.swift`

### View Architecture

**View Models:**
- `ClassViewModel` — Manages classes and recordings; SwiftData queries
- `RecordingViewModel` — Manages a single recording and AI generation

**Key Views:**
- `ContentView` — Main app container
- `RecordingsListView` — List of recordings with delete/export
- `RecordingView` — Live recording with live transcript display
- `RecordingDetailView` — Post-recording detail page
- `EnhancedSummaryView` — AI-generated summary display
- `RecallPromptsView` — Interactive spaced repetition prompts
- `ClassManagementView` — Class CRUD
- `SettingsView` — API key configuration

## SwiftData Patterns in This Codebase

1. **Complex Type Storage**: Classes like `IntentMarker`, `EnhancedSummary`, `RecallPrompts` are JSON-encoded to `Data` with computed property accessors:
   ```swift
   @Model final class SDRecording {
       var enhancedSummaryData: Data?

       var enhancedSummary: EnhancedSummary? {
           get { enhancedSummaryData.flatMap { try? JSONDecoder().decode(EnhancedSummary.self, from: $0) } }
           set { enhancedSummaryData = try? JSONEncoder().encode(newValue) }
       }
   }
   ```

2. **Reference Semantics**: `@Model` classes are reference types—no need for `inout` when modifying.

3. **Relationship Management**: Use `@Relationship(deleteRule: .cascade)` to handle cascading deletes (e.g., deleting a class deletes its recordings).

## Important Implementation Details

### Sandboxed File Access

macOS apps using the Sandbox entitlement require security-scoped bookmarks for persistent folder access:
- `SDClass.resolveFolder()` restores URLs from bookmarks
- `SDClass.createBookmark()` creates new bookmarks
- Always resolve bookmarks; they can become stale

### UI Isolation

- `@MainActor` is heavily used for UI updates
- When non-MainActor code calls MainActor methods, wrap in: `Task { @MainActor in ... }`
- PDFExportService example: dispatches to main thread for UI updates from background queue

### Transcription Flow

1. **Start Transcription**: Before recording begins (not after)
2. **Audio Routing**: Microphone input → SharedAudioManager tap → SpeechAnalyzerService
3. **Text Accumulation**: Text persists across internal restarts via `SpeechAnalyzerService.accumulatedText`
4. **Format**: M4A/AAC (sandboxed app compatibility requirement)

### Diagnostics

- SourceKit cross-file diagnostics during editing are often false positives; always verify with actual `xcodebuild`
- Review actual build output before investigating SourceKit errors

## Code Organization

```
Sponge/Sponge/
├── SpongeApp.swift                      # Entry point, app-level setup
├── Models/
│   ├── SpongeDataModels.swift           # SDClass, SDRecording (SwiftData)
│   ├── ClassModel.swift                 # Legacy (migration only)
│   ├── RecordingModel.swift             # Legacy (migration only)
│   ├── IntentMarker.swift               # AI feature: lecture intent markers
│   ├── EnhancedSummary.swift            # AI feature: enhanced summaries
│   ├── NoteStyle.swift                  # Note customization
│   ├── SaveDestination.swift            # Enum: where to save
├── Services/
│   ├── SharedAudioManager.swift         # Audio engine coordinator
│   ├── AudioRecordingService.swift      # Recording logic
│   ├── TranscriptionService.swift       # Legacy transcription (Apple Speech)
│   ├── SpeechAnalyzerService.swift      # Modern transcription with accumulation
│   ├── GeminiService.swift              # AI note generation
│   ├── PersistenceService.swift         # SwiftData setup
│   ├── PDFExportService.swift           # PDF generation
│   ├── CalendarService.swift            # Calendar event creation
│   ├── KeychainHelper.swift             # Secure API key storage
│   └── TranscriptionServiceProtocol.swift # Interface
├── ViewModels/
│   ├── ClassViewModel.swift
│   └── RecordingViewModel.swift
├── Views/
│   ├── ContentView.swift
│   ├── RecordingsListView.swift
│   ├── RecordingView.swift
│   ├── RecordingDetailView.swift
│   ├── ClassManagementView.swift
│   ├── ClassEditorView.swift
│   ├── SettingsView.swift
│   ├── ToastView.swift
│   ├── Components/
│   │   └── MarkdownNotesEditor.swift
│   └── PostLecture/
│       ├── EnhancedSummaryView.swift
│       ├── RecallPromptsView.swift
│       ├── IntentMarkerBar.swift
│       └── WhatDidIMissButton.swift
└── Utils/
    ├── MarkdownParser.swift
    ├── DesignSystemComponents.swift
    ├── SpongeTheme.swift
    └── NoteStyle.swift
```

## Common Development Tasks

### Adding a New AI Feature

1. Add a new model type (e.g., struct conforming to Codable) in Models/
2. Add a stored Data field to SDRecording (e.g., `var myFeatureData: Data?`)
3. Add a computed property accessor to decode/encode
4. Add a generation method to GeminiService
5. Call from RecordingViewModel after recording stops
6. Create a view to display the results

### Modifying Audio Flow

- Review SharedAudioManager first to understand the audio tap setup
- Changes to audio format require updating AudioRecordingService settings
- Test on actual macOS (not just Xcode preview)

### Testing UI Changes

- Use Xcode preview with mock data when possible
- Test on macOS (not iOS) since app is macOS-only
- Recent work stripped iOS code paths; don't re-add platform checks

## Recent Changes (Feb 2026)

- **Pass 3 (Feb 7)**: Removed all Google Drive integration; migrated remaining UserDefaults to SwiftData
- **Pass 2 (Feb 5)**: Removed GoogleAuthService, GoogleDriveService, GoogleSignInView, GoogleDriveFolderPicker
- **Pass 1 (Feb 4)**: Thread safety improvements, retry timing, caching, parallel AI calls
- **Latest Features**: Intent markers, enhanced summaries, recall prompts, user notes with live markdown editor

See CHANGELOG.md for full details.

## Deployment Target

- **macOS**: 14.0 minimum
- **iOS**: Not actively developed (code cleanup removed iOS-specific paths)
