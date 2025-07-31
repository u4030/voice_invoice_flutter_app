import 'dart:async';
import 'package:flutter/material.dart';
import '../models/nlu_result.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/local_nlu_service.dart';

enum VoiceState { idle, listening, processing, error }

class SpeechProvider extends ChangeNotifier {
  // Services
  final SttService _sttService = SttService();
  final TtsService _ttsService = TtsService();
  final LocalNluService _nluService = LocalNluService();

  // State
  VoiceState _state = VoiceState.idle;
  String _errorMessage = '';
  String _recognizedText = '';
  String _partialText = ''; // Although STT service doesn't give partials, UI might need it.
  final _nluResultController = StreamController<NluResult>.broadcast();

  // Getters
  VoiceState get state => _state;
  String get errorMessage => _errorMessage;
  String get recognizedText => _recognizedText;
  String get partialText => _partialText;
  Stream<NluResult> get nluResultStream => _nluResultController.stream;
  bool get isListening => _state == VoiceState.listening;

  // --- Public Methods ---

  Future<void> initialize() async {
    try {
      await _nluService.loadIntents();
      _state = VoiceState.idle;
    } catch (e) {
      _setError("Failed to initialize NLU service: $e");
    }
    notifyListeners();
  }

  Future<void> startListening() async {
    if (isListening) return;

    _clearState();
    _state = VoiceState.listening;
    notifyListeners();

    final commandText = await _sttService.listen();

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

    _state = VoiceState.idle;
    notifyListeners();
  }

  Future<void> stopListening() async {
    // The STT service stops itself, this is for manual interruption
    // which is not yet implemented in SttService. For now, it's a placeholder.
    _state = VoiceState.idle;
    notifyListeners();
  }

  void clearText() {
    _clearState();
    notifyListeners();
  }

  Future<void> speak(String text) async {
    await _ttsService.speak(text);
  }

  void _setError(String message) {
    _errorMessage = message;
    _state = VoiceState.error;
    notifyListeners();
  }

  void _clearState() {
    _errorMessage = '';
    _recognizedText = '';
    _partialText = '';
  }

  @override
  void dispose() {
    _nluResultController.close();
    super.dispose();
  }
}