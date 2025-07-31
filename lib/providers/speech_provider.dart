import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum SpeechState { idle, listening, processing, error }

class SpeechProvider extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _errorMessage = '';
  String _recognizedText = '';
  String _partialText = '';
  SpeechState _state = SpeechState.idle;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get errorMessage => _errorMessage;
  String get recognizedText => _recognizedText;
  String get partialText => _partialText;
  SpeechState get state => _state;

  Future<void> initialize() async {
    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          _errorMessage = 'خطأ في التعرف على الصوت: ${error.errorMsg}';
          _state = SpeechState.error;
          _isListening = false;
          notifyListeners();
        },
      );
      _state = SpeechState.idle;
      notifyListeners();
    } catch (e) {
      _isInitialized = false;
      _state = SpeechState.error;
      _errorMessage = 'خطأ في تهيئة التعرف على الصوت: $e';
      notifyListeners();
      throw Exception(_errorMessage);
    }
  }

  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onCommand,
    bool continuous = false,
  }) async {
    if (!_isInitialized) {
      _errorMessage = 'التعرف على الصوت غير مهيأ';
      _state = SpeechState.error;
      notifyListeners();
      return;
    }

    try {
      _isListening = true;
      _state = SpeechState.listening;
      _errorMessage = '';
      notifyListeners();

      await _speech.listen(
        onResult: (result) {
          _partialText = result.recognizedWords;
          _recognizedText = result.finalResult ? result.recognizedWords : '';
          _state = result.finalResult ? SpeechState.processing : SpeechState.listening;
          notifyListeners();
          if (result.finalResult) {
            onResult(_recognizedText);
            onCommand(_recognizedText);
            if (!continuous) {
              stopListening();
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        localeId: 'ar_JO',
      );
    } catch (e) {
      _errorMessage = 'خطأ أثناء التعرف على الصوت: $e';
      _state = SpeechState.error;
      _isListening = false;
      notifyListeners();
    }
  }

  void stopListening() {
    _speech.stop();
    _isListening = false;
    _state = SpeechState.idle;
    _partialText = '';
    notifyListeners();
  }

  void clearText() {
    _recognizedText = '';
    _partialText = '';
    _errorMessage = '';
    _state = SpeechState.idle;
    notifyListeners();
  }

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'[^\u0600-\u06FF\s0-9]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  String convertArabicDigits(String text) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const latinDigits = '0123456789';
    for (int i = 0; i < 10; i++) {
      text = text.replaceAll(arabicDigits[i], latinDigits[i]);
    }
    return text;
  }

  bool containsNewInvoiceCommand(String command) {
    final cleanedCommand = _cleanText(command);
    final newInvoiceKeywords = [
      'فاتورة جديدة',
      'فاتوره جديده',
      'إنشاء فاتورة',
      'انشاء فاتوره',
      'new invoice',
      'create invoice'
    ];
    bool matches = newInvoiceKeywords.any((keyword) => cleanedCommand.contains(_cleanText(keyword)));
    print('Command: $command, Cleaned: $cleanedCommand, Matches: $matches');
    return matches;
  }

  bool containsPrintCommand(String command) {
    final cleanedCommand = _cleanText(command);
    final printKeywords = [
      'طباعة الفاتورة',
      'طبع الفاتورة',
      'print invoice',
      'print the invoice'
    ];
    return printKeywords.any((keyword) => cleanedCommand == _cleanText(keyword));
  }

  bool containsSaveCommand(String command) {
    final cleanedCommand = _cleanText(command);
    final saveKeywords = [
      'حفظ الفاتورة',
      'حفظ',
      'save invoice',
      'save'
    ];
    return saveKeywords.any((keyword) => cleanedCommand == _cleanText(keyword));
  }

  Map<String, dynamic>? parseInvoiceItem(String text) {
    final cleanedText = _cleanText(text); // تنظيف النص
    print('Parsing invoice item for text: $cleanedText');

    // نمط معدل للتعامل مع النص
    final pattern = RegExp(r'(?:ضيف|add procedure)\s+(.+?)\s+(\d+(?:\.\d+)?)\s*$');
    final match = pattern.firstMatch(cleanedText);

    if (match != null && match.groupCount >= 2) {
      final description = match.group(1)!; // الوصف
      final amountStr = match.group(2)!;   // المبلغ
      final amount = double.tryParse(amountStr) ?? 0.0;

      print('Parsed description: $description, amount: $amount');
      if (description.isNotEmpty && amount > 0) {
        return {
          'description': description,
          'amount': amount,
        };
      }
    }

    print('No pattern matched for text: $cleanedText');
    return null;
  }

  Map<String, dynamic>? parseExpense(String text) {
    final lowerText = _cleanText(text);
    final RegExp expensePattern = RegExp(r'(أضف مصروف|add expense)\s+(.+?)\s+(بمبلغ|amount)\s+(\d+\.?\d*)\s*(فئة|category)?\s*(.+)?');
    final match = expensePattern.firstMatch(lowerText);

    if (match != null) {
      final description = match.group(2)!;
      final amount = double.tryParse(match.group(4)!) ?? 0.0;
      final category = match.group(6) ?? 'عام';

      if (description.isNotEmpty && amount > 0) {
        return {
          'description': description,
          'amount': amount,
          'category': category,
        };
      }
    }
    return null;
  }
}