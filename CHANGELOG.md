# Changelog

## 2026-02-04

### Added
- Visible delete button on each recording row (with confirmation dialog)
- Visible "Show in Finder" button for exported PDFs
- SharedAudioManager for macOS to coordinate audio between recording and transcription
- Debug logging for transcription service to trace audio flow

### Fixed
- Microphone spasming/flickering when running app outside Xcode debug environment on macOS (audio conflict between AVAudioRecorder and AVAudioEngine)
- "Show in Finder" button now correctly locates PDF files (filename format mismatch)
- Live transcription word counter no longer resets every few seconds
- Words no longer disappear during live transcription
- Fixed race condition in legacy mode restart (captures baseTranscript before task cancellation)
- Added text accumulation to modern mode (SpeechAnalyzerService) to preserve words across internal restarts
- Fixed transcription not working on macOS (start transcription before recording to set up buffer handler)
- Cancel recording no longer shows "saved successfully" toast

### Removed
- Post-processing transcription step (now uses live transcript directly)
- Transcribing overlay UI
- `transcriptionProgress` property from services and view model

### Notes
- **Working copy as of 2026-02-04**: Live transcription, recording, and PDF export all functional
