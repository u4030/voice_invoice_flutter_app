import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  final SpeechToText _speech = SpeechToText();

  Future<String?> listen({Duration listenDuration = const Duration(seconds: 5)}) async {
    // Using a Completer to handle the async nature of onResult
    final completer = Completer<String?>();
    String recognizedWords = '';

    bool initialized = await _speech.initialize(
      onStatus: (status) {
        // This is called when the listening status changes.
        // We use it to know when listening has stopped.
        // Using 'done' status is more reliable to ensure all results are processed.
        if (status == 'done') {
          if (!completer.isCompleted) {
            completer.complete(recognizedWords);
          }
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    if (!initialized) {
      return null;
    }

    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          recognizedWords = result.recognizedWords;
        }
      },
      listenFor: listenDuration,
      localeId: 'ar_SA',
      // The onDevice parameter was causing the error. It expects a boolean.
      // The logic to complete the future is now handled by the onStatus listener.
    );

    return completer.future;
  }
}
