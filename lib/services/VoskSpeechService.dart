import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:vosk_flutter_2/vosk_flutter_2.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoskSpeechService {
  static final VoskSpeechService instance = VoskSpeechService._init();

  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;
  final FlutterTts _flutterTts = FlutterTts();

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isAvailable = false;

  VoskSpeechService._init();

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;

  Future<bool> initialize(BuildContext context) async {
    if (_isInitialized || _speechService != null) return true;

    try {
      final assetManifest = await DefaultAssetBundle.of(context).loadString('AssetManifest.json');
      final manifestMap = jsonDecode(assetManifest);
      final modelAssets = manifestMap.keys
          .where((String key) => key.startsWith('assets/models/vosk-model-ar-mgb2-0.4/'))
          .toList();

      final assetData = <String, List<int>>{};
      for (var assetPath in modelAssets) {
        final data = await DefaultAssetBundle.of(context).load(assetPath);
        assetData[assetPath] = data.buffer.asUint8List();
      }

      final appDir = await getExternalStorageDirectory();
      final modelDir = appDir != null ? path.join(appDir.path, 'vosk-model-ar-mgb2-0.4') : '';
      final directory = Directory(modelDir);

      if (!await directory.exists()) {
        await directory.create(recursive: true);
        for (var assetPath in modelAssets) {
          final relativePath = assetPath.replaceFirst('assets/models/vosk-model-ar-mgb2-0.4/', '');
          final file = File(path.join(modelDir, relativePath));
          await file.writeAsBytes(assetData[assetPath]!);
        }
      }

      _model = await _vosk.createModel(modelDir);
      _recognizer = await _vosk.createRecognizer(model: _model!, sampleRate: 16000);
      _speechService = await _vosk.initSpeechService(_recognizer!);

      if (_speechService != null) {
        await _reinitializeTts();
        _isAvailable = true;
        _isInitialized = true;
        return true;
      }
    } catch (e) {
      print('Vosk initialization error: $e');
    }
    return false;
  }

  Future<void> _reinitializeTts() async {
    try {
      await _flutterTts.setLanguage('ar-SA');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      print('TTS reinitialized successfully');
    } catch (e) {
      print('Error reinitializing TTS: $e');
    }
  }

  Future<void> startListening({
    required BuildContext context,
    required Function(String) onResult,
    Function(String)? onPartialResult,
    Function()? onComplete,
    Function(String)? onError,
  }) async {
    if (!_isInitialized || !_isAvailable || _isListening || _speechService == null) return;

    try {
      await _speechService!.start();
      _isListening = true;

      _speechService!.onPartial().listen((partialResult) {
        onPartialResult?.call(partialResult.toString());
      }, onError: (err) {
        onError?.call('خطأ في النتائج الجزئية: $err');
      });

      _speechService!.onResult().listen((finalResult) {
        _isListening = false;
        onResult(finalResult.toString());
        onComplete?.call();
      }, onError: (err) {
        onError?.call('خطأ في النتيجة النهائية: $err');
        _isListening = false;
      });
    } catch (e) {
      onError?.call('خطأ في بدء التسجيل Vosk: $e');
      _isListening = false;
    }
  }

  Future<void> stopListening() async {
    if (_isListening && _speechService != null) {
      await _speechService!.stop();
      _isListening = false;
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) return;
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      print('TTS error: $e');
      await _reinitializeTts(); // إعادة تهيئة في حالة الفشل
    }
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }

  bool containsNewInvoiceCommand(String text) {
    final lowerText = text.toLowerCase().trim();
    return ['فاتورة جديدة', 'إنشاء فاتورة'].any((cmd) => lowerText.contains(cmd.toLowerCase()));
  }

  bool containsPrintCommand(String text) {
    final lowerText = text.toLowerCase().trim();
    return ['طباعة', 'اطبع الفاتورة'].any((cmd) => lowerText.contains(cmd.toLowerCase()));
  }

  bool containsSaveCommand(String text) {
    final lowerText = text.toLowerCase().trim();
    return ['حفظ', 'احفظ الفاتورة'].any((cmd) => lowerText.contains(cmd.toLowerCase()));
  }

  Map<String, dynamic>? parseInvoiceItem(String text) {
    final lowerText = text.toLowerCase().trim();
    final pattern = RegExp(r'أضف\s+(.+)\s+بسعر\s+(\d+\.?\d*)', caseSensitive: false);
    final match = pattern.firstMatch(lowerText);
    if (match != null && match.groupCount >= 2) {
      final description = match.group(1)?.trim();
      final amountStr = match.group(2)?.trim();
      if (description != null && amountStr != null) {
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          return {'description': description, 'amount': amount};
        }
      }
    }
    return null;
  }

  void dispose() {
    _speechService?.stop();
    _isInitialized = false;
    _isListening = false;
  }
}