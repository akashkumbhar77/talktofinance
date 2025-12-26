import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_mvp/services/device_storage.dart';
import 'package:flutter_mvp/services/download_cancel_token.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class BrainDownloader {
  /// Downloads (with resume) a model file into app documents dir.
  ///
  /// - Uses `*.partial` temp file and atomic rename on success.
  /// - Supports HTTP Range resume when server supports it.
  /// - Validates Content-Length (when available) and SHA-256 (when provided).
  Stream<int> downloadWithProgress({
    required String url,
    required String? expectedSha256Hex,
    required String localFileName,
    int maxAttempts = 4,
    DownloadCancelToken? cancelToken,
    void Function(int attempt, Object error, Duration nextDelay)? onRetry,
  }) async* {
    final finalFile = await resolveLocalFile(localFileName);
    final partialFile = File('${finalFile.path}.partial');

    if (cancelToken?.isCancelled == true) throw DownloadCancelled();

    // If already downloaded, just verify and return 100.
    if (await finalFile.exists()) {
      await _verifyFile(finalFile, expectedSha256Hex: expectedSha256Hex, expectedLength: null);
      yield 100;
      return;
    }

    final totalBytes = await _tryGetContentLength(url);

    // Preflight disk space (best-effort).
    if (totalBytes != null && totalBytes > 0) {
      final freeBytes = await DeviceStorage.tryGetFreeDiskBytes();
      if (freeBytes != null) {
        // Require ~2x file size free to avoid OS / temp space issues.
        final required = totalBytes * 2;
        if (freeBytes < required) {
          throw StateError('Insufficient storage. Need ~${(required / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB free.');
        }
      }
    }

    // Download with retries.
    var attempt = 0;
    while (true) {
      if (cancelToken?.isCancelled == true) throw DownloadCancelled();
      attempt++;
      try {
        yield* _downloadOnce(
          url: url,
          totalBytes: totalBytes,
          partialFile: partialFile,
          cancelToken: cancelToken,
        );

        // Finalize.
        await partialFile.rename(finalFile.path);

        // Validate file size + hash.
        await _verifyFile(finalFile, expectedSha256Hex: expectedSha256Hex, expectedLength: totalBytes);
        yield 100;
        return;
      } catch (e) {
        if (e is DownloadCancelled) rethrow;
        if (attempt >= maxAttempts) rethrow;
        // Exponential backoff.
        final delay = Duration(seconds: 1 << (attempt - 1));
        onRetry?.call(attempt, e, delay);
        await Future<void>.delayed(delay);
      }
    }
  }

  Future<File> resolveLocalFile(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  static Future<void> _verifyFile(
    File f, {
    required String? expectedSha256Hex,
    required int? expectedLength,
  }) async {
    if (expectedLength != null && expectedLength > 0) {
      final len = await f.length();
      if (len != expectedLength) {
        throw StateError('File length mismatch. Expected $expectedLength, got $len');
      }
    }

    if (expectedSha256Hex != null && expectedSha256Hex.trim().isNotEmpty) {
      final actual = await _sha256OfFile(f);
      final expected = expectedSha256Hex.trim().toLowerCase();
      if (actual != expected) {
        throw StateError('SHA256 mismatch.\nExpected: $expected\nActual:   $actual');
      }
    }
  }

  static Future<String> _sha256OfFile(File f) async {
    final digest = await sha256.bind(f.openRead()).first;
    final sb = StringBuffer();
    for (final b in digest.bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static Future<int?> _tryGetContentLength(String url) async {
    try {
      final res = await http.head(Uri.parse(url));
      final len = res.headers['content-length'];
      if (len == null) return null;
      return int.tryParse(len);
    } catch (_) {
      return null;
    }
  }

  static Stream<int> _downloadOnce({
    required String url,
    required int? totalBytes,
    required File partialFile,
    required DownloadCancelToken? cancelToken,
  }) async* {
    await partialFile.parent.create(recursive: true);

    var existing = 0;
    if (await partialFile.exists()) {
      existing = await partialFile.length();
    }

    final client = http.Client();
    try {
      if (cancelToken?.isCancelled == true) throw DownloadCancelled();

      // If we know total size and already complete, skip.
      if (totalBytes != null && totalBytes > 0 && existing >= totalBytes) {
        yield 100;
        return;
      }

      final req = http.Request('GET', Uri.parse(url));
      if (existing > 0) {
        req.headers['Range'] = 'bytes=$existing-';
      }
      final resp = await client.send(req);

      // Range resume: expect 206. If server ignores Range and returns 200, restart.
      if (existing > 0 && resp.statusCode == 200) {
        await partialFile.delete();
        existing = 0;
      } else if (resp.statusCode != 200 && resp.statusCode != 206) {
        throw StateError('Download failed: HTTP ${resp.statusCode}');
      }

      final sink = partialFile.openWrite(mode: existing > 0 ? FileMode.append : FileMode.write);
      var downloaded = existing;
      try {
        await for (final chunk in resp.stream) {
          if (cancelToken?.isCancelled == true) {
            client.close();
            throw DownloadCancelled();
          }
          sink.add(chunk);
          downloaded += chunk.length;
          if (totalBytes != null && totalBytes > 0) {
            final pct = ((downloaded / totalBytes) * 100).clamp(0, 99).toInt();
            yield pct;
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
    } finally {
      client.close();
    }
  }
}

