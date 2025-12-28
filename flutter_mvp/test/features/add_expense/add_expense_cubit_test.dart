import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mvp/domain/expense_extraction.dart';
import 'package:flutter_mvp/features/add_expense/add_expense_cubit.dart';
import 'package:flutter_mvp/features/add_expense/add_expense_state.dart';

import '../../helpers/mocks.dart';

void main() {
  group('AddExpenseCubit', () {
    late MockSettingsRepo settings;
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
      settings = MockSettingsRepo();
      transactions = MockTransactionsRepository();
    });

    blocTest<AddExpenseCubit, AddExpenseState>(
      'init loads useMockExtractor',
      build: () {
        when(() => settings.getUseMockExtractor()).thenAnswer((_) async => true);
        return AddExpenseCubit(
          settings: settings,
          runtime: MockGemmaRuntime(),
          transactions: transactions,
        );
      },
      act: (cubit) => cubit.init(),
      expect: () => [
        AddExpenseState.initial().copyWith(prefsLoaded: true, useMockExtractor: true),
      ],
    );

    blocTest<AddExpenseCubit, AddExpenseState>(
      'extractAndSave (mock mode) emits finalJson and stores to repository',
      build: () {
        when(() => settings.getUseMockExtractor()).thenAnswer((_) async => true);
        when(
          () => transactions.addExtraction(
            rawText: any(named: 'rawText'),
            extractedJson: any(named: 'extractedJson'),
            parsed: any(named: 'parsed'),
          ),
        ).thenAnswer((_) async {});
        return AddExpenseCubit(
          settings: settings,
          runtime: MockGemmaRuntime(),
          transactions: transactions,
        );
      },
      seed: () => AddExpenseState.initial().copyWith(prefsLoaded: true, useMockExtractor: true, text: 'coffee 250 rs'),
      act: (cubit) => cubit.extractAndSave(),
      verify: (_) {
        verify(
          () => transactions.addExtraction(
            rawText: any(named: 'rawText'),
            extractedJson: any(named: 'extractedJson'),
            parsed: any(named: 'parsed'),
          ),
        ).called(1);
      },
      expect: () => [
        // busy=true
        isA<AddExpenseState>().having((s) => s.busy, 'busy', true),
        // busy=false + finalJson present
        isA<AddExpenseState>().having((s) => s.busy, 'busy', false).having((s) => s.finalJson.isNotEmpty, 'finalJson', true),
      ],
    );
  });
}

