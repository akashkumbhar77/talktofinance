import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_mvp/core/repositories/transactions_repository.dart';
import 'package:flutter_mvp/core/utils/json_extract.dart';
import 'package:flutter_mvp/domain/expense_extraction.dart';
import 'package:flutter_mvp/features/add_expense/add_expense_state.dart';
import 'package:flutter_mvp/services/gemma_runtime.dart';
import 'package:flutter_mvp/services/ocr/ocr_service.dart';
import 'package:flutter_mvp/services/speech_service.dart';

class AddExpenseCubit extends Cubit<AddExpenseState> {
  AddExpenseCubit({
    required GemmaRuntime runtime,
    required TransactionsRepository transactions,
    SpeechService? speech,
    OcrService? ocr,
  })  : _runtime = runtime,
        _transactions = transactions,
        _speech = speech ?? SpeechService(),
        _ocr = ocr ?? OcrService(),
        super(AddExpenseState.initial());

  final GemmaRuntime _runtime;
  final TransactionsRepository _transactions;
  final SpeechService _speech;
  final OcrService _ocr;

  Future<void> init() async {
    emit(state.copyWith(prefsLoaded: true));
  }

  void setText(String v) => emit(state.copyWith(text: v));

  Future<void> toggleMic() async {
    if (state.busy) return;

    final ok = await _speech.ensureInitialized();
    if (!ok) {
      emit(state.copyWith(error: 'Speech recognizer unavailable on this device.'));
      return;
    }

    if (_speech.isListening) {
      await _speech.stop();
      emit(state.copyWith(isListening: false));
      return;
    }

    emit(state.copyWith(error: null));
    await _speech.start(onResult: (t) {
      emit(state.copyWith(text: t, isListening: true));
    });
    emit(state.copyWith(isListening: true));
  }

  Future<void> pickReceiptImageAndOcr() async {
    if (state.busy) return;

    emit(state.copyWith(busy: true, error: null));
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
      if (text.trim().isEmpty) return;
      emit(state.copyWith(text: text));
    } catch (e) {
      emit(state.copyWith(error: 'OCR failed: $e'));
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  Future<void> extractAndSave() async {
    final input = state.text.trim();
    if (input.isEmpty || state.busy) return;

    emit(state.copyWith(busy: true, error: null, streaming: '', finalJson: ''));

    try {
      final sb = StringBuffer();
      await for (final tok in _runtime.extractExpenseJsonStream(input)) {
        sb.write(tok);
        emit(state.copyWith(streaming: sb.toString()));
      }
      final jsonStr = sb.toString();

      final obj = json.decode(extractJsonObject(jsonStr)) as Map<String, dynamic>;
      final parsed = ExpenseExtraction.fromJson(obj);
      final pretty = const JsonEncoder.withIndent('  ').convert(obj);

      await _transactions.addExtraction(rawText: input, extractedJson: pretty, parsed: parsed);

      emit(state.copyWith(finalJson: pretty));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  @override
  Future<void> close() async {
    // Best-effort cleanup (cubits can outlive screens depending on providers).
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}
    try {
      await _ocr.close();
    } catch (_) {}
    return super.close();
  }
}
