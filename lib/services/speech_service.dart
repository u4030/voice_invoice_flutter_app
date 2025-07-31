import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/app_constants.dart';

class SpeechService {
  static final SpeechService instance = SpeechService._init();

  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isAvailable = false;

  SpeechService._init();

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final micPermission = await Permission.microphone.status;
      if (!micPermission.isGranted) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          return false;
        }
      }

      _isAvailable = await _speechToText.initialize(
        onError: (error) => print('Speech error: $error'),
        onStatus: (status) => print('Speech status: $status'),
      );

      if (_isAvailable) {
        await _flutterTts.setLanguage('ar');
        await _flutterTts.setSpeechRate(0.8);
        await _flutterTts.setVolume(1.0);
        await _flutterTts.setPitch(1.0);

        _isInitialized = true;
        return true;
      }
    } catch (e) {
      print('Speech initialization error: $e');
    }

    return false;
  }

  Future<void> startListening({
    required Function(String) onResult,
    Function(String)? onPartialResult,
    Function()? onComplete,
    Function(String)? onError,
  }) async {
    if (!_isInitialized || !_isAvailable || _isListening) return;

    try {
      await _speechToText.listen(
        onResult: (result) {
          final recognizedWords = result.recognizedWords;

          if (result.finalResult) {
            _isListening = false;
            onResult(recognizedWords);
            onComplete?.call();
          } else {
            onPartialResult?.call(recognizedWords);
          }
        },
        listenFor: AppConstants.speechTimeout,
        pauseFor: AppConstants.pauseTimeout,
        partialResults: true,
        localeId: AppConstants.defaultLocale,
        onSoundLevelChange: (level) {},
      );

      _isListening = true;
    } catch (e) {
      onError?.call('خطأ في بدء التسجيل: $e');
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
    }
  }

  Future<void> cancelListening() async {
    if (_isListening) {
      await _speechToText.cancel();
      _isListening = false;
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) return;

    try {
      await _flutterTts.speak(text);
    } catch (e) {
      print('TTS error: $e');
    }
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }

  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) return [];
    return await _speechToText.locales();
  }

  void dispose() {
    _speechToText.cancel();
    _flutterTts.stop();
    _isInitialized = false;
    _isListening = false;
  }
}