import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  TtsService() {
    _flutterTts.setLanguage('ar');
    _flutterTts.setSpeechRate(0.8);
  }

  Future<void> speak(String text) async {
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      print("TTS error: $e");
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
