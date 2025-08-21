import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'local_nlu_service.dart';
import 'tts_service.dart';

class SttService {
  final SpeechToText _speech = SpeechToText();
  final LocalNluService _nluService;
  final TtsService _ttsService; // إضافة TtsService كتبعية
  bool _isInitialized = false;
  bool _isListeningForWakeword = false;
  int _retryCount = 0; // عداد المحاولات لإعادة التهيئة
  List<String> _wakeWords = []; // سيتم تحميلها من نية greet

  // Constructor يأخذ LocalNluService و TtsService كمعاملات
  SttService({LocalNluService? nluService, TtsService? ttsService})
      : _nluService = nluService ?? LocalNluService(),
        _ttsService = ttsService ?? TtsService();

  // تحميل الكلمات المفتاحية من نية greet
  Future<void> _loadWakeWords() async {
    await _nluService.loadIntents();
    _wakeWords = _nluService.getIntentPatterns('greet');
    print('Loaded wake words from greet intent: $_wakeWords');
  }

  // التحقق من إذن الميكروفون
  Future<bool> _checkPermissions() async {
    final microphoneStatus = await Permission.microphone.request();

    if (!microphoneStatus.isGranted) {
      print('Microphone permission denied');
      return false;
    }
    print('Microphone permission granted');
    return true;
  }

  // تهيئة مكتبة speech_to_text مع حد أقصى لإعادة المحاولة
  Future<bool> initialize() async {
    if (_retryCount >= 3) {
      print('Max retry attempts reached for initialization');
      _isInitialized = false;
      return false;
    }

    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          print('SpeechToText status: $status');
        },
        onError: (error) {
          print('SpeechToText error during initialization: $error');
          _isInitialized = false;
          if (error.errorMsg == 'error_speech_timeout') {
            print('Speech timeout during initialization, retrying... (Attempt ${_retryCount + 1}/3)');
            _retryCount++;
            initialize(); // إعادة المحاولة
          }
        },
      );
      _retryCount = 0; // إعادة تعيين العداد عند النجاح
      print('SpeechToText initialized successfully: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      print('Error during SpeechToText initialization: $e');
      _isInitialized = false;
      _retryCount++;
      return false;
    }
  }

  // الاستماع للكلمات المفتاحية من نية greet
  Future<void> listenForWakeword({required VoidCallback onWakewordDetected}) async {
    _isListeningForWakeword = true;
    if (!await _checkPermissions()) {
      print('Permissions denied for wakeword listening');
      _isListeningForWakeword = false;
      return;
    }

    // تحميل الكلمات المفتاحية إذا لم تُحمّل بعد
    if (_wakeWords.isEmpty) {
      await _loadWakeWords();
    }

    await initialize();
    if (!_isInitialized) {
      print('Failed to initialize SpeechToText for wakeword');
      _isListeningForWakeword = false;
      return;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          print('Wakeword partial result: ${result.recognizedWords}');
          final text = result.recognizedWords.toLowerCase();
          // التحقق مما إذا كان النص يحتوي على أي من الكلمات المفتاحية
          for (String wakeWord in _wakeWords) {
            if (text.contains(wakeWord.toLowerCase())) {
              print('Wakeword "$wakeWord" detected!');
              stop();
              // تشغيل استجابة صوتية لنية greet
              final response = _nluService.getIntentResponse('greet');
              if (response.isNotEmpty) {
                _ttsService.speak(response);
              }
              onWakewordDetected();
              return;
            }
          }
        },
        partialResults: true,
        localeId: 'ar_SA', // يمكن تجربة ar_AE أو ar_EG إذا لزم الأمر
        listenFor: const Duration(seconds: 10),
        onSoundLevelChange: (level) {
          print('Wakeword sound level: $level');
          if (level < -20) {
            print('Warning: Low sound level detected, check microphone or environment');
          }
        },
      );
    } catch (e) {
      print('Error in listenForWakeword: $e');
      _isListeningForWakeword = false;
      _isInitialized = false;
      await initialize();
      listenForWakeword(onWakewordDetected: onWakewordDetected); // إعادة المحاولة
    }
  }

  // تسجيل الأوامر الصوتية مع إعادة الاستماع للكلمات المفتاحية بعد الانتهاء
  Future<String?> listen({
    Duration listenDuration = const Duration(seconds: 10),
    Function(String)? onPartialResult,
  }) async {
    _isListeningForWakeword = false;
    await stop(); // إيقاف أي جلسة استماع سابقة

    if (!await _checkPermissions()) {
      print('Permissions denied for command listening');
      return null;
    }

    await initialize();
    if (!_isInitialized) {
      print('Failed to initialize SpeechToText for command listening');
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
          } else {
            onPartialResult?.call(result.recognizedWords); // تحديث النتائج الجزئية
          }
        },
        onSoundLevelChange: (level) {
          print('Sound level: $level');
          if (level < -20) {
            print('Warning: Low sound level detected, check microphone or environment');
          }
        },
        listenFor: listenDuration,
        localeId: 'ar_SA', // يمكن تجربة ar_AE أو ar_EG إذا لزم الأمر
      );

      return await completer.future.timeout(
        listenDuration + const Duration(seconds: 2),
        onTimeout: () async {
          print('Listen timeout, stopping...');
          await _speech.stop();
          if (!completer.isCompleted) {
            completer.complete(recognizedWords);
          }
          // إعادة بدء الاستماع للكلمات المفتاحية بعد انتهاء المهلة
          listenForWakeword(onWakewordDetected: () {
            listen(onPartialResult: onPartialResult);
          });
          return recognizedWords;
        },
      );
    } catch (e) {
      print('Error during listening: $e');
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      await stop();
      // إعادة بدء الاستماع للكلمات المفتاحية بعد الخطأ
      listenForWakeword(onWakewordDetected: () {
        listen(onPartialResult: onPartialResult);
      });
      return null;
    } finally {
      await stop();
      // إعادة بدء الاستماع للكلمات المفتاحية بعد انتهاء التسجيل
      listenForWakeword(onWakewordDetected: () {
        listen(onPartialResult: onPartialResult);
      });
    }
  }

  // إيقاف الاستماع
  Future<void> stop() async {
    if (_speech.isListening) {
      await _speech.stop();
      print('SpeechToText stopped');
    }
    _isListeningForWakeword = false;
  }

  // إلغاء الاستماع للكلمات المفتاحية
  void cancelWakewordListener() {
    _isListeningForWakeword = false;
    stop();
  }
}