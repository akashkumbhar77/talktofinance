import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_mvp/core/repositories/transactions_repository.dart';
import 'package:flutter_mvp/core/utils/json_extract.dart';
import 'package:flutter_mvp/domain/expense_extraction.dart';
import 'package:flutter_mvp/features/import_pdf/import_pdf_state.dart';
import 'package:flutter_mvp/services/download_cancel_token.dart';
import 'package:flutter_mvp/services/gemma_runtime.dart';
import 'package:flutter_mvp/services/ocr/pdf_ocr.dart';
import 'package:flutter_mvp/services/settings_repo.dart';

class ImportPdfCubit extends Cubit<ImportPdfState> {
  ImportPdfCubit({
    required SettingsRepo settings,
    required GemmaRuntime runtime,
    required PdfOcrService pdfOcr,
    required TransactionsRepository transactions,
  })  : _settings = settings,
        _runtime = runtime,
        _pdfOcr = pdfOcr,
        _transactions = transactions,
        super(ImportPdfState.initial());

  final SettingsRepo _settings;
  final GemmaRuntime _runtime;
  final PdfOcrService _pdfOcr;
  final TransactionsRepository _transactions;

  DownloadCancelToken? _ocrCancel;

  Future<void> init() async {
    final useMock = await _settings.getUseMockExtractor();
    emit(state.copyWith(prefsLoaded: true, useMockExtractor: useMock));
  }

  /// Useful for tests (and future manual import flows).
  void setStatementText(String text) {
    emit(state.copyWith(statementText: text));
  }

  Future<void> pickPdf() async {
    if (state.busy || state.isOcring) return;

    emit(
      state.copyWith(
        busy: true,
        status: 'Picking PDF…',
        parsed: const [],
        selected: const {},
        statementText: '',
        ocrPage: null,
        ocrPageCount: null,
        clearPdfPath: true,
      ),
    );
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) {
        emit(state.copyWith(status: 'Cancelled.'));
        return;
      }
      final path = result.files.first.path;
      if (path == null) {
        emit(state.copyWith(status: 'Could not read PDF path.'));
        return;
      }
      emit(state.copyWith(pdfPath: path, status: 'PDF selected. Tap “Run OCR”.'));
    } catch (e) {
      emit(state.copyWith(status: 'PDF selection failed: $e'));
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  Future<void> runOcr() async {
    final pdfPath = state.pdfPath;
    if (pdfPath == null || state.isOcring) return;

    emit(
      state.copyWith(
        isOcring: true,
        status: 'Running OCR…',
        statementText: '',
        ocrPage: null,
        ocrPageCount: null,
      ),
    );

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
        emit(
          state.copyWith(
            ocrPage: p.page,
            ocrPageCount: p.pageCount,
            status: 'OCR page ${p.page}/${p.pageCount}…',
          ),
        );
      }
      emit(
        state.copyWith(
          statementText: sb.toString(),
          status: 'OCR complete. Extracted ${sb.length} characters.',
        ),
      );
    } catch (e) {
      final msg = e is DownloadCancelled ? 'OCR cancelled.' : 'OCR failed: $e';
      emit(state.copyWith(status: msg));
    } finally {
      _ocrCancel = null;
      emit(state.copyWith(isOcring: false));
    }
  }

  void cancelOcr() => _ocrCancel?.cancel();

  Future<void> extractTransactions() async {
    if (state.statementText.trim().isEmpty || state.busy) return;

    emit(state.copyWith(busy: true, status: 'Extracting transactions…', parsed: const [], selected: const {}));
    try {
      // Reload current preference (Setup can change it while this cubit is alive).
      final useMock = await _settings.getUseMockExtractor();
      if (useMock != state.useMockExtractor) {
        emit(state.copyWith(useMockExtractor: useMock));
      }

      String jsonStr;
      if (useMock) {
        jsonStr = _mockExtractStatementJson(state.statementText);
      } else {
        final sb = StringBuffer();
        await for (final tok in _runtime.extractStatementJsonStream(state.statementText)) {
          sb.write(tok);
        }
        jsonStr = sb.toString();
      }

      final arr = json.decode(extractJsonArray(jsonStr)) as List<dynamic>;
      final list = arr.whereType<Map>().map((m) => m.map((k, v) => MapEntry(k.toString(), v))).toList();
      final parsed = list.cast<Map<String, dynamic>>();
      final selected = Set<int>.from(List<int>.generate(parsed.length, (i) => i));
      emit(state.copyWith(parsed: parsed, selected: selected, status: 'Found ${parsed.length} candidate transactions.'));
    } catch (e) {
      emit(state.copyWith(status: 'Extract failed: $e'));
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  void toggleSelected(int index, bool selected) {
    final next = Set<int>.from(state.selected);
    if (selected) {
      next.add(index);
    } else {
      next.remove(index);
    }
    emit(state.copyWith(selected: next));
  }

  Future<void> importSelected() async {
    if (state.selected.isEmpty || state.busy) return;

    emit(state.copyWith(busy: true, status: 'Importing…'));
    try {
      var count = 0;
      for (final idx in state.selected) {
        final m = state.parsed[idx];
        final parsed = ExpenseExtraction.fromJson(m);
        await _transactions.addExtraction(
          rawText: (m['notes']?.toString() ?? '').isEmpty ? 'Imported from PDF' : m['notes'].toString(),
          extractedJson: const JsonEncoder.withIndent('  ').convert(m),
          parsed: parsed,
        );
        count++;
      }
      emit(state.copyWith(status: 'Imported $count transactions.'));
    } catch (e) {
      emit(state.copyWith(status: 'Import failed: $e'));
    } finally {
      emit(state.copyWith(busy: false));
    }
  }
}

String _mockExtractStatementJson(String statementText) {
  final lines =
      statementText.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList(growable: false);
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

