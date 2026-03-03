# Changelog

## 2026-03-02
Added XCUITest target with 7 UI tests covering app launch, main window, settings, recording detail tabs, and the Regenerate AI Notes button. Added autonomous development workflow to CLAUDE.md so builds, code reviews, and tests run automatically after every change.

## 2026-03-02
Added "Regenerate AI Notes" button to the recording detail view, allowing students to retry AI note generation for recordings where it failed (e.g. closed laptop, bad API key). Fixed live UI updates after regeneration by switching SDRecording bindings to `@Bindable` in detail, summary, and recall views.

## 2026-03-02
Updated CLAUDE.md to reflect macOS 26 deployment target and SpeechAnalyzer API details. Removed `@available(macOS 26.0, *)` annotation from SpeechAnalyzerService (redundant given min target). Deleted stale CHANGELOG.md and convert-docs.py scripts.
