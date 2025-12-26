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

## MLC integration status

Right now the Android side implements the same platform-channel API but uses a **mock** extractor so the project builds without MLC runtime artifacts:

- Dart channels:
  - MethodChannel: `edge_ai/mlc`
  - EventChannel: `edge_ai/mlc_stream`
- Android implementation: `android/app/src/main/kotlin/com/example/flutter_mvp/MainActivity.kt`

To switch to real on-device MLC:

- keep the Dart API as-is (`lib/services/mlc_client.dart`)
- replace the Android methods (`loadModel`, `extractExpense`, `extractStatement`) to call MLC’s `MLCEngine` and stream deltas over `edge_ai/mlc_stream`
- drop the required native runtime artifacts (JNI `.so` + tvm Java runtime jar) into the Android build per MLC docs (`https://llm.mlc.ai/docs/deploy/android.html`)

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
