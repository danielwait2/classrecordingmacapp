# Sponge — Lecture Recording & AI Notes

Record your lectures, get real-time transcripts, and generate AI-powered study notes — all on your Mac.

---

## Requirements

- **macOS 26 (Tahoe)** — required for on-device transcription
- A free **Gemini API key** for AI notes (optional, but recommended — the app walks you through it)

---

## Install (No Xcode needed)

### 1. Download
Go to the [Releases page](https://github.com/danielwaitworksllc/sponge/releases/latest) and download the latest **Sponge-vX.X.zip**.

### 2. Unzip
Double-click the zip to extract **Sponge.app**.

### 3. Remove the security block
macOS will block the app from opening because it isn't from the App Store. Run this one-time command in Terminal to fix it:

```bash
xattr -cr ~/Downloads/Sponge.app
```

> **Where's Terminal?** Press `⌘ Space`, type `Terminal`, hit Enter. Then paste the line above and press Enter.

### 4. Open the app
Double-click **Sponge.app**. The app will walk you through the rest on first launch.

### Updating
After first install, Sponge updates itself automatically — no action needed.

---

## First Launch

Sponge's onboarding covers everything:

1. **Microphone access** — grant permission when prompted (required for recording)
2. **Gemini API key** — get a free key at [aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey), paste it in
3. **Create a class** — name it after your course and pick a folder to save transcripts

---

## Features

- Real-time transcription using Apple SpeechAnalyzer (fully on-device, Voice Memos quality)
- AI-generated class notes, summaries, and recall prompts via Google Gemini
- Class scheduling — Sponge auto-suggests the right class when you open it during class time
- Whisper offline transcription for improved accuracy after recording
- PDF export of transcripts and notes

---

