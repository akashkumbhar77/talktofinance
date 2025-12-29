import 'package:mocktail/mocktail.dart';

import 'package:flutter_mvp/core/repositories/transactions_repository.dart';
import 'package:flutter_mvp/services/gemma_runtime.dart';
import 'package:flutter_mvp/services/ocr/pdf_ocr.dart';
import 'package:flutter_mvp/services/settings_repo.dart';

class MockSettingsRepo extends Mock implements SettingsRepo {}

class MockGemmaRuntime extends Mock implements GemmaRuntime {}

class MockTransactionsRepository extends Mock implements TransactionsRepository {}

class MockPdfOcrService extends Mock implements PdfOcrService {}

