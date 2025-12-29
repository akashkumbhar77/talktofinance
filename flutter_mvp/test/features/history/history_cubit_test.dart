import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mvp/domain/transaction.dart';
import 'package:flutter_mvp/features/history/history_cubit.dart';
import 'package:flutter_mvp/features/history/history_state.dart';

import '../../helpers/mocks.dart';

void main() {
  group('HistoryCubit', () {
    late MockTransactionsRepository repo;

    blocTest<HistoryCubit, HistoryState>(
      'load emits items',
      build: () {
        final repo = MockTransactionsRepository();
        when(() => repo.list()).thenAnswer(
          (_) async => const [
            TransactionRecord(
              id: 1,
              createdAtEpochMs: 0,
              rawText: 'Bought coffee',
              extractedJson: '{}',
              amount: 250,
              currency: 'INR',
              merchant: 'CCD',
              category: 'Food',
              date: '2025-01-01',
              notes: null,
              confidence: 0.5,
            ),
          ],
        );
        return HistoryCubit(transactions: repo);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const HistoryState(loading: true, items: <TransactionRecord>[], error: null),
        const HistoryState(
          loading: false,
          items: [
            TransactionRecord(
              id: 1,
              createdAtEpochMs: 0,
              rawText: 'Bought coffee',
              extractedJson: '{}',
              amount: 250,
              currency: 'INR',
              merchant: 'CCD',
              category: 'Food',
              date: '2025-01-01',
              notes: null,
              confidence: 0.5,
            ),
          ],
          error: null,
        ),
      ],
    );

    blocTest<HistoryCubit, HistoryState>(
      'clear calls repository and reloads',
      build: () {
        repo = MockTransactionsRepository();
        when(() => repo.clearAll()).thenAnswer((_) async {});
        when(() => repo.list()).thenAnswer((_) async => const <TransactionRecord>[]);
        return HistoryCubit(transactions: repo);
      },
      act: (cubit) => cubit.clear(),
      verify: (_) {
        verify(() => repo.clearAll()).called(1);
        verify(() => repo.list()).called(1);
      },
    );
  });
}

