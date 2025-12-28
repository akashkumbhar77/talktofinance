import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_mvp/features/add_expense/add_expense_cubit.dart';
import 'package:flutter_mvp/features/add_expense/add_expense_state.dart';
import 'package:flutter_mvp/features/history/history_cubit.dart';
import 'package:flutter_mvp/features/history/history_state.dart';
import 'package:flutter_mvp/features/import_pdf/import_pdf_cubit.dart';
import 'package:flutter_mvp/features/import_pdf/import_pdf_state.dart';
import 'package:flutter_mvp/features/setup/setup_cubit.dart';
import 'package:flutter_mvp/features/setup/setup_state.dart';

class MockSetupCubit extends MockCubit<SetupState> implements SetupCubit {}

class MockAddExpenseCubit extends MockCubit<AddExpenseState> implements AddExpenseCubit {}

class MockImportPdfCubit extends MockCubit<ImportPdfState> implements ImportPdfCubit {}

class MockHistoryCubit extends MockCubit<HistoryState> implements HistoryCubit {}

