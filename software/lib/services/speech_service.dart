import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  stt.SpeechToText _speech = stt.SpeechToText();

  Future<bool> initialize() async {
    return await _speech.initialize(
      onError: (error) => print("Speech recognition error: $error"),
      onStatus: (status) => print("Speech recognition status: $status"),
    );
  }

  Future<void> startListening(Function(String) onResult) async {
    if (_speech.isAvailable && !_speech.isListening) {
      _speech.listen(
        onResult: (result) => onResult(result.recognizedWords),
        localeId: 'en_IN', // Change locale if needed
      );
    }
  }

  void stopListening() {
    if (_speech.isListening) {
      _speech.stop();
    }
  }
}
