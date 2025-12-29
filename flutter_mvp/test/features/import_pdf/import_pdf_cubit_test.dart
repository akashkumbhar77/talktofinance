import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mvp/features/import_pdf/import_pdf_cubit.dart';
import 'package:flutter_mvp/features/import_pdf/import_pdf_state.dart';

import '../../helpers/mocks.dart';

void main() {
  group('ImportPdfCubit', () {
    late ImportPdfCubit cubit;

    setUp(() {
      cubit = ImportPdfCubit(
        runtime: MockGemmaRuntime(),
        pdfOcr: MockPdfOcrService(),
        transactions: MockTransactionsRepository(),
      );
    });

    tearDown(() => cubit.close());

    test('init marks prefsLoaded', () async {
      await cubit.init();
      expect(cubit.state.prefsLoaded, isTrue);
    });

    blocTest<ImportPdfCubit, ImportPdfState>(
      'extractTransactions emits error status if model not loaded',
      build: () {
        final c = ImportPdfCubit(
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
            .having((s) => s.status.contains('Extract failed'), 'status contains Extract failed', true),
      ],
    );
  });
}

