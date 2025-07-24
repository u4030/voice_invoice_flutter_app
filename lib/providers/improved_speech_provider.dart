import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:voice_invoice_app/services/improved_vosk_speech_service.dart';
import 'package:synchronized/synchronized.dart';

enum SpeechMode { online, offline }

class ImprovedSpeechProvider with ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
  ImprovedVoskSpeechService? _voskSpeechService;
  SpeechMode _mode = SpeechMode.online;
  String _recognizedText = '';
  String _partialText = '';
  String _errorMessage = '';
  double _micLevel = 0.0;
  bool _isListening = false;
  StreamSubscription? _partialSubscription;
  StreamSubscription? _resultSubscription;
  final String _offlineModelPath = '/storage/emulated/0/Android/data/com.example.voice_invoice_flutter_app/files/vosk-model-ar-mgb2-0.4';
  final Lock _lock = Lock();

  ImprovedSpeechProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _speechToText.initialize();
    notifyListeners();
  }

  Future<void> switchToOfflineMode() async {
    await _lock.synchronized(() async {
      try {
        if (_voskSpeechService != null) {
          await _voskSpeechService!.dispose();
          await _partialSubscription?.cancel();
          await _resultSubscription?.cancel();
          _partialSubscription = null;
          _resultSubscription = null;
        }
        _voskSpeechService = ImprovedVoskSpeechService();
        await _voskSpeechService!.initialize(_offlineModelPath);
        _mode = SpeechMode.offline;
        _isListening = false;
        notifyListeners();
        print('Switched to offline mode');
      } catch (e) {
        _errorMessage = 'فشل التبديل إلى الوضع الخارج الشبكة: $e';
        notifyListeners();
        print('Error switching to offline mode: $e');
      }
    });
  }

  Future<void> switchToOnlineMode() async {
    await _lock.synchronized(() async {
      try {
        if (_voskSpeechService != null) {
          await _voskSpeechService!.dispose();
          await _partialSubscription?.cancel();
          await _resultSubscription?.cancel();
          _partialSubscription = null;
          _resultSubscription = null;
        }
        await _speechToText.initialize();
        _mode = SpeechMode.online;
        _isListening = false;
        notifyListeners();
        print('Switched to online mode');
      } catch (e) {
        _errorMessage = 'فشل التبديل إلى الوضع الأونلاين: $e';
        notifyListeners();
        print('Error switching to online mode: $e');
      }
    });
  }

  Future<void> startListening({
    required BuildContext context,
    required Function(String) onResult,
    required Function(String) onCommand,
  }) async {
    if (_isListening) return;

    _isListening = true;
    _recognizedText = '';
    _partialText = '';
    _errorMessage = '';
    notifyListeners();

    try {
      if (_mode == SpeechMode.offline && _voskSpeechService != null) {
        _partialSubscription = _voskSpeechService!.onPartial().listen((text) {
          _partialText = text;
          notifyListeners();
        });
        _resultSubscription = _voskSpeechService!.onResult().listen((text) {
          _recognizedText = text;
          _isListening = false;
          notifyListeners();
          onResult(text);
          if (containsCommand(text)) onCommand(text);
        });
      } else if (_mode == SpeechMode.online) {
        await _speechToText.listen(
          onResult: (result) {
            _recognizedText = result.recognizedWords ?? '';
            _isListening = false;
            notifyListeners();
            if (_recognizedText.isNotEmpty) {
              onResult(_recognizedText);
              if (containsCommand(_recognizedText)) onCommand(_recognizedText);
            }
          },
          onSoundLevelChange: (level) {
            _micLevel = level;
            notifyListeners();
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          cancelOnError: true,
          partialResults: true,
        );
      }
    } catch (e) {
      _errorMessage = 'فشل بدء الاستماع: $e';
      _isListening = false;
      notifyListeners();
      print('Error starting listening: $e');
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    _isListening = false;
    await _partialSubscription?.cancel();
    await _resultSubscription?.cancel();
    _partialSubscription = null;
    _resultSubscription = null;
    if (_mode == SpeechMode.online) {
      await _speechToText.stop();
    }
    notifyListeners();
  }

  bool containsNewInvoiceCommand(String text) {
    final normalizedText = text.toLowerCase().trim();
    return normalizedText.contains('فاتورة جديدة') || normalizedText.contains('فاتوره جديده');
  }

  Map<String, dynamic>? parseInvoiceItem(String text) {
    final regex = RegExp(r'(\w+)\s+(\d+(?:\.\d+)?)\s*(دينار|د\.إ|ريال|ر\.س)?');
    final match = regex.firstMatch(text);
    if (match != null) {
      final item = match.group(1)?.trim();
      final amount = double.tryParse(match.group(2) ?? '0');
      if (item != null && amount != null) {
        return {'name': item, 'amount': amount};
      }
    }
    return null;
  }

  Map<String, dynamic>? parseExpense(String text) {
    final regex = RegExp(r'مصروف\s+(\w+)\s+(\d+(?:\.\d+)?)\s*(دينار|د\.إ|ريال|ر\.س)?');
    final match = regex.firstMatch(text.toLowerCase());
    if (match != null) {
      final category = match.group(1)?.trim();
      final amount = double.tryParse(match.group(2) ?? '0');
      if (category != null && amount != null) {
        return {'category': category, 'amount': amount};
      }
    }
    return null;
  }

  bool containsPrintCommand(String text) {
    final normalizedText = text.toLowerCase().trim();
    return normalizedText.contains('طباعة');
  }

  bool containsSaveCommand(String text) {
    final normalizedText = text.toLowerCase().trim();
    return normalizedText.contains('حفظ');
  }

  bool containsCommand(String text) {
    return containsNewInvoiceCommand(text) || parseInvoiceItem(text) != null || parseExpense(text) != null ||
        containsPrintCommand(text) || containsSaveCommand(text);
  }

  void clearText() {
    _recognizedText = '';
    _partialText = '';
    notifyListeners();
  }

  // Getters
  String get recognizedText => _recognizedText;
  String get partialText => _partialText;
  String get errorMessage => _errorMessage;
  double get micLevel => _micLevel;
  bool get isListening => _isListening;
  SpeechMode get mode => _mode;
  bool get useOnlineMode => _mode == SpeechMode.online;
}

class SpeechServiceManager {
  // يمكن أن يحتوي على منطق إضافي إذا لزم الأمر
}