import 'package:flutter_gemma/pigeon.g.dart';

enum GemmaTier { gpu, cpu }

class GemmaTierConfig {
  final GemmaTier tier;
  final PreferredBackend backend;
  final String url;
  final String? sha256Hex; // optional but strongly recommended

  const GemmaTierConfig({
    required this.tier,
    required this.backend,
    required this.url,
    required this.sha256Hex,
  });
}

/// Default URLs based on flutter_gemma’s published model list (can be overridden in-app).
class GemmaDefaultTiers {
  static const gpu = GemmaTierConfig(
    tier: GemmaTier.gpu,
    backend: PreferredBackend.gpu,
    // Gemma 3 1B IT (LiteRT/MediaPipe task bundle)
    url: 'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task',
    sha256Hex: null,
  );

  /// CPU fallback: you may need a CPU-tuned .task bundle.
  /// If you only have one .task, you can keep the same URL but switch backend to CPU.
  static const cpu = GemmaTierConfig(
    tier: GemmaTier.cpu,
    backend: PreferredBackend.cpu,
    url: 'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task',
    sha256Hex: null,
  );
}

