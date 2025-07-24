import 'dart:async';
import 'package:vosk_flutter_2/vosk_flutter_2.dart';
import 'package:flutter/services.dart' show RootIsolateToken, BackgroundIsolateBinaryMessenger;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

class ImprovedVoskSpeechService {
  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;
  StreamSubscription? _partialSubscription;
  StreamSubscription? _resultSubscription;

  Future<void> initialize(String modelPath) async {
    await _cleanup(); // التأكد من إغلاق أي خدمة نشطة مسبقًا
    try {
      _model = await _vosk.createModel(modelPath);
      _recognizer = await _vosk.createRecognizer(model: _model!, sampleRate: 16000);
      _speechService = await _vosk.initSpeechService(_recognizer!);
      print('Vosk SpeechService initialized successfully');
    } catch (e) {
      print('Error initializing Vosk: $e');
      await _cleanup();
      rethrow; // إعادة إلقاء الاستثناء بدلاً من المحاولة مرة أخرى إذا فشلت التهيئة
    }
  }

  Stream<String> onPartial() {
    if (_speechService == null) {
      throw Exception('SpeechService is not initialized');
    }
    return _speechService!.onPartial().map((event) {
      try {
        final Map<String, dynamic> json = jsonDecode(event.toString());
        return json['partial']?.toString().trim() ?? 'جارٍ الاستماع...';
      } catch (e) {
        print('Error parsing partial result: $e');
        return 'جارٍ الاستماع...';
      }
    });
  }

  Stream<String> onResult() {
    if (_speechService == null) {
      throw Exception('SpeechService is not initialized');
    }
    return _speechService!.onResult().map((event) {
      try {
        final Map<String, dynamic> json = jsonDecode(event.toString());
        return json['text']?.toString().trim() ?? '';
      } catch (e) {
        print('Error parsing result: $e');
        return '';
      }
    });
  }

  Future<void> _cleanup() async {
    if (_speechService != null) {
      try {
        await _partialSubscription?.cancel();
        await _resultSubscription?.cancel();
        _partialSubscription = null;
        _resultSubscription = null;

        await _speechService!.stop();
        await Future.delayed(const Duration(milliseconds: 500)); // تأخير لضمان تحرير الموارد
        _speechService = null;
        print('Vosk resources cleaned up successfully');
      } catch (e) {
        print('Error during Vosk cleanup: $e');
        _speechService = null;
      }
    }
    // النموذج والمعرف لا يتم التخلص منهما مباشرة، يتم إعادة استخدامهما
  }

  Future<void> dispose() async {
    await _cleanup();
    print('Vosk resources disposed');
  }
}

class ModelLoader {
  static Future<Model> loadFromAssets(String modelPath) async {
    final voskPlugin = VoskFlutterPlugin.instance();
    return voskPlugin.createModel(modelPath);
  }
}