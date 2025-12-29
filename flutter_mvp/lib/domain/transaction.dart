class TransactionRecord {
  final int id;
  final int createdAtEpochMs;
  final String rawText;
  final String extractedJson;
  final double? amount;
  final String? currency;
  final String? merchant;
  final String? category;
  final String? date;
  final String? notes;
  final double? confidence;

  const TransactionRecord({
    required this.id,
    required this.createdAtEpochMs,
    required this.rawText,
    required this.extractedJson,
    required this.amount,
    required this.currency,
    required this.merchant,
    required this.category,
    required this.date,
    required this.notes,
    required this.confidence,
  });
}

