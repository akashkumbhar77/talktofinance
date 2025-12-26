# Edge Expense AI — Android MVP (MLC LLM)

This is an Android demo app that:

- runs an on-device SLM via **MLC LLM**
- extracts **strict JSON** from free-form transaction text
- stores results locally via **Room (SQLite)**

## App flow

- **Setup**: select a `model_id` folder and `model_lib`, then `Load + Warmup`
- **Extract**: paste text → see streaming model output → parsed JSON is saved
- **History**: browse saved transactions (local only)

## Required artifacts (not in git)

To build/run, `mlc4j` needs its packaged runtime outputs:

- put MLC Android runtime artifacts under: `mlc4j/output/`
  - a TVM Java runtime JAR (used to satisfy `org.apache.tvm.*` imports)
  - JNI `.so` files under ABI folders (e.g. `output/arm64-v8a/*.so`)

To use a model, you also need a packaged model folder on-device containing:

- `mlc-chat-config.json` (contains `model_lib`)
- `tensor-cache.json` + referenced weight shard files
- tokenizer files referenced by `tokenizer_files`

## Run (device demo)

1. Open `android_mvp/` in Android Studio
2. Sync Gradle (ensure `mlc4j/output/` exists and has the required artifacts)
3. Install on a device
4. Copy your model folder to the app’s external files dir
   - the **Setup** screen shows the exact expected path

Docs reference (MLC): `https://llm.mlc.ai/docs/deploy/android.html`
