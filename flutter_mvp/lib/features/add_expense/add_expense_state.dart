import 'package:equatable/equatable.dart';

class AddExpenseState extends Equatable {
  final bool prefsLoaded;

  final String text;
  final bool isListening;
  final bool busy;

  final String streaming;
  final String finalJson;
  final String? error;

  const AddExpenseState({
    required this.prefsLoaded,
    required this.text,
    required this.isListening,
    required this.busy,
    required this.streaming,
    required this.finalJson,
    required this.error,
  });

  factory AddExpenseState.initial() => const AddExpenseState(
        prefsLoaded: false,
        text: '',
        isListening: false,
        busy: false,
        streaming: '',
        finalJson: '',
        error: null,
      );

  AddExpenseState copyWith({
    bool? prefsLoaded,
    String? text,
    bool? isListening,
    bool? busy,
    String? streaming,
    String? finalJson,
    String? error,
  }) {
    return AddExpenseState(
      prefsLoaded: prefsLoaded ?? this.prefsLoaded,
      text: text ?? this.text,
      isListening: isListening ?? this.isListening,
      busy: busy ?? this.busy,
      streaming: streaming ?? this.streaming,
      finalJson: finalJson ?? this.finalJson,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        prefsLoaded,
        text,
        isListening,
        busy,
        streaming,
        finalJson,
        error,
      ];
}

