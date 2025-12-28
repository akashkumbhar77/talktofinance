import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mvp/domain/transaction.dart';
import 'package:flutter_mvp/features/add_expense/add_expense_state.dart';
import 'package:flutter_mvp/features/history/history_state.dart';
import 'package:flutter_mvp/features/import_pdf/import_pdf_state.dart';
import 'package:flutter_mvp/features/setup/setup_state.dart';
import 'package:flutter_mvp/ui/app_theme.dart';
import 'package:flutter_mvp/ui/screens/history_screen.dart';
import 'package:flutter_mvp/ui/screens/import_pdf_screen.dart';
import 'package:flutter_mvp/ui/screens/setup_screen.dart';
import 'package:flutter_mvp/ui/screens/voice_add_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mock_cubits.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UI overflow smoke', () {
    testWidgets('SetupScreen does not overflow on small device', (tester) async {
      final mock = MockSetupCubit();

      final loaded = SetupState.initial().copyWith(
        prefsLoaded: true,
        gpuUrl: 'https://example.com/models/gpu/some_really_long_path_that_could_wrap_or_overflow/gemma.task',
        gpuSha256: 'a' * 64,
        cpuUrl: 'https://example.com/models/cpu/some_really_long_path_that_could_wrap_or_overflow/gemma.task',
        cpuSha256: 'b' * 64,
        useMockExtractor: false,
        wifiOnlyDownloads: true,
        selectedTier: 'gpu',
        status: 'A long status message ' * 8,
        isDownloading: true,
        downloadProgress: 42,
      );

      whenListen(mock, Stream<SetupState>.fromIterable([loaded]), initialState: SetupState.initial());

      when(() => mock.setUseMockExtractor(any())).thenAnswer((_) async {});
      when(() => mock.setWifiOnlyDownloads(any())).thenAnswer((_) async {});
      when(() => mock.setSelectedTier(any())).thenAnswer((_) async {});
      when(() => mock.setGpuUrl(any())).thenAnswer((_) async {});
      when(() => mock.setGpuSha256(any())).thenAnswer((_) async {});
      when(() => mock.setCpuUrl(any())).thenAnswer((_) async {});
      when(() => mock.setCpuSha256(any())).thenAnswer((_) async {});
      when(() => mock.downloadAndLoad()).thenAnswer((_) async {});
      when(() => mock.cancelDownload()).thenReturn(null);

      await _pumpSmall(tester, BlocProvider.value(value: mock, child: const SetupScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await mock.close();
    });

    testWidgets('VoiceAddScreen does not overflow with long streaming/json', (tester) async {
      final mock = MockAddExpenseCubit();

      final s = AddExpenseState.initial().copyWith(
        prefsLoaded: true,
        useMockExtractor: true,
        text: 'Bought coffee for ₹250 at CCD. ' * 10,
        busy: false,
        isListening: false,
        streaming: '{"partial":"${'x' * 500}"}' * 5,
        finalJson: const JsonEncoder.withIndent('  ').convert({
          'amount': 250,
          'currency': 'INR',
          'merchant': 'CCD',
          'category': 'Food',
          'date': '2025-12-28',
          'notes': 'n' * 400,
          'confidence': 0.7,
        }),
        error: null,
      );

      whenListen(mock, Stream<AddExpenseState>.fromIterable([s]), initialState: AddExpenseState.initial());

      when(() => mock.setText(any())).thenReturn(null);
      when(() => mock.toggleMic()).thenAnswer((_) async {});
      when(() => mock.pickReceiptImageAndOcr()).thenAnswer((_) async {});
      when(() => mock.extractAndSave()).thenAnswer((_) async {});

      await _pumpSmall(tester, BlocProvider.value(value: mock, child: const VoiceAddScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await mock.close();
    });

    testWidgets('ImportPdfScreen does not overflow with many candidates', (tester) async {
      final mock = MockImportPdfCubit();

      final candidates = List<Map<String, dynamic>>.generate(
        20,
        (i) => {
          'amount': i * 10 + 0.99,
          'currency': 'INR',
          'merchant': 'Merchant with a long name ' * 3,
          'notes': 'This is a long line that should ellipsize safely. ' * 4,
        },
      );

      final s = ImportPdfState.initial().copyWith(
        prefsLoaded: true,
        useMockExtractor: true,
        pdfPath: '/tmp/statement.pdf',
        statementText: 'line ' * 200,
        status: 'Ready.',
        busy: false,
        isOcring: false,
        parsed: candidates,
        selected: Set<int>.from(List<int>.generate(candidates.length, (i) => i)),
      );

      when(() => mock.state).thenReturn(s);
      whenListen(mock, const Stream<ImportPdfState>.empty(), initialState: s);

      when(() => mock.pickPdf()).thenAnswer((_) async {});
      when(() => mock.runOcr()).thenAnswer((_) async {});
      when(() => mock.extractTransactions()).thenAnswer((_) async {});
      when(() => mock.importSelected()).thenAnswer((_) async {});
      when(() => mock.toggleSelected(any(), any())).thenReturn(null);
      when(() => mock.cancelOcr()).thenReturn(null);

      await _pumpSmall(tester, BlocProvider.value(value: mock, child: const ImportPdfScreen()));
      await tester.pumpAndSettle();

      // Scroll a bit to exercise layout further.
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await mock.close();
    });

    testWidgets('HistoryScreen does not overflow with long JSON', (tester) async {
      final mock = MockHistoryCubit();

      final items = List<TransactionRecord>.generate(
        8,
        (i) => TransactionRecord(
          id: i + 1,
          createdAtEpochMs: DateTime(2025, 12, 28).millisecondsSinceEpoch,
          rawText: 'raw ' * 20,
          extractedJson: '{"id":$i,"payload":"${'x' * 600}"}',
          amount: 99.99,
          currency: 'INR',
          merchant: 'A very long merchant name ' * 3,
          category: 'Category',
          date: '2025-12-28',
          notes: null,
          confidence: 0.5,
        ),
      );

      final s = HistoryState(loading: false, items: items, error: null);
      when(() => mock.state).thenReturn(s);
      whenListen(mock, const Stream<HistoryState>.empty(), initialState: s);

      when(() => mock.refresh()).thenAnswer((_) async {});
      when(() => mock.clear()).thenAnswer((_) async {});

      await _pumpSmall(tester, BlocProvider.value(value: mock, child: const HistoryScreen()));
      await tester.pumpAndSettle();

      // Expand first tile to render JSON area.
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await mock.close();
    });
  });
}

Future<void> _pumpSmall(WidgetTester tester, Widget child) async {
  final errors = <FlutterErrorDetails>[];
  final old = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details);
  };
  addTearDown(() {
    FlutterError.onError = old;
  });

  // Small-ish device surface.
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.window.physicalSizeTestValue = const Size(320, 568);
  binding.window.devicePixelRatioTestValue = 2.0;
  addTearDown(() {
    binding.window.clearPhysicalSizeTestValue();
    binding.window.clearDevicePixelRatioTestValue();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: child,
    ),
  );

  await tester.pump();
  expect(errors, isEmpty, reason: 'FlutterError(s) occurred (often includes overflow).');
}

