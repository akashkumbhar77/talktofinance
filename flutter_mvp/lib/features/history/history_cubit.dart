import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_mvp/core/repositories/transactions_repository.dart';
import 'package:flutter_mvp/features/history/history_state.dart';

class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit({required TransactionsRepository transactions})
      : _transactions = transactions,
        super(HistoryState.initial());

  final TransactionsRepository _transactions;

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final items = await _transactions.list();
      emit(state.copyWith(loading: false, items: items, error: null));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> refresh() => load();

  Future<void> clear() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      await _transactions.clearAll();
      final items = await _transactions.list();
      emit(state.copyWith(loading: false, items: items, error: null));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }
}

