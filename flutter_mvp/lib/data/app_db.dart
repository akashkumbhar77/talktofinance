import 'package:flutter_mvp/domain/expense_extraction.dart';
import 'package:flutter_mvp/domain/transaction.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDb {
  AppDb._(this._db);

  final Database _db;

  static Future<AppDb> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'edge_expense.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at_ms INTEGER NOT NULL,
  raw_text TEXT NOT NULL,
  extracted_json TEXT NOT NULL,
  amount REAL NULL,
  currency TEXT NULL,
  merchant TEXT NULL,
  category TEXT NULL,
  date_iso TEXT NULL,
  notes TEXT NULL,
  confidence REAL NULL
);
''');
      },
    );
    return AppDb._(db);
  }

  Future<int> insertExtraction({
    required String rawText,
    required String extractedJson,
    required ExpenseExtraction parsed,
  }) async {
    return _db.insert('transactions', {
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      'raw_text': rawText,
      'extracted_json': extractedJson,
      'amount': parsed.amount,
      'currency': parsed.currency,
      'merchant': parsed.merchant,
      'category': parsed.category,
      'date_iso': parsed.date,
      'notes': parsed.notes,
      'confidence': parsed.confidence,
    });
  }

  Future<List<TransactionRecord>> listTransactions() async {
    final rows = await _db.query('transactions', orderBy: 'created_at_ms DESC');
    return rows.map((r) {
      double? toDouble(Object? v) => v is num ? v.toDouble() : null;
      int toInt(Object? v) => (v as num).toInt();
      String? toStr(Object? v) => v?.toString();

      return TransactionRecord(
        id: toInt(r['id']),
        createdAtEpochMs: toInt(r['created_at_ms']),
        rawText: r['raw_text']!.toString(),
        extractedJson: r['extracted_json']!.toString(),
        amount: toDouble(r['amount']),
        currency: toStr(r['currency']),
        merchant: toStr(r['merchant']),
        category: toStr(r['category']),
        date: toStr(r['date_iso']),
        notes: toStr(r['notes']),
        confidence: toDouble(r['confidence']),
      );
    }).toList(growable: false);
  }

  Future<void> clearAll() => _db.delete('transactions');

  Future<void> close() => _db.close();
}

