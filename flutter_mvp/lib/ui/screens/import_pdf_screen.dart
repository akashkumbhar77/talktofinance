import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mvp/data/app_db.dart';
import 'package:flutter_mvp/domain/expense_extraction.dart';
import 'package:flutter_mvp/services/mlc_client.dart';
import 'package:flutter_mvp/services/settings_repo.dart';
import 'package:pdf_text/pdf_text.dart';

class ImportPdfScreen extends StatefulWidget {
  const ImportPdfScreen({super.key});

  @override
  State<ImportPdfScreen> createState() => _ImportPdfScreenState();
}

class _ImportPdfScreenState extends State<ImportPdfScreen> {
  final _mlc = MlcClient();
  final _settings = SettingsRepo();

  String _statementText = '';
  String _status = 'Pick a PDF statement to extract transactions locally.';
  bool _busy = false;
  bool _useMock = true;

  List<Map<String, dynamic>> _parsed = [];
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _useMock = await _settings.getUseMockExtractor();
    if (mounted) setState(() {});
  }

  Future<void> _pickPdf() async {
    setState(() {
      _busy = true;
      _status = 'Picking PDF…';
      _parsed = [];
      _selected.clear();
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _status = 'Cancelled.');
        return;
      }
      final path = result.files.first.path;
      if (path == null) {
        setState(() => _status = 'Could not read PDF path.');
        return;
      }
      setState(() => _status = 'Extracting text from PDF…');
      final doc = await PDFDoc.fromFile(File(path));
      final text = await doc.text;
      setState(() {
        _statementText = text;
        _status = 'Extracted ${text.length} characters of text.';
      });
    } catch (e) {
      setState(() => _status = 'PDF extraction failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _extractTransactions() async {
    if (_statementText.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _status = 'Extracting transactions…';
      _parsed = [];
      _selected.clear();
    });
    try {
      final jsonStr = _useMock
          ? MlcClient.mockExtractStatementJson(_statementText)
          : await _mlc.extractTransactionsFromStatement(_statementText);
      final arr = json.decode(jsonStr) as List<dynamic>;
      final list = arr.whereType<Map>().map((m) => m.map((k, v) => MapEntry(k.toString(), v))).toList();
      setState(() {
        _parsed = list.cast<Map<String, dynamic>>();
        _selected.addAll(List<int>.generate(_parsed.length, (i) => i));
        _status = 'Found ${_parsed.length} candidate transactions.';
      });
    } on PlatformException catch (e) {
      setState(() => _status = 'Extract failed: ${e.message ?? e.code}');
    } catch (e) {
      setState(() => _status = 'Extract failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _importSelected() async {
    if (_selected.isEmpty) return;
    setState(() {
      _busy = true;
      _status = 'Importing…';
    });
    try {
      final db = await AppDb.open();
      var count = 0;
      for (final idx in _selected) {
        final m = _parsed[idx];
        final parsed = ExpenseExtraction.fromJson(m);
        await db.insertExtraction(
          rawText: (m['notes']?.toString() ?? '').isEmpty ? 'Imported from PDF' : m['notes'].toString(),
          extractedJson: const JsonEncoder.withIndent('  ').convert(m),
          parsed: parsed,
        );
        count++;
      }
      await db.close();
      setState(() => _status = 'Imported $count transactions.');
    } catch (e) {
      setState(() => _status = 'Import failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _statementText.length > 900 ? '${_statementText.substring(0, 900)}\n…' : _statementText;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Import bank statement (PDF)', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(_status),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _pickPdf,
              icon: const Icon(Icons.upload_file),
              label: const Text('Pick PDF'),
            ),
            FilledButton(
              onPressed: _busy || _statementText.trim().isEmpty ? null : _extractTransactions,
              child: Text(_busy ? 'Working…' : 'Extract transactions'),
            ),
            FilledButton(
              onPressed: _busy || _selected.isEmpty ? null : _importSelected,
              child: const Text('Import selected'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_useMock)
          const Text(
            'Mock extractor enabled (toggle in Setup).',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        if (_statementText.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Text preview:'),
          SelectableText(preview, style: const TextStyle(fontFamily: 'monospace')),
        ],
        if (_parsed.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Candidates (${_parsed.length}):', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...List.generate(_parsed.length, (i) {
            final m = _parsed[i];
            final title = [
              m['amount']?.toString(),
              m['currency']?.toString(),
              m['merchant']?.toString(),
            ].whereType<String>().where((e) => e.isNotEmpty).join(' ');
            final subtitle = (m['notes']?.toString() ?? '').trim();
            return CheckboxListTile(
              value: _selected.contains(i),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selected.add(i);
                  } else {
                    _selected.remove(i);
                  }
                });
              },
              title: Text(title.isEmpty ? 'Transaction ${i + 1}' : title),
              subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            );
          }),
        ],
      ],
    );
  }
}

