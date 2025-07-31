import 'dart:async';
import 'package:flutter/material.dart';
import '../models/nlu_result.dart';
import '../services/wake_word_service.dart';
import '../services/stt_service.dart';
import '../services/local_nlu_service.dart';

enum VoiceState { idle, listeningWakeWord, listeningCommand, processing, error }

class SpeechProvider extends ChangeNotifier {
  // Services
  WakeWordService? _wakeWordService;
  final SttService _sttService = SttService();
  final LocalNluService _nluService = LocalNluService();

  // State
  VoiceState _state = VoiceState.idle;
  String _errorMessage = '';
  final _nluResultController = StreamController<NluResult>.broadcast();

  // Getters
  VoiceState get state => _state;
  String get errorMessage => _errorMessage;
  Stream<NluResult> get nluResultStream => _nluResultController.stream;

  // --- Public Methods ---

  Future<void> initialize() async {
    try {
      await _nluService.loadIntents();
      _wakeWordService = WakeWordService(_onWakeWordDetected);
      await _wakeWordService!.initialize();
      _state = VoiceState.idle;
    } catch (e) {
      _setError("Failed to initialize services: $e");
    }
    notifyListeners();
  }

  Future<void> start() async {
    if (_state == VoiceState.listeningWakeWord) return;
    try {
      await _wakeWordService?.start();
      _state = VoiceState.listeningWakeWord;
    } catch (e) {
      _setError("Could not start wake word listener: $e");
    }
    notifyListeners();
  }

  Future<void> stop() async {
    try {
      await _wakeWordService?.stop();
      _state = VoiceState.idle;
    } catch (e) {
      _setError("Could not stop wake word listener: $e");
    }
    notifyListeners();
  }

  // --- Private Callbacks & Logic ---

  void _onWakeWordDetected() async {
    if (_state == VoiceState.listeningCommand) return; // Already in a command loop

    await _wakeWordService?.stop();
    _state = VoiceState.listeningCommand;
    notifyListeners();

    final commandText = await _sttService.listen();
    _state = VoiceState.processing;
    notifyListeners();

    if (commandText != null && commandText.isNotEmpty) {
      final nluResult = await _nluService.parse(commandText);
      _nluResultController.add(nluResult);
    } else {
      // Handle case where nothing was heard
    }

    // Go back to listening for the wake word
    start();
  }

  void _setError(String message) {
    _errorMessage = message;
    _state = VoiceState.error;
    notifyListeners();
  }

  @override
  void dispose() {
    _wakeWordService?.release();
    _nluResultController.close();
    super.dispose();
  }
}