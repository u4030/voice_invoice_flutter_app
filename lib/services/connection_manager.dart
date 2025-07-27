import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vosk_flutter_2/vosk_flutter_2.dart';
import 'package:path/path.dart' as path;

enum ConnectionMode { online, offline }

class ConnectionManager {
  final stt.SpeechToText _speech;
  final VoskFlutterPlugin _vosk;
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  ConnectionMode _mode = ConnectionMode.online;
  bool _isInitialized = false;

  ConnectionManager(this._speech, this._vosk);

  ConnectionMode get mode => _mode;
  bool get isInitialized => _isInitialized;
  stt.SpeechToText get onlineService => _speech;
  SpeechService? get offlineService => _speechService;

  Future<void> initialize() async {
    await _requestPermissions();
    await _initializeOnline();
    _isInitialized = true;
  }

  Future<void> switchMode(ConnectionMode newMode) async {
    if (_mode == newMode) return;

    _mode = newMode;
    _isInitialized = false;

    if (_mode == ConnectionMode.online) {
      await _disposeOffline();
      await _initializeOnline();
    } else {
      await _disposeOnline();
      await _initializeOffline();
    }
    _isInitialized = true;
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> _initializeOnline() async {
    await _speech.initialize();
  }

  Future<void> _initializeOffline() async {
    if (_speechService != null) return;
    final modelPath = await _getModelPath();
    _model = await _vosk.createModel(modelPath);
    _recognizer = await _vosk.createRecognizer(model: _model!, sampleRate: 16000);
    _speechService = await _vosk.initSpeechService(_recognizer!);
  }

  Future<void> _disposeOnline() async {
    await _speech.stop();
  }

  Future<void> _disposeOffline() async {
    await _speechService?.stop();
    _speechService = null;
    _recognizer = null;
    _model = null;
  }

  Future<String> _getModelPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory(path.join(appDir.path, 'vosk-model'));
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      final modelAssets = manifestMap.keys
          .where((String key) => key.startsWith('assets/models/vosk-model-ar-mgb2-0.4/'))
          .toList();
      for (var assetPath in modelAssets) {
        final byteData = await rootBundle.load(assetPath);
        final relativePath = assetPath.replaceFirst('assets/models/vosk-model-ar-mgb2-0.4/', '');
        final file = File(path.join(modelDir.path, relativePath));
        await file.create(recursive: true);
        await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      }
    }
    return modelDir.path;
  }

  void dispose() {
    _disposeOnline();
    _disposeOffline();
  }
}
