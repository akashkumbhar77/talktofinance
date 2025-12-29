# Edge Expense AI (Android MVP)

This repo contains an **Android-first, privacy-first** demo that runs an on-device SLM via **MLC LLM** to extract a transaction JSON from free-form text and stores it **locally** (Room/SQLite).

## What’s included

- **Android app**: `android_mvp/`
  - **Setup** screen: point the app at a packaged MLC model folder + `model_lib`
  - **Extract** screen: paste SMS/OCR/text → streams model output → saves parsed JSON locally
  - **History** screen: lists saved extractions from local DB

## Prereqs (for a real device demo)

You need two things that are **not committed** here:

- **MLC Android runtime artifacts** for `mlc4j` (TVM Java + native `.so` files)
  - These must be placed under: `android_mvp/mlc4j/output/`
- A **packaged MLC model folder** (the “AI brain”) containing:
  - `mlc-chat-config.json` (contains `model_lib`)
  - `tensor-cache.json` + referenced weight shards
  - tokenizer files referenced by `tokenizer_files`

## Run the demo

1. Open `android_mvp/` in Android Studio and sync Gradle.
2. Ensure `android_mvp/mlc4j/output/` contains the required runtime JAR(s) and JNI libs.
3. Install the app on a device.
4. Push your packaged model folder to the app’s external files directory.
   - The app shows the exact expected path on the **Setup** screen.
5. In the app:
   - **Setup** → `Load + Warmup`
   - **Extract** → paste text like `Bought coffee for 250 rupees at CCD today` → `Extract & Save`

