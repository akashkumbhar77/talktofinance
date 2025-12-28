import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mvp/data/app_db.dart';
import 'package:flutter_mvp/domain/expense_extraction.dart';
import 'package:flutter_mvp/services/ocr/ocr_service.dart';
import 'package:flutter_mvp/services/settings_repo.dart';
import 'package:flutter_mvp/services/speech_service.dart';
import 'package:flutter_mvp/services/gemma_runtime.dart';

class VoiceAddScreen extends StatefulWidget {
  const VoiceAddScreen({super.key});

  @override
  State<VoiceAddScreen> createState() => _VoiceAddScreenState();
}

class _VoiceAddScreenState extends State<VoiceAddScreen> {
  final _text = TextEditingController();
  final _speech = SpeechService();
  final _settings = SettingsRepo();
  final _runtime = GemmaRuntime.instance;
  final _ocr = OcrService();

  String _streaming = '';
  String _finalJson = '';
  String? _error;
  bool _busy = false;
  bool _useMock = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _useMock = await _settings.getUseMockExtractor();
    if (mounted) setState(() {});
  }

  Future<void> _toggleMic() async {
    final ok = await _speech.ensureInitialized();
    if (!ok) {
      setState(() => _error = 'Speech recognizer unavailable on this device.');
      return;
    }
    if (_speech.isListening) {
      await _speech.stop();
      setState(() {});
    } else {
      await _speech.start(onResult: (t) {
        setState(() => _text.text = t);
      });
      setState(() {});
    }
  }

  Future<void> _pickReceiptImageAndOcr() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;
      final text = await _ocr.recognizeFilePath(path);
      if (!mounted) return;
      setState(() {
        _text.text = text.trim().isEmpty ? _text.text : text;
      });
    } catch (e) {
      setState(() => _error = 'OCR failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _extractAndSave() async {
    final input = _text.text.trim();
    if (input.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _streaming = '';
      _finalJson = '';
    });

    try {
      if (_useMock) {
        final jsonStr = _mockExtractExpenseJson(input);
        final obj = json.decode(_extractJsonObject(jsonStr)) as Map<String, dynamic>;
        final parsed = ExpenseExtraction.fromJson(obj);

        final db = await AppDb.open();
        await db.insertExtraction(rawText: input, extractedJson: const JsonEncoder.withIndent('  ').convert(obj), parsed: parsed);
        await db.close();

        setState(() => _finalJson = const JsonEncoder.withIndent('  ').convert(obj));
        return;
      }

      // Collect full output.
      final sb = StringBuffer();
      await for (final tok in _runtime.extractExpenseJsonStream(input)) {
        sb.write(tok);
        if (mounted) {
          setState(() => _streaming = sb.toString());
        }
      }
      final full = sb.toString();
      final obj = json.decode(_extractJsonObject(full)) as Map<String, dynamic>;
      final parsed = ExpenseExtraction.fromJson(obj);

      final db = await AppDb.open();
      await db.insertExtraction(rawText: input, extractedJson: const JsonEncoder.withIndent('  ').convert(obj), parsed: parsed);
      await db.close();

      setState(() => _finalJson = const JsonEncoder.withIndent('  ').convert(obj));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _ocr.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Describe an expense',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _text,
                    minLines: 3,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Example: Bought coffee for ₹250 at CCD',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _busy ? null : _toggleMic,
                          icon: Icon(_speech.isListening ? Icons.stop : Icons.mic),
                          label: Text(_speech.isListening ? 'Stop' : 'Talk'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _busy ? null : _pickReceiptImageAndOcr,
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Receipt OCR'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _extractAndSave,
                      child: Text(_busy ? 'Extracting…' : 'Extract & Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_useMock)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                'Mock extractor is enabled in Setup.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: cs.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_streaming.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Streaming', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SelectableText(_streaming, style: const TextStyle(fontFamily: 'monospace')),
                  ],
                ),
              ),
            ),
          ],
          if (_finalJson.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saved', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SelectableText(_finalJson, style: const TextStyle(fontFamily: 'monospace')),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _extractJsonObject(String s) {
  final start = s.indexOf('{');
  final end = s.lastIndexOf('}');
  if (start == -1 || end == -1 || end <= start) return '{}';
  return s.substring(start, end + 1);
}

String _mockExtractExpenseJson(String input) {
  final amountMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(input);
  final amount = amountMatch != null ? double.tryParse(amountMatch.group(1)!) : null;
  final currency = input.contains('₹') || input.toLowerCase().contains('inr') || input.toLowerCase().contains('rs')
      ? 'INR'
      : (input.contains(r'$') ? 'USD' : null);

  final out = <String, Object?>{
    'amount': amount,
    'currency': currency,
    'merchant': null,
    'category': null,
    'date': null,
    'notes': null,
    'confidence': amount == null ? 0.2 : 0.4,
  };
  return const JsonEncoder.withIndent('  ').convert(out);
}

