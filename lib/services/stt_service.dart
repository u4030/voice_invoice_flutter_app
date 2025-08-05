import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;

  Future<bool> _checkMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> initialize() async {
    if (!_isInitialized) {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          print('SpeechToText error: $error');
        },
      );
    }
  }

  Future<String?> listen({Duration listenDuration = const Duration(seconds: 10)}) async {
    // Check microphone permission
    if (!await _checkMicrophonePermission()) {
      print('Microphone permission denied');
      return null;
    }

    // Ensure SpeechToText is initialized
    await initialize();
    if (!_isInitialized) {
      print('Failed to initialize SpeechToText');
      return null;
    }

    final completer = Completer<String?>();
    String recognizedWords = '';

    try {
      await _speech.listen(
        onResult: (result) {
          print('Speech recognition result: ${result.recognizedWords}, final: ${result.finalResult}');
          if (result.finalResult) {
            recognizedWords = result.recognizedWords;
            if (!completer.isCompleted) {
              completer.complete(recognizedWords);
            }
          }
        },
        onSoundLevelChange: (level) {
          print('Sound level: $level');
        },
        listenFor: listenDuration,
        localeId: 'ar', // Try 'ar' instead of 'ar_SA' for better recognition
      );

      return await completer.future.timeout(
        listenDuration + const Duration(seconds: 1),
        onTimeout: () async {
          await _speech.stop();
          if (!completer.isCompleted) {
            completer.complete(recognizedWords);
          }
          return recognizedWords;
        },
      );
    } catch (e) {
      print('Error during listening: $e');
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      await stop();
      return null;
    } finally {
      await stop();
    }
  }

  Future<void> stop() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    // Reset initialization state to force re-initialization for the next session
    _isInitialized = false;
  }
}