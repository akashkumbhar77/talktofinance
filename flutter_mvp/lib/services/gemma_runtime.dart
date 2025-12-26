import 'dart:async';

import 'package:flutter_gemma/flutter_gemma_interface.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/core/message.dart';
import 'package:flutter_mvp/services/brain_downloader.dart';
import 'package:flutter_mvp/services/gemma_models.dart';

class GemmaRuntime {
  GemmaRuntime._();

  static final GemmaRuntime instance = GemmaRuntime._();

  final FlutterGemmaPlugin _plugin = FlutterGemmaPlugin.instance;
  final BrainDownloader _downloader = BrainDownloader();

  InferenceModel? _model;
  GemmaTier? _activeTier;

  GemmaTier? get activeTier => _activeTier;

  Future<void> close() async {
    await _model?.close();
    _model = null;
    _activeTier = null;
  }

  /// Ensures the model file is downloaded, then creates an inference model for the given tier.
  Stream<int> prepareTier(GemmaTierConfig tier) async* {
    // If already active with the same tier, skip.
    if (_model != null && _activeTier == tier.tier) return;

    // Close any existing model first.
    await close();

    // Download/verify the task bundle.
    yield* _downloader.downloadWithProgress(url: tier.url, expectedSha256Hex: tier.sha256Hex);

    // Create model (this is the "load" step).
    _model = await _plugin.createModel(
      modelType: ModelType.gemmaIt,
      preferredBackend: tier.backend,
      maxTokens: 1024,
    );
    _activeTier = tier.tier;

    // Warmup to reduce first-token latency.
    final session = await _model!.createSession(temperature: 0.0, topK: 1);
    await session.addQueryChunk(Message.text(text: 'Hi', isUser: true));
    await session.getResponse();
    await session.close();
  }

  /// Best-effort: try GPU tier first, fall back to CPU tier on any error.
  ///
  /// The returned stream yields download progress for whichever tier succeeds.
  Stream<int> prepareAuto({
    required GemmaTierConfig gpu,
    required GemmaTierConfig cpu,
    required void Function(String message) onFallback,
  }) async* {
    try {
      yield* prepareTier(gpu);
    } catch (e) {
      onFallback('GPU tier failed, falling back to CPU: $e');
      yield* prepareTier(cpu);
    }
  }

  /// Streams tokens for a single-shot “extract expense JSON” prompt.
  Stream<String> extractExpenseJsonStream(String input) async* {
    final model = _model;
    if (model == null) throw StateError('Model not loaded. Go to Setup and load Gemma first.');

    final systemPrompt = '''
You are an on-device finance assistant. Extract ONE expense transaction from the user's text.

Return ONLY valid JSON (no markdown, no extra text) matching this schema:
{
  "amount": number|null,
  "currency": string|null,
  "merchant": string|null,
  "category": string|null,
  "date": string|null,
  "notes": string|null,
  "confidence": number|null
}

Rules:
- If unknown, use null and set confidence low (<= 0.4).
- Use ISO date when possible (YYYY-MM-DD).
''';

    final session = await model.createSession(temperature: 0.0, topK: 1);
    try {
      await session.addQueryChunk(Message.systemInfo(text: systemPrompt));
      await session.addQueryChunk(Message.text(text: input, isUser: true));
      yield* session.getResponseAsync();
    } finally {
      await session.close();
    }
  }

  /// Streams tokens for extracting a JSON array of transactions from statement text.
  Stream<String> extractStatementJsonStream(String statementText) async* {
    final model = _model;
    if (model == null) throw StateError('Model not loaded. Go to Setup and load Gemma first.');

    final systemPrompt = '''
You extract bank statement transactions from text.

Return ONLY a JSON array (no markdown, no extra text). Each array element MUST match:
{
  "amount": number|null,
  "currency": string|null,
  "merchant": string|null,
  "category": string|null,
  "date": string|null,
  "notes": string|null,
  "confidence": number|null
}

Rules:
- Extract as many transactions as you can.
- If unsure, set fields to null and confidence low.
''';

    final session = await model.createSession(temperature: 0.0, topK: 1);
    try {
      await session.addQueryChunk(Message.systemInfo(text: systemPrompt));
      await session.addQueryChunk(Message.text(text: statementText, isUser: true));
      yield* session.getResponseAsync();
    } finally {
      await session.close();
    }
  }
}

