import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

  bool containsActivateCommand(String text) {
    final lowerText = text.toLowerCase().trim();
    return AppConstants.activateMicCommands.any(
          (command) => lowerText.contains(command.toLowerCase()),
    );
  }

  bool containsDeactivateCommand(String text) {
    final lowerText = text.toLowerCase().trim();
    return AppConstants.deactivateMicCommands.any(
          (command) => lowerText.contains(command.toLowerCase()),
    );
  }

  bool containsConfirmCommand(String text) {
    final lowerText = text.toLowerCase().trim();
    return AppConstants.confirmTextCommands.any(
          (command) => lowerText.contains(command.toLowerCase()),
    );
  }

  bool containsCancelCommand(String text) {
    final lowerText = text.toLowerCase().trim();
    return AppConstants.cancelTextCommands.any(
          (command) => lowerText.contains(command.toLowerCase()),
    );
  }

  bool containsRetryCommand(String text) {
    final lowerText = text.toLowerCase().trim();
    return AppConstants.retryCommands.any(
          (command) => lowerText.contains(command.toLowerCase()),
    );
  }

  bool containsNewInvoiceCommand(String text) {
    final lowerText = text.toLowerCase().trim();
    return AppConstants.newInvoiceCommands.any(
          (command) => lowerText.contains(command.toLowerCase()),
    );
  }

  bool containsPrintCommand(String text) {
    final lowerText = text.toLowerCase().trim();
    return AppConstants.printInvoiceCommands.any(
          (command) => lowerText.contains(command.toLowerCase()),
    );
  }

  bool containsSaveCommand(String text) {
    final lowerText = text.toLowerCase().trim();
    return AppConstants.saveInvoiceCommands.any(
          (command) => lowerText.contains(command.toLowerCase()),
    );
  }

  Map<String, dynamic>? parseInvoiceItem(String text) {
    final lowerText = text.toLowerCase().trim();

    final patterns = [
      RegExp(r'حساب\s+(.+?)\s+(\d+(?:\.\d+)?)', caseSensitive: false),
      RegExp(r'(.+?)\s+(\d+(?:\.\d+)?)\s*دينار', caseSensitive: false),
      RegExp(r'(.+?)\s+(\d+(?:\.\d+)?)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(lowerText);
      if (match != null && match.groupCount >= 2) {
        final description = match.group(1)?.trim();
        final amountStr = match.group(2)?.trim();

        if (description != null && amountStr != null) {
          final amount = double.tryParse(amountStr);
          if (amount != null && amount > 0) {
            return {
              'description': description,
              'amount': amount,
            };
          }
        }
      }
    }

    return null;
  }

  Map<String, dynamic>? parseExpense(String text) {
    final lowerText = text.toLowerCase().trim();

    final patterns = [
      RegExp(r'مصروف\s+(.+?)\s+(\d+(?:\.\d+)?)', caseSensitive: false),
      RegExp(r'مصاريف\s+(.+?)\s+(\d+(?:\.\d+)?)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(lowerText);
      if (match != null && match.groupCount >= 2) {
        final description = match.group(1)?.trim();
        final amountStr = match.group(2)?.trim();

        if (description != null && amountStr != null) {
          final amount = double.tryParse(amountStr);
          if (amount != null && amount > 0) {
            String category = _categorizeExpense(description);

            return {
              'description': description,
              'amount': amount,
              'category': category,
            };
          }
        }
      }
    }

    return null;
  }

  String _categorizeExpense(String description) {
    final lowerDesc = description.toLowerCase();

    if (lowerDesc.contains('طعام') ||
        lowerDesc.contains('أكل') ||
        lowerDesc.contains('مطعم') ||
        lowerDesc.contains('غداء') ||
        lowerDesc.contains('عشاء')) {
      return 'الطعام';
    }

    if (lowerDesc.contains('وقود') ||
        lowerDesc.contains('بنزين') ||
        lowerDesc.contains('تاكسي') ||
        lowerDesc.contains('باص') ||
        lowerDesc.contains('مواصلات')) {
      return 'النقل';
    }

    if (lowerDesc.contains('تسوق') ||
        lowerDesc.contains('شراء') ||
        lowerDesc.contains('ملابس') ||
        lowerDesc.contains('سوق')) {
      return 'التسوق';
    }

    if (lowerDesc.contains('منزل') ||
        lowerDesc.contains('بيت') ||
        lowerDesc.contains('كهرباء') ||
        lowerDesc.contains('ماء') ||
        lowerDesc.contains('إيجار')) {
      return 'المنزل';
    }

    if (lowerDesc.contains('طبيب') ||
        lowerDesc.contains('دواء') ||
        lowerDesc.contains('مستشفى') ||
        lowerDesc.contains('صحة')) {
      return 'الصحة';
    }

    if (lowerDesc.contains('تعليم') ||
        lowerDesc.contains('مدرسة') ||
        lowerDesc.contains('جامعة') ||
        lowerDesc.contains('كتاب')) {
      return 'التعليم';
    }

    if (lowerDesc.contains('ترفيه') ||
        lowerDesc.contains('سينما') ||
        lowerDesc.contains('لعبة') ||
        lowerDesc.contains('رحلة')) {
      return 'الترفيه';
    }

    return 'أخرى';
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