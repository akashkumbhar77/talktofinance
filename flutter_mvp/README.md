# Flutter MVP: Privacy-first Edge Expense AI

This folder contains the **Flutter-first MVP** you asked for (Android-first now, expand to iOS later).

## What’s implemented

- **Setup tab**
  - Stores `model_id` + `model_lib`
  - Toggle **Mock extractor** (so the app builds/runs before MLC is wired)
- **Add tab**
  - **Talk to register expense** (speech-to-text)
  - Extracts **transaction JSON** (streamed output) and saves it locally
- **Import tab**
  - Pick a **PDF bank statement**, extract text locally, then extract candidate transactions and import them
- **History tab**
  - Reads saved records from local SQLite and shows JSON

## Running

```bash
cd flutter_mvp
flutter pub get
flutter run
```

## Gemma / MediaPipe integration status

This MVP uses **MediaPipe GenAI via `flutter_gemma`**.

- The “brain” is a **`.task` bundle** (LiteRT/MediaPipe format), downloaded on first run and stored under app documents.
- The app supports a **2-tier strategy**:
  - Tier A: GPU (default)
  - Tier B: CPU fallback (used if GPU fails)

Configure Tier URLs + optional SHA256 verification in the **Setup** tab.

# flutter_mvp

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
