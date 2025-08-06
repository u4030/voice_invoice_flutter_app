import 'dart:async';
import 'package:flutter/material.dart';
import '../models/nlu_result.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/local_nlu_service.dart';

enum VoiceState { idle, wakeword, listening, processing, error }

class SpeechProvider extends ChangeNotifier {
  final LocalNluService _nluService = LocalNluService();
  final TtsService _ttsService = TtsService();
  late final SttService _sttService; // تأخير إنشاء SttService حتى التهيئة

  VoiceState _state = VoiceState.idle;
  String _errorMessage = '';
  String _recognizedText = '';
  String _partialText = '';
  final _nluResultController = StreamController<NluResult>.broadcast();

  VoiceState get state => _state;
  String get errorMessage => _errorMessage;
  String get recognizedText => _recognizedText;
  String get partialText => _partialText;
  Stream<NluResult> get nluResultStream => _nluResultController.stream;
  bool get isListening => _state == VoiceState.listening;
  bool get isListeningForWakeword => _state == VoiceState.wakeword;

  SpeechProvider() {
    // تمرير نفس مثيلات LocalNluService و TtsService إلى SttService
    _sttService = SttService(nluService: _nluService, ttsService: _ttsService);
  }

  Future<void> initialize() async {
    try {
      // تهيئة LocalNluService مرة واحدة فقط
      await _nluService.loadIntents();
      await _sttService.initialize();
      // تأخير بدء مستمع الكلمات المفتاحية لتجنب تحميل الخيط الرئيسي
      Future.delayed(const Duration(milliseconds: 500), () {
        startWakewordListener();
      });
    } catch (e) {
      _setError("Failed to initialize services: $e");
    }
    notifyListeners();
  }

  Future<void> startWakewordListener() async {
    if (_state == VoiceState.listening || _state == VoiceState.wakeword) return;
    _state = VoiceState.wakeword;
    notifyListeners();

    await _sttService.listenForWakeword(
      onWakewordDetected: () {
        print("SpeechProvider: Wakeword detected, starting command listening.");
        startListening();
      },
    );
  }

  Future<void> startListening() async {
    if (isListening) return;
    _sttService.cancelWakewordListener();

    _clearState();
    _state = VoiceState.listening;
    notifyListeners();

    try {
      final commandText = await _sttService.listen(
        onPartialResult: (partial) {
          _partialText = partial;
          notifyListeners();
        },
      );
      _state = VoiceState.processing;
      _recognizedText = commandText ?? '';
      notifyListeners();

      if (commandText != null && commandText.isNotEmpty) {
        final nluResult = await _nluService.parse(commandText);
        _nluResultController.add(nluResult);
      } else {
        final fallbackResult = await _nluService.parse("");
        _nluResultController.add(fallbackResult);
      }
    } catch (e) {
      _setError("Error during speech recognition: $e");
    } finally {
      if (_state != VoiceState.wakeword) {
        startWakewordListener();
      }
    }
  }

  Future<void> stopListening() async {
    if (isListening) {
      await _sttService.stop();
      startWakewordListener();
    }
  }

  void clearText() {
    _clearState();
    notifyListeners();
  }

  Future<void> speak(String text) async {
    try {
      await _ttsService.speak(text);
    } catch (e) {
      _setError("TTS error: $e");
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    _state = VoiceState.error;
    notifyListeners();
    // إعادة بدء مستمع الكلمات المفتاحية بعد الخطأ
    Future.delayed(const Duration(seconds: 1), () {
      startWakewordListener();
    });
  }

  void _clearState() {
    _errorMessage = '';
    _recognizedText = '';
    _partialText = '';
  }

  @override
  void dispose() {
    _sttService.cancelWakewordListener();
    _nluResultController.close();
    super.dispose();
  }
}