import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_mvp/core/repositories/transactions_repository.dart';
import 'package:flutter_mvp/features/add_expense/add_expense_cubit.dart';
import 'package:flutter_mvp/features/history/history_cubit.dart';
import 'package:flutter_mvp/features/import_pdf/import_pdf_cubit.dart';
import 'package:flutter_mvp/features/setup/setup_cubit.dart';
import 'package:flutter_mvp/services/gemma_runtime.dart';
import 'package:flutter_mvp/services/ocr/pdf_ocr.dart';
import 'package:flutter_mvp/services/settings_repo.dart';
import 'package:flutter_mvp/ui/screens/history_screen.dart';
import 'package:flutter_mvp/ui/screens/import_pdf_screen.dart';
import 'package:flutter_mvp/ui/screens/setup_screen.dart';
import 'package:flutter_mvp/ui/screens/voice_add_screen.dart';
import 'package:flutter_mvp/ui/app_theme.dart';

class EdgeExpenseApp extends StatelessWidget {
  const EdgeExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edge Expense AI',
      theme: buildAppTheme(),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _index = 0;

  final SettingsRepo _settings = SettingsRepo();
  final TransactionsRepository _transactions = TransactionsRepository();
  final GemmaRuntime _runtime = GemmaRuntime.instance;
  final PdfOcrService _pdfOcr = PdfOcrService();

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: _settings),
        RepositoryProvider.value(value: _transactions),
        RepositoryProvider.value(value: _runtime),
        RepositoryProvider.value(value: _pdfOcr),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (ctx) => SetupCubit(settings: _settings, runtime: _runtime)..init()),
          BlocProvider(
            create: (ctx) => AddExpenseCubit(settings: _settings, runtime: _runtime, transactions: _transactions)..init(),
          ),
          BlocProvider(
            create: (ctx) =>
                ImportPdfCubit(settings: _settings, runtime: _runtime, pdfOcr: _pdfOcr, transactions: _transactions)
                  ..init(),
          ),
          BlocProvider(create: (ctx) => HistoryCubit(transactions: _transactions)..load()),
        ],
        child: Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: _index,
              children: const [
                SetupScreen(),
                VoiceAddScreen(),
                ImportPdfScreen(),
                HistoryScreen(),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.settings), label: 'Setup'),
              NavigationDestination(icon: Icon(Icons.mic), label: 'Add'),
              NavigationDestination(icon: Icon(Icons.picture_as_pdf), label: 'Import'),
              NavigationDestination(icon: Icon(Icons.history), label: 'History'),
            ],
          ),
        ),
      ),
    );
  }
}

