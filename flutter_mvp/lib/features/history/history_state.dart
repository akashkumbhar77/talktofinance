import 'package:equatable/equatable.dart';
import 'package:flutter_mvp/domain/transaction.dart';

class HistoryState extends Equatable {
  final bool loading;
  final List<TransactionRecord> items;
  final String? error;

  const HistoryState({
    required this.loading,
    required this.items,
    required this.error,
  });

  factory HistoryState.initial() => const HistoryState(loading: true, items: <TransactionRecord>[], error: null);

  HistoryState copyWith({
    bool? loading,
    List<TransactionRecord>? items,
    String? error,
  }) {
    return HistoryState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      error: error,
    );
  }

  @override
  List<Object?> get props => [loading, items, error];
}

