import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mvp/domain/expense_extraction.dart';
import 'package:flutter_mvp/features/add_expense/add_expense_cubit.dart';
import 'package:flutter_mvp/features/add_expense/add_expense_state.dart';

import '../../helpers/mocks.dart';

void main() {
  group('AddExpenseCubit', () {
    late MockTransactionsRepository transactions;

    setUpAll(() {
      registerFallbackValue(const ExpenseExtraction(
        amount: null,
        currency: null,
        merchant: null,
        category: null,
        date: null,
        notes: null,
        confidence: null,
      ));
    });

    setUp(() {
      transactions = MockTransactionsRepository();
    });

    blocTest<AddExpenseCubit, AddExpenseState>(
      'init marks prefsLoaded',
      build: () {
        return AddExpenseCubit(
          runtime: MockGemmaRuntime(),
          transactions: transactions,
        );
      },
      act: (cubit) => cubit.init(),
      expect: () => [
        AddExpenseState.initial().copyWith(prefsLoaded: true),
      ],
    );

    blocTest<AddExpenseCubit, AddExpenseState>(
      'extractAndSave emits error if model not loaded',
      build: () {
        return AddExpenseCubit(
          runtime: MockGemmaRuntime(),
          transactions: transactions,
        );
      },
      seed: () => AddExpenseState.initial().copyWith(prefsLoaded: true, text: 'coffee 250 rs'),
      act: (cubit) => cubit.extractAndSave(),
      expect: () => [
        // busy=true
        isA<AddExpenseState>().having((s) => s.busy, 'busy', true),
        // busy=false + error present (because runtime isn't loaded in this unit test)
        isA<AddExpenseState>().having((s) => s.busy, 'busy', false).having((s) => s.error != null, 'error', true),
      ],
    );
  });
}

