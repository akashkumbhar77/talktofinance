import 'package:equatable/equatable.dart';

class ImportPdfState extends Equatable {
  final bool prefsLoaded;

  final String? pdfPath;
  final String statementText;
  final String status;

  final bool busy;
  final bool isOcring;
  final int? ocrPage;
  final int? ocrPageCount;

  final List<Map<String, dynamic>> parsed;
  final Set<int> selected;

  const ImportPdfState({
    required this.prefsLoaded,
    required this.pdfPath,
    required this.statementText,
    required this.status,
    required this.busy,
    required this.isOcring,
    required this.ocrPage,
    required this.ocrPageCount,
    required this.parsed,
    required this.selected,
  });

  factory ImportPdfState.initial() => const ImportPdfState(
        prefsLoaded: false,
        pdfPath: null,
        statementText: '',
        status: 'Pick a PDF statement to extract transactions locally.',
        busy: false,
        isOcring: false,
        ocrPage: null,
        ocrPageCount: null,
        parsed: <Map<String, dynamic>>[],
        selected: <int>{},
      );

  ImportPdfState copyWith({
    bool? prefsLoaded,
    String? pdfPath,
    String? statementText,
    String? status,
    bool? busy,
    bool? isOcring,
    int? ocrPage,
    int? ocrPageCount,
    List<Map<String, dynamic>>? parsed,
    Set<int>? selected,
    bool clearPdfPath = false,
  }) {
    return ImportPdfState(
      prefsLoaded: prefsLoaded ?? this.prefsLoaded,
      pdfPath: clearPdfPath ? null : (pdfPath ?? this.pdfPath),
      statementText: statementText ?? this.statementText,
      status: status ?? this.status,
      busy: busy ?? this.busy,
      isOcring: isOcring ?? this.isOcring,
      ocrPage: ocrPage ?? this.ocrPage,
      ocrPageCount: ocrPageCount ?? this.ocrPageCount,
      parsed: parsed ?? this.parsed,
      selected: selected ?? this.selected,
    );
  }

  @override
  List<Object?> get props => [
        prefsLoaded,
        pdfPath,
        statementText,
        status,
        busy,
        isOcring,
        ocrPage,
        ocrPageCount,
        parsed,
        selected,
      ];
}

