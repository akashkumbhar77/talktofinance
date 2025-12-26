import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _initialized = false;

  Future<bool> ensureInitialized() async {
    if (_initialized) return true;
    _initialized = await _stt.initialize();
    return _initialized;
  }

  bool get isListening => _stt.isListening;

  Future<void> start({
    required void Function(String text) onResult,
  }) async {
    final ok = await ensureInitialized();
    if (!ok) return;
    await _stt.listen(
      onResult: (r) => onResult(r.recognizedWords),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
      ),
    );
  }

  Future<void> stop() => _stt.stop();
}

