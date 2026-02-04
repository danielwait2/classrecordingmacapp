# Changelog

## 2026-02-04

### Added
- Visible delete button on each recording row (with confirmation dialog)
- Visible "Show in Finder" button for exported PDFs

### Fixed
- Live transcription word counter no longer resets every few seconds
- Words no longer disappear during live transcription
- Fixed race condition in legacy mode restart (captures baseTranscript before task cancellation)
- Added text accumulation to modern mode (SpeechAnalyzerService) to preserve words across internal restarts

### Removed
- Post-processing transcription step (now uses live transcript directly)
- Transcribing overlay UI
- `transcriptionProgress` property from services and view model
