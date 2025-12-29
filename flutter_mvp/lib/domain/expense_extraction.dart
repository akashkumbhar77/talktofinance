class ExpenseExtraction {
  final double? amount;
  final String? currency;
  final String? merchant;
  final String? category;
  final String? date; // ISO yyyy-mm-dd when possible
  final String? notes;
  final double? confidence;

  const ExpenseExtraction({
    required this.amount,
    required this.currency,
    required this.merchant,
    required this.category,
    required this.date,
    required this.notes,
    required this.confidence,
  });

  factory ExpenseExtraction.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    String? toStringOrNull(dynamic v) => v?.toString();

    return ExpenseExtraction(
      amount: toDouble(json['amount']),
      currency: toStringOrNull(json['currency']),
      merchant: toStringOrNull(json['merchant']),
      category: toStringOrNull(json['category']),
      date: toStringOrNull(json['date']),
      notes: toStringOrNull(json['notes']),
      confidence: toDouble(json['confidence']),
    );
  }
}

