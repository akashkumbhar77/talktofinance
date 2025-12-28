import 'package:flutter_mvp/data/app_db.dart';
import 'package:flutter_mvp/domain/expense_extraction.dart';
import 'package:flutter_mvp/domain/transaction.dart';

class TransactionsRepository {
  Future<void> addExtraction({
    required String rawText,
    required String extractedJson,
    required ExpenseExtraction parsed,
  }) async {
    final db = await AppDb.open();
    try {
      await db.insertExtraction(rawText: rawText, extractedJson: extractedJson, parsed: parsed);
    } finally {
      await db.close();
    }
  }

  Future<List<TransactionRecord>> list() async {
    final db = await AppDb.open();
    try {
      return await db.listTransactions();
    } finally {
      await db.close();
    }
  }

  Future<void> clearAll() async {
    final db = await AppDb.open();
    try {
      await db.clearAll();
    } finally {
      await db.close();
    }
  }
}

