import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

class MlcClient {
  static const MethodChannel _ch = MethodChannel('edge_ai/mlc');
  static const EventChannel _events = EventChannel('edge_ai/mlc_stream');

  Stream<String> streamTokens() {
    return _events.receiveBroadcastStream().map((e) => e?.toString() ?? '');
  }

  Future<void> loadModel({required String modelId, required String modelLib}) async {
    await _ch.invokeMethod('loadModel', {'modelId': modelId, 'modelLib': modelLib});
  }

  /// Returns extracted JSON string. Streaming tokens are emitted on [streamTokens].
  Future<String> extractExpenseJson(String input) async {
    final res = await _ch.invokeMethod<String>('extractExpense', {'input': input});
    return res ?? '{}';
  }

  /// Returns JSON array string. Streaming tokens are emitted on [streamTokens].
  Future<String> extractTransactionsFromStatement(String statementText) async {
    final res = await _ch.invokeMethod<String>(
      'extractStatement',
      {'input': statementText},
    );
    return res ?? '[]';
  }

  /// Local-only fallback used when MLC isn’t wired yet.
  static String mockExtractExpenseJson(String input) {
    // Very small heuristic: find first number as amount, infer currency.
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

  static String mockExtractStatementJson(String statementText) {
    // Heuristic: each line with a number becomes a transaction.
    final lines = statementText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);

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
}

