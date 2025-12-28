import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mvp/data/app_db.dart';
import 'package:flutter_mvp/domain/expense_extraction.dart';
import 'package:flutter_mvp/services/download_cancel_token.dart';
import 'package:flutter_mvp/services/ocr/pdf_ocr.dart';
import 'package:flutter_mvp/services/settings_repo.dart';
import 'package:flutter_mvp/services/gemma_runtime.dart';

class ImportPdfScreen extends StatefulWidget {
  const ImportPdfScreen({super.key});

  @override
  State<ImportPdfScreen> createState() => _ImportPdfScreenState();
}

class _ImportPdfScreenState extends State<ImportPdfScreen> {
  final _runtime = GemmaRuntime.instance;
  final _settings = SettingsRepo();
  final _pdfOcr = PdfOcrService();

  String? _pdfPath;
  String _statementText = '';
  String _status = 'Pick a PDF statement to extract transactions locally.';
  bool _busy = false;
  bool _useMock = true;
  bool _isOcring = false;
  DownloadCancelToken? _ocrCancel;
  int? _ocrPage;
  int? _ocrPageCount;

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
      _pdfPath = null;
      _statementText = '';
      _ocrPage = null;
      _ocrPageCount = null;
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
      setState(() {
        _pdfPath = path;
        _statementText = '';
        _status = 'PDF selected. Tap “Run OCR (scanned PDF)”.';
      });
    } catch (e) {
      setState(() => _status = 'PDF extraction failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _runOcr() async {
    final pdfPath = _pdfPath;
    if (pdfPath == null) return;
    setState(() {
      _isOcring = true;
      _status = 'Running OCR…';
      _ocrPage = null;
      _ocrPageCount = null;
      _statementText = '';
    });
    final token = _ocrCancel = DownloadCancelToken();
    final sb = StringBuffer();
    try {
      await for (final p in _pdfOcr.ocrPdfWithProgress(
        pdfPath: pdfPath,
        cancelToken: token,
        onPageText: (pageText) {
          if (pageText.trim().isEmpty) return;
          sb.writeln(pageText);
          sb.writeln('\n');
        },
      )) {
        setState(() {
          _ocrPage = p.page;
          _ocrPageCount = p.pageCount;
          _status = 'OCR page ${p.page}/${p.pageCount}…';
        });
      }
      setState(() {
        _statementText = sb.toString();
        _status = 'OCR complete. Extracted ${_statementText.length} characters.';
      });
    } catch (e) {
      final msg = e is DownloadCancelled ? 'OCR cancelled.' : 'OCR failed: $e';
      setState(() => _status = msg);
    } finally {
      _ocrCancel = null;
      setState(() => _isOcring = false);
    }
  }

  void _cancelOcr() => _ocrCancel?.cancel();

  Future<void> _extractTransactions() async {
    if (_statementText.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _status = 'Extracting transactions…';
      _parsed = [];
      _selected.clear();
    });
    try {
      String jsonStr;
      if (_useMock) {
        jsonStr = _mockExtractStatementJson(_statementText);
      } else {
        final sb = StringBuffer();
        await for (final tok in _runtime.extractStatementJsonStream(_statementText)) {
          sb.write(tok);
        }
        jsonStr = sb.toString();
      }

      final arr = json.decode(_extractJsonArray(jsonStr)) as List<dynamic>;
      final list = arr.whereType<Map>().map((m) => m.map((k, v) => MapEntry(k.toString(), v))).toList();
      setState(() {
        _parsed = list.cast<Map<String, dynamic>>();
        _selected.addAll(List<int>.generate(_parsed.length, (i) => i));
        _status = 'Found ${_parsed.length} candidate transactions.';
      });
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
    final cs = Theme.of(context).colorScheme;
    final preview = _statementText.length > 900 ? '${_statementText.substring(0, 900)}\n…' : _statementText;
    final suggestOcr = (_pdfPath != null) && _statementText.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import'),
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
                    'Bank statement (PDF)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(_status, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _busy ? null : _pickPdf,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Pick PDF'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_isOcring)
                        IconButton.filledTonal(
                          onPressed: _cancelOcr,
                          icon: const Icon(Icons.close),
                          tooltip: 'Cancel OCR',
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: (_busy || _isOcring || !suggestOcr) ? null : _runOcr,
                          icon: const Icon(Icons.document_scanner),
                          label: const Text('Run OCR'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _busy || _statementText.trim().isEmpty ? null : _extractTransactions,
                          child: Text(_busy ? 'Working…' : 'Extract'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy || _selected.isEmpty ? null : _importSelected,
                      child: const Text('Import selected'),
                    ),
                  ),
                  if (_isOcring && _ocrPage != null && _ocrPageCount != null) ...[
                    const SizedBox(height: 12),
                    Text('OCR: $_ocrPage / $_ocrPageCount', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(value: _ocrPageCount == 0 ? null : (_ocrPage! / _ocrPageCount!)),
                    ),
                  ],
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
          if (_statementText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Text preview', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SelectableText(preview, style: const TextStyle(fontFamily: 'monospace')),
                  ],
                ),
              ),
            ),
          ],
          if (_parsed.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Candidates',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...List.generate(_parsed.length, (i) {
              final m = _parsed[i];
              final title = [
                m['amount']?.toString(),
                m['currency']?.toString(),
                m['merchant']?.toString(),
              ].whereType<String>().where((e) => e.isNotEmpty).join(' ');
              final subtitle = (m['notes']?.toString() ?? '').trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: CheckboxListTile(
                    value: _selected.contains(i),
                    controlAffinity: ListTileControlAffinity.leading,
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
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

String _extractJsonArray(String s) {
  final start = s.indexOf('[');
  final end = s.lastIndexOf(']');
  if (start == -1 || end == -1 || end <= start) return '[]';
  return s.substring(start, end + 1);
}

String _mockExtractStatementJson(String statementText) {
  final lines = statementText.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList(growable: false);
  final txs = <Map<String, Object?>>[];
  for (final line in lines) {
    final amountMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(line);
    if (amountMatch == null) continue;
    final amount = double.tryParse(amountMatch.group(1)!);
    if (amount == null) continue;
    txs.add({
      'amount': amount,
      'currency': line.contains('₹') || line.toLowerCase().contains('inr') || line.toLowerCase().contains('rs')
          ? 'INR'
          : (line.contains(r'$') ? 'USD' : null),
      'merchant': null,
      'category': null,
      'date': null,
      'notes': line,
      'confidence': 0.25,
    });
  }
  return const JsonEncoder.withIndent('  ').convert(txs);
}

