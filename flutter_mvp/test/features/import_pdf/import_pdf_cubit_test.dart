import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mvp/features/import_pdf/import_pdf_cubit.dart';
import 'package:flutter_mvp/features/import_pdf/import_pdf_state.dart';

import '../../helpers/mocks.dart';

void main() {
  group('ImportPdfCubit', () {
    late MockSettingsRepo settings;
    late ImportPdfCubit cubit;

    setUp(() {
      settings = MockSettingsRepo();
      when(() => settings.getUseMockExtractor()).thenAnswer((_) async => true);

      cubit = ImportPdfCubit(
        settings: settings,
        runtime: MockGemmaRuntime(),
        pdfOcr: MockPdfOcrService(),
        transactions: MockTransactionsRepository(),
      );
    });

    tearDown(() => cubit.close());

    test('init loads useMockExtractor', () async {
      await cubit.init();
      expect(cubit.state.prefsLoaded, isTrue);
      expect(cubit.state.useMockExtractor, isTrue);
    });

    blocTest<ImportPdfCubit, ImportPdfState>(
      'extractTransactions (mock mode) parses candidates and selects all',
      build: () {
        when(() => settings.getUseMockExtractor()).thenAnswer((_) async => true);
        final c = ImportPdfCubit(
          settings: settings,
          runtime: MockGemmaRuntime(),
          pdfOcr: MockPdfOcrService(),
          transactions: MockTransactionsRepository(),
        );
        c.setStatementText('Line one ₹120\nLine two ₹200\n');
        return c;
      },
      act: (cubit) => cubit.extractTransactions(),
      expect: () => [
        isA<ImportPdfState>().having((s) => s.busy, 'busy', true),
        isA<ImportPdfState>()
            .having((s) => s.busy, 'busy', false)
            .having((s) => s.parsed.length, 'parsed.length', 2)
            .having((s) => s.selected.length, 'selected.length', 2),
      ],
    );
  });
}

