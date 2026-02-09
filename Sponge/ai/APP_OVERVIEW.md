# Sponge - Lecture Recording & Learning Companion

## What It Is
Sponge is a macOS/iOS app that helps students capture, transcribe, and learn from lectures. It transforms passive note-taking into active learning through AI-powered features.

## Core Value Proposition
"Record your lecture, get AI-powered notes, and actually remember what you learned."

---

## Key Features

### 1. Recording & Live Transcription
- Records audio while transcribing in real-time using Apple's Speech Recognition
- User can take markdown notes alongside the live transcript
- Supports pause/resume during recording

### 2. Intent Markers (During Recording)
Four one-tap buttons to mark significant moments:
- **Confused** (?) - "I don't understand this"
- **Important** (!) - "This seems key"
- **Exam** (★) - "This will be on the test"
- **Review Later** (▸) - "Come back to this"

Each marker captures timestamp + ~30 words of transcript context.

### 3. "What Did I Miss?" (During Recording)
Floating button that generates a quick AI catch-up summary covering the last ~2.5 minutes. For when you zone out and need to get back on track.

### 4. AI Class Notes (Post-Recording)
Gemini AI generates structured notes with:
- Overview, Key Concepts, Detailed Notes, Action Items
- Customizable styles: Detailed, Concise, Bullet Points, Study Guide, Cornell, Outline
- Customizable length: Quick, Medium, Comprehensive

### 5. Enhanced Summaries (Post-Recording)
- **General Overview** - Always generated
- **Confusion-Focused** - Only if confused markers exist; clarifies those moments
- **Exam-Oriented** - Only if exam/important markers exist; highlights testable material

### 6. Recall Prompts (Post-Recording)
AI-generated practice questions (6-10 per lecture) across four types:
- Definition ("What is...?")
- Conceptual ("Why/How does...?")
- Applied ("How would you use...?")
- Connection ("How does X relate to Y?")

Two viewing modes: List (grouped, tap to reveal answer) and Flashcard (swipe through, tap to flip).

### 7. PDF Export
Auto-exports notes to:
- Local folder (user-selected)
- Google Drive (with OAuth integration)
- Or both

### 8. Class Organization
- Create classes with custom save destinations
- Recordings organized by class
- Each recording shows: duration, word count, marker count, recall question count

---

## Technical Architecture

### Platform
- SwiftUI (macOS 14+ / iOS 17+)
- Universal app (shared codebase with platform conditionals)

### Key Services
| Service | Purpose |
|---------|---------|
| `AudioRecordingService` | Records audio to .m4a files |
| `TranscriptionService` | Live speech-to-text via SFSpeechRecognizer |
| `GeminiService` | AI generation (notes, summaries, recall prompts, catch-up) |
| `GoogleAuthService` | OAuth for Google Drive |
| `GoogleDriveService` | Upload PDFs to Drive |
| `PDFExportService` | Generate PDF from transcript + notes |

### Data Models
| Model | Purpose |
|-------|---------|
| `ClassModel` | Class name, save destination, folder references |
| `RecordingModel` | Audio file, transcript, notes, markers, summaries, prompts |
| `IntentMarker` | Type, timestamp, transcript snapshot |
| `EnhancedSummary` | General, confusion-focused, exam-oriented summaries |
| `RecallPrompts` | Collection of RecallQuestion objects |
| `CatchUpSummary` | Time range + summary text |

### Persistence
- `UserDefaults` for classes and recordings (JSON encoded)
- `Keychain` for Gemini API key
- File system for audio files (`Documents/Recordings/`)
- Secure bookmarks for user-selected local folders

### View Structure
```
ContentView (3-column layout)
├── ClassManagementView (sidebar)
├── RecordingView (main - recording UI)
│   ├── IntentMarkerBar
│   ├── Transcript display
│   ├── WhatDidIMissButton
│   └── MarkdownNotesEditor
├── RecordingsListView (detail)
│   └── RecordingDetailView (sheet)
│       ├── Transcript tab
│       ├── Summaries tab (EnhancedSummaryView)
│       ├── Recall tab (RecallPromptsView)
│       └── Markers tab
└── SettingsView (sheet)
```

---

## External Dependencies
- **Gemini API** (Google AI) - All AI generation
- **Google OAuth** - Drive integration
- **Apple Speech Framework** - Transcription

## Current API Key Handling
User enters their own Gemini API key in Settings, stored in Keychain. For distribution, consider a backend proxy (see planning discussions).

---

## Design Language
- **Primary color**: Coral (#FF7F66)
- **Secondary**: Cream (#FCF1E3)
- **Style**: Clean, geometric, friendly
- **Theme file**: `Utils/SpongeTheme.swift`

---

## File Counts (as of Feb 2026)
- ~15 Swift files in Views/
- ~7 Swift files in Services/
- ~5 Swift files in Models/
- ~2 Swift files in ViewModels/
- ~3 Swift files in Utils/
- Total: ~8,000+ lines of Swift
