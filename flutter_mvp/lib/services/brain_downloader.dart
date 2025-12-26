import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

class BrainDownloader {
  BrainDownloader({FlutterGemmaPlugin? plugin}) : _plugin = plugin ?? FlutterGemmaPlugin.instance;

  final FlutterGemmaPlugin _plugin;

  /// Downloads (or reuses) the model file via flutter_gemma’s model manager.
  /// If [expectedSha256Hex] is provided, verifies the downloaded file hash.
  Stream<int> downloadWithProgress({
    required String url,
    required String? expectedSha256Hex,
  }) async* {
    final mm = _plugin.modelManager;

    // Use the plugin’s downloader (handles large files + stores under app docs dir).
    yield* mm.downloadModelFromNetworkWithProgress(url);

    // Verify hash if requested.
    if (expectedSha256Hex != null && expectedSha256Hex.trim().isNotEmpty) {
      final file = await _resolveDownloadedFile(url);
      final actual = await _sha256OfFile(file);
      final expected = expectedSha256Hex.trim().toLowerCase();
      if (actual != expected) {
        // Remove bad file to avoid mysterious load crashes.
        await mm.deleteModel();
        throw StateError('SHA256 mismatch.\nExpected: $expected\nActual:   $actual');
      }
    }
  }

  Future<File> _resolveDownloadedFile(String url) async {
    final filename = Uri.parse(url).pathSegments.last;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    if (!await file.exists()) {
      throw StateError('Downloaded model not found at ${file.path}');
    }
    return file;
  }

  static Future<String> _sha256OfFile(File f) async {
    final digest = await sha256.bind(f.openRead()).first;
    final sb = StringBuffer();
    for (final b in digest.bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}

