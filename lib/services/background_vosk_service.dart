import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../models/nlu_result.dart';
import '../services/speech_service.dart';
import '../services/local_nlu_service.dart';

enum VoiceState { idle, wakeword, listening, processing, error }

class SpeechProvider extends ChangeNotifier {
  final LocalNluService _nluService = LocalNluService();
  final SpeechService _speechService = SpeechService.instance;

  VoiceState _state = VoiceState.idle;
  String _errorMessage = '';
  String _recognizedText = '';
  String _partialText = '';
  bool _wakeWordDetected = false;
  Timer? _commandTimer;
  bool _isInitialized = false;

  final _nluResultController = StreamController<NluResult>.broadcast();

  VoiceState get state => _state;
  String get errorMessage => _errorMessage;
  String get recognizedText => _recognizedText;
  String get partialText => _partialText;
  Stream<NluResult> get nluResultStream => _nluResultController.stream;

  bool get isListening => _state == VoiceState.listening || _state == VoiceState.wakeword;
  bool get isListeningForWakeword => _state == VoiceState.wakeword;

  SpeechProvider() {
    // Constructor is now simpler
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _nluService.loadIntents();
      await _speechService.initialize();
      _isInitialized = true;

      // listener للكشف من الخلفية
      FlutterBackgroundService().on('wakeDetected').listen((event) {
        print("Wake word detected! Starting command listening.");
        // Greet the user and start listening for a command
        speak(_nluService.getIntentResponse('greet'));
        startVoiceDetection();
      });
    } catch (e) {
      _setError("Failed to initialize services: $e");
    }
  }

  Future<void> _processCommand(String commandText) async {
    print("Processing command: $commandText");
    if (commandText.isNotEmpty) {
      _state = VoiceState.processing;
      notifyListeners();
      final nluResult = await _nluService.parse(commandText);
      if (!_nluResultController.isClosed) _nluResultController.add(nluResult);
    }
    _resetAfterCommand();
  }

  void _resetAfterCommand() {
    print("Resetting state.");
    _wakeWordDetected = false;
    _clearState();
    _state = VoiceState.idle;
    notifyListeners();
  }

  Future<void> startVoiceDetection() async {
    _state = VoiceState.listening;
    _partialText = '';
    notifyListeners();

    await _speechService.startListening(
      onResult: (text) {
        _recognizedText = text;
        _processCommand(text);
      },
      onPartialResult: (text) {
        _partialText = text;
        notifyListeners();
      },
      onComplete: () {
        _state = VoiceState.idle;
        notifyListeners();
      },
      onError: (error) {
        _setError('Error during listening: $error');
      },
    );
  }

  Future<void> stopVoiceDetection() async {
    await _speechService.stopListening();
    _state = VoiceState.idle;
    _clearState();
    notifyListeners();
  }

  void clearText() {
    _clearState();
    notifyListeners();
  }

  Future<void> speak(String text) async {
    try {
      await _speechService.speak(text);
    } catch (e) {
      _setError("TTS error: $e");
    }
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
    _commandTimer?.cancel();
    _speechService.dispose(); // The singleton can be disposed if the provider is
    _nluResultController.close();
    super.dispose();
  }
}