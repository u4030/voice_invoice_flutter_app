import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  final SpeechToText _speech = SpeechToText();

  Future<String?> listen({Duration listenDuration = const Duration(seconds: 5)}) async {
    bool initialized = await _speech.initialize();
    if (!initialized) return null;

    String recognized = '';
    // Using a Completer to handle the async nature of onResult
    final completer = Completer<String>();

    _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            recognized = result.recognizedWords;
            if (!completer.isCompleted) {
              completer.complete(recognized);
            }
          }
        },
        listenFor: listenDuration,
        // Adding a timeout to ensure it doesn't hang
        onDevice: () {
          if (!completer.isCompleted) {
            completer.complete(recognized);
          }
        }
    );

    return completer.future;
  }
}
