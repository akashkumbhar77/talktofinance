import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_mvp/data/app_db.dart';
import 'package:flutter_mvp/domain/expense_extraction.dart';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Add expense (voice/text)', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _text,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Say or type: “Bought coffee for 250 rupees at CCD”',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _toggleMic,
              icon: Icon(_speech.isListening ? Icons.stop : Icons.mic),
              label: Text(_speech.isListening ? 'Stop' : 'Talk'),
            ),
            FilledButton(
              onPressed: _busy ? null : _extractAndSave,
              child: Text(_busy ? 'Extracting…' : 'Extract & Save'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_useMock)
          const Text(
            'Mock extractor enabled (toggle in Setup).',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        if (_streaming.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Streaming output:'),
          SelectableText(_streaming, style: const TextStyle(fontFamily: 'monospace')),
        ],
        if (_finalJson.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Saved JSON:'),
          SelectableText(_finalJson, style: const TextStyle(fontFamily: 'monospace')),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
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

