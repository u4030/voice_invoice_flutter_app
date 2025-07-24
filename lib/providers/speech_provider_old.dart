import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show RootIsolateToken, BackgroundIsolateBinaryMessenger;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vosk_flutter_2/vosk_flutter_2.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'dart:typed_data';
import 'package:synchronized/synchronized.dart';

enum SpeechState { idle, listening, processing, error, loading }

class SpeechProvider extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;
  FlutterTts _tts = FlutterTts();
  final FlutterAudioCapture _audioCapture = FlutterAudioCapture();
  final _lock = Lock();
  double _micLevel = 0.0;

  bool _isInitialized = false;
  bool _isListening = false;
  bool _useOnlineMode = true;
  bool _isLoading = false;
  String _errorMessage = '';
  String _recognizedText = '';
  String _partialText = '';
  SpeechState _state = SpeechState.idle;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get useOnlineMode => _useOnlineMode;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get recognizedText => _recognizedText;
  String get partialText => _partialText;
  SpeechState get state => _state;
  double get micLevel => _micLevel;

  Function(String)? _onResult;
  Function(String)? _onCommand;
  bool _continuous = false;

  void updateErrorMessage(String message) {
    _errorMessage = message;
    _state = SpeechState.error;
    notifyListeners();
  }

  String convertArabicDigits(String input) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String result = input;
    for (int i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], englishDigits[i]);
    }
    return result;
  }

  Future<void> _setupTts() async {
    try {
      await _tts.setLanguage('ar-SA');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      print('TTS setup completed');
    } catch (e) {
      print('Error in TTS setup: $e');
      _errorMessage = 'خطأ في تهيئة TTS: $e';
      _state = SpeechState.error;
      notifyListeners();
    }
  }

  Future<void> _disposeVoskResources() async {
    print('Disposing all Vosk resources...');
    if (_speechService != null) {
      try {
        await _speechService!.stop();
        print('Vosk SpeechService stopped successfully');
      } catch (e) {
        print('Error stopping Vosk SpeechService: $e');
      }
      _speechService = null;
    }
    if (_recognizer != null) {
      // لا توجد دالة dispose للـ recognizer في هذه المكتبة،
      // ولكن تعيينه إلى null يضمن إنشاء واحد جديد.
      _recognizer = null;
      print('Vosk recognizer cleared');
    }
    if (_model != null) {
      // لا توجد دالة dispose للـ model في هذه المكتبة،
      // ولكن تعيينه إلى null يضمن تحميل واحد جديد عند الحاجة.
      _model = null;
      print('Vosk model cleared');
    }
    print('All Vosk resources have been cleared.');
  }

  static Future<String> _copyModelToStorage(Map<String, dynamic> params) async {
    final List<String> modelAssets = params['modelAssets'];
    final Map<String, List<int>> assetData = params['assetData'];
    final RootIsolateToken token = params['token'];

    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    try {
      print('Attempting to copy Vosk model to storage...');
      final appDir = await getExternalStorageDirectory();
      if (appDir == null) {
        throw Exception('External storage directory not accessible');
      }
      final modelDir = path.join(appDir.path, 'vosk-model-ar-mgb2-0.4');
      final directory = Directory(modelDir);

      final requiredFiles = [
        'am/final.mdl', 'conf/model.conf', 'conf/mfcc.conf', 'ivector/final.ie',
        'ivector/final.mat', 'ivector/global_cmvn.stats', 'ivector/online_cmvn.conf',
        'ivector/final.dubm', 'ivector/final.ie.id', 'ivector/splice.conf',
        'graph/HCLG.fst', 'graph/phones.txt', 'graph/words.txt', 'graph/words_bw.txt',
        'graph/words_head.txt', 'graph/words_tail.txt',
      ];

      if (await directory.exists()) {
        bool allFilesExist = true;
        for (var filePath in requiredFiles) {
          final file = File(path.join(modelDir, filePath));
          if (!await file.exists()) {
            allFilesExist = false;
            break;
          }
        }
        if (allFilesExist) {
          print('Vosk model already exists at: $modelDir');
          return modelDir;
        } else {
          await directory.delete(recursive: true);
        }
      }

      await directory.create(recursive: true);
      print('Created model directory at: $modelDir');

      if (modelAssets.isEmpty) {
        throw Exception('No model files found in assets/vosk-model-ar-mgb2-0.4/');
      }

      for (var assetPath in modelAssets) {
        final relativePath = assetPath.replaceFirst('assets/models/vosk-model-ar-mgb2-0.4/', '');
        final file = File(path.join(modelDir, relativePath));
        if (!await file.exists()) {
          await file.create(recursive: true);
          await file.writeAsBytes(assetData[assetPath]!);
          print('Copied file: $relativePath');
        }
      }

      for (var filePath in requiredFiles) {
        final file = File(path.join(modelDir, filePath));
        if (!await file.exists()) {
          throw Exception('Required model file $filePath not found after copying');
        }
      }

      print('Vosk model copied successfully to: $modelDir');
      return modelDir;
    } catch (e) {
      print('Error copying Vosk model: $e');
      throw Exception('Failed to copy model: $e');
    }
  }

  Future<bool> _initializeOnlineSpeech() async {
    print('Initializing online speech recognition...');
    bool available = false;
    try {
      available = await _speech.initialize(
        onError: (err) {
          _errorMessage = 'خطأ في التعرف على الصوت (online): ${err.errorMsg}';
          _state = SpeechState.error;
          notifyListeners();
        },
        onStatus: (status) {
          print('Speech status: $status');
          _state = status == 'listening' ? SpeechState.listening : SpeechState.idle;
          notifyListeners();
        },
        debugLogging: true,
      );
    } catch (e) {
      _errorMessage = 'Exception during online speech initialization: $e';
      _state = SpeechState.error;
      notifyListeners();
    }
    if (!available) {
      _errorMessage = 'فشل تهيئة التعرف على الصوت أونلاين';
      _state = SpeechState.error;
      notifyListeners();
      print('Online speech initialization failed');
      return false;
    }
    print('Online speech initialized successfully with speech_to_text');
    return true;
  }

  Future<bool> _initializeVosk(BuildContext context) async {
    _isLoading = true;
    _state = SpeechState.loading;
    notifyListeners();

    try {
      var microphoneStatus = await Permission.microphone.status;
      if (!microphoneStatus.isGranted) {
        microphoneStatus = await Permission.microphone.request();
        if (!microphoneStatus.isGranted) {
          _errorMessage = 'لم يتم منح إذن الميكروفون. يرجى السماح بالوصول إلى الميكروفون.';
          _state = SpeechState.error;
          _isLoading = false;
          _showFeedback(context, _errorMessage, isError: true);
          notifyListeners();
          return false;
        }
      }

      print('Initializing Vosk offline recognition...');
      final assetManifest = await DefaultAssetBundle.of(context).loadString('AssetManifest.json');
      final manifestMap = jsonDecode(assetManifest);
      final modelAssets = manifestMap.keys
          .where((String key) => key.startsWith('assets/models/vosk-model-ar-mgb2-0.4/'))
          .toList();
      print('Found ${modelAssets.length} model assets');

      final assetData = <String, List<int>>{};
      for (var assetPath in modelAssets) {
        final data = await DefaultAssetBundle.of(context).load(assetPath);
        assetData[assetPath] = data.buffer.asUint8List();
      }

      final token = RootIsolateToken.instance!;
      final modelPath = await compute(_copyModelToStorage, {
        'modelAssets': modelAssets,
        'assetData': assetData,
        'token': token,
      }, debugLabel: 'VoskModelCopy');
      print('Model path: $modelPath');

      if (_model == null) {
        _model = await _vosk.createModel(modelPath);
        print('Vosk model created successfully at: $modelPath');
      } else {
        print('Reusing existing Vosk model');
      }

      if (_recognizer == null) {
        _recognizer = await _vosk.createRecognizer(
          model: _model!,
          sampleRate: 16000,
        );
        print('Vosk recognizer created successfully');
      } else {
        print('Reusing existing Vosk recognizer');
      }

      // تحرير SpeechService إذا كان موجودًا
      if (_speechService != null) {
        await _speechService!.stop();
        _speechService = null;
        print('Existing SpeechService instance stopped and cleared');
      }

      try {
        _speechService = await _vosk.initSpeechService(_recognizer!);
        print('Vosk SpeechService initialized successfully');
      } catch (e) {
        print('Error creating SpeechService: $e');
        _errorMessage = 'خطأ في إنشاء SpeechService: $e';
        _state = SpeechState.error;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLoading = false;
      _state = SpeechState.idle;
      notifyListeners();
      return true;
    } catch (e) {
      print('Error initializing Vosk: $e');
      _errorMessage = 'خطأ عند تهيئة Vosk: $e';
      _state = SpeechState.error;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) {
      print('SpeechProvider already initialized, skipping...');
      return;
    }

    try {
      print('Starting speech initialization...');
      await _setupTts();

      _isInitialized = await _initializeOnlineSpeech();
      if (_isInitialized) {
        _state = SpeechState.idle;
        _showFeedback(context, 'تم تهيئة التطبيق في الوضع الأول (أونلاين)');
      }

      try {
        await _audioCapture.init();
        print('AudioCapture initialized');
      } catch (e) {
        print('AudioCapture init failed: $e');
        _errorMessage = 'خطأ في تهيئة AudioCapture: $e';
        _state = SpeechState.error;
        _showFeedback(context, _errorMessage, isError: true);
        notifyListeners();
      }
    } catch (e) {
      _isInitialized = false;
      _state = SpeechState.error;
      _errorMessage = 'خطأ عند التهيئة: $e';
      _showFeedback(context, _errorMessage, isError: true);
      print('Initialization failed: $e');
      notifyListeners();
    }
  }

  void switchToOfflineMode(BuildContext context) async {
    await _lock.synchronized(() async {
      // أوقف الاستماع الحالي قبل أي تبديل
      if (_isListening) {
        await stopListening();
      }

      _useOnlineMode = !_useOnlineMode; // تبديل الوضع

      if (!_useOnlineMode) { // إذا كنا نتحول إلى الوضع الأوفلاين
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('جارٍ التحميل'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('يتم تهيئة النظام الثاني (خارج الشبكة)، يرجى الانتظار...'),
              ],
            ),
          ),
        );

        // نظّف الموارد القديمة قبل التهيئة
        await _disposeVoskResources();

        _isInitialized = await _initializeVosk(context);

        Navigator.of(context).pop(); // إغلاق الحوار

        if (_isInitialized) {
          _state = SpeechState.idle;
          _showFeedback(context, 'تم التبديل إلى الوضع الثاني (خارج الشبكة)');
        } else {
          _useOnlineMode = true; // فشل التحويل، ارجع إلى الأونلاين
          _showFeedback(context, 'فشل التبديل إلى الوضع الثاني، يرجى المحاولة لاحقًا', isError: true);
        }

      } else { // إذا كنا نرجع إلى الوضع الأونلاين
        // تخلص تمامًا من موارد Vosk
        await _disposeVoskResources();
        _isInitialized = await _initializeOnlineSpeech();
        _showFeedback(context, 'تم الرجوع إلى الوضع الأول (أونلاين)');
      }
      notifyListeners();
    });
  }

  String _extractTextFromJson(String jsonString) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      String text = json['text']?.toString().trim() ?? json['partial']?.toString().trim() ?? '';
      if (text.isEmpty) {
        print('Empty text extracted from JSON: $jsonString');
        return 'جارٍ الاستماع...';
      }
      return text;
    } catch (e) {
      print('Error parsing Vosk JSON: $e');
      return 'جارٍ الاستماع...';
    }
  }

  void _calculateMicLevel(Float32List samples) {
    if (samples.isEmpty) {
      _micLevel = 0.0;
      print('No audio samples received');
    } else {
      double sum = samples.fold(0, (sum, sample) => sum + sample.abs());
      _micLevel = (sum / samples.length).clamp(0.0, 1.0);
      print('Audio samples received, mic level: $_micLevel');
    }
    notifyListeners();
  }

  Future<void> startListening({
    required BuildContext context,
    required Function(String) onResult,
    required Function(String) onCommand,
    bool continuous = false,
  }) async {
    if (!_isInitialized || _isLoading) {
      _errorMessage = 'لم يتم تهيئة الخدمة بعد أو جارٍ التحميل';
      _state = SpeechState.error;
      _showFeedback(context, _errorMessage, isError: true);
      notifyListeners();
      return;
    }

    var microphoneStatus = await Permission.microphone.status;
    if (!microphoneStatus.isGranted) {
      microphoneStatus = await Permission.microphone.request();
      if (!microphoneStatus.isGranted) {
        _errorMessage = 'لم يتم منح إذن الميكروفون. يرجى السماح بالوصول إلى الميكروفون.';
        _state = SpeechState.error;
        _showFeedback(context, _errorMessage, isError: true);
        notifyListeners();
        return;
      }
    }

    _onResult = onResult;
    _onCommand = onCommand;
    _continuous = continuous;

    try {
      _isListening = true;
      _state = SpeechState.listening;
      _partialText = 'جارٍ الاستماع...';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('جارٍ الاستماع...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      notifyListeners();

      if (_useOnlineMode) {
        print('Using speech_to_text for online recognition');
        await _speech.listen(
          onResult: (res) {
            _partialText = res.recognizedWords.isNotEmpty ? res.recognizedWords : 'جارٍ الاستماع...';
            _recognizedText = res.finalResult ? convertArabicDigits(res.recognizedWords.toLowerCase().trim()) : _recognizedText;
            _state = res.finalResult ? SpeechState.processing : SpeechState.listening;
            notifyListeners();
            if (res.finalResult && _recognizedText.isNotEmpty) {
              onResult(_recognizedText);
              onCommand(_recognizedText);
              if (!continuous) stopListening();
            }
          },
          localeId: 'ar_JO',
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          cancelOnError: false,
        );
      } else {
        print('Using Vosk for offline recognition');
        if (_speechService == null || _recognizer == null) {
          _errorMessage = 'خدمة Vosk أو المعرف غير متاح، يرجى إعادة التهيئة';
          _state = SpeechState.error;
          _showFeedback(context, _errorMessage, isError: true);
          notifyListeners();
          return;
        }

        try {
          await _audioCapture.stop();
          await _audioCapture.init();
          print('AudioCapture initialized before start');

          await _audioCapture.start(
                (Float32List samples) {
              _calculateMicLevel(samples);
            },
                (Object error) {
              print('Mic capture error: $error');
              _errorMessage = 'خطأ في التقاط الصوت: $error';
              _state = SpeechState.error;
              _showFeedback(context, _errorMessage, isError: true);
              notifyListeners();
            },
            sampleRate: 16000,
            bufferSize: 8192,
          );

          await _speechService!.start();
          print('Vosk SpeechService started successfully');

          int emptyResultCount = 0;
          const int maxEmptyResults = 30;

          _speechService!.onPartial().listen((partialResult) {
            String partialText = _extractTextFromJson(partialResult.toString());
            _partialText = partialText;
            print('Partial result: $_partialText');
            if (partialText == 'جارٍ الاستماع...') {
              emptyResultCount++;
              if (emptyResultCount >= maxEmptyResults && !_continuous) {
                _errorMessage = 'لم يتم التعرف على أي صوت. تأكد من أن الميكروفون يعمل وتحدث بوضوح.';
                _state = SpeechState.error;
                _showFeedback(context, _errorMessage, isError: true);
                notifyListeners();
                stopListening();
              }
            } else {
              emptyResultCount = 0;
            }
            notifyListeners();
          });

          _speechService!.onResult().listen((finalResult) {
            String recognized = _extractTextFromJson(finalResult.toString());
            print('Final result: $recognized');
            if (recognized != 'جارٍ الاستماع...' && recognized.isNotEmpty) {
              _recognizedText = convertArabicDigits(recognized.toLowerCase().trim());
              _state = SpeechState.processing;
              notifyListeners();
              onResult(_recognizedText);
              onCommand(_recognizedText);
              if (!continuous) stopListening();
            } else {
              print('Ignoring empty or invalid final result');
              if (!_continuous) {
                _errorMessage = 'لم يتم التعرف على أي صوت. تأكد من أن الميكروفون يعمل وتحدث بوضوح.';
                _state = SpeechState.error;
                _showFeedback(context, _errorMessage, isError: true);
                notifyListeners();
                stopListening();
              }
            }
          });
        } catch (e) {
          _errorMessage = 'خطأ عند بدء الاستماع: $e';
          _state = SpeechState.error;
          _showFeedback(context, _errorMessage, isError: true);
          notifyListeners();
          await stopListening();
        }
      }
    } catch (e) {
      _errorMessage = 'خطأ عند بدء الاستماع: $e';
      _state = SpeechState.error;
      _isListening = false;
      _showFeedback(context, _errorMessage, isError: true);
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    if (_useOnlineMode) {
      await _speech.stop();
      print('Online speech recognition stopped');
    } else {
      if (_speechService != null) {
        try {
          await _speechService!.stop();
          print('Vosk SpeechService stopped successfully');
        } catch (e) {
          print('Error stopping Vosk SpeechService: $e');
        }
        _speechService = null;
        print('SpeechService cleared');
      }
      await _audioCapture.stop();
      _micLevel = 0.0;
      print('AudioCapture stopped');
    }
    _isListening = false;
    _state = SpeechState.idle;
    _partialText = '';
    notifyListeners();
  }

  void clearText() {
    _recognizedText = '';
    _partialText = '';
    _micLevel = 0.0;
    notifyListeners();
  }

  String _cleanText(String text) {
    if (text.contains('text') || text.contains('partial')) {
      print('Raw JSON detected in text: $text');
      return '';
    }
    return text
        .replaceAll(RegExp(r'[^\u0600-\u06FF\s0-9]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  void _showFeedback(BuildContext context, String message, {bool isError = false}) async {
    if (ScaffoldMessenger.maybeOf(context) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    // تعطيل TTS مؤقتًا
    print('TTS: Message would have been spoken: $message');
    /*
    try {
      await _tts.setLanguage('ar-SA');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.speak(message);
      print('TTS: Message spoken: $message');
    } catch (e) {
      print('TTS error: $e');
      _errorMessage = 'خطأ في النص إلى كلام: $e';
      _state = SpeechState.error;
      notifyListeners();
    }
    */
  }

  bool containsNewInvoiceCommand(String command) {
    if (command.isEmpty) return false;
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
    if (command.isEmpty) return false;
    final cleanedCommand = _cleanText(command);
    final printKeywords = [
      'طباعة الفاتورة',
      'طبع الفاتورة',
      'print invoice',
      'print the invoice'
    ];
    bool matches = printKeywords.any((keyword) => cleanedCommand == _cleanText(keyword));
    print('Print command check: Command: $command, Cleaned: $cleanedCommand, Matches: $matches');
    return matches;
  }

  bool containsSaveCommand(String command) {
    if (command.isEmpty) return false;
    final cleanedCommand = _cleanText(command);
    final saveKeywords = [
      'حفظ الفاتورة',
      'حفظ',
      'save invoice',
      'save'
    ];
    bool matches = saveKeywords.any((keyword) => cleanedCommand == _cleanText(keyword));
    print('Save command check: Command: $command, Cleaned: $cleanedCommand, Matches: $matches');
    return matches;
  }

  Map<String, dynamic>? parseInvoiceItem(String text) {
    final cleanedText = _cleanText(text);
    print('Parsing invoice item for text: $cleanedText');

    final pattern = RegExp(r'(?:ضيف|add procedure)\s+(.+?)\s+(\d+(?:\.\d+)?)\s*$');
    final match = pattern.firstMatch(cleanedText);

    if (match != null && match.groupCount >= 2) {
      final description = match.group(1)!;
      final amountStr = match.group(2)!;
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

  @override
  void dispose() {
    print('Disposing SpeechProvider resources...');
    _speech.stop();
    _disposeVoskResources(); // استخدم الدالة الجديدة هنا
    _audioCapture.stop();
    _tts.stop();
    _isInitialized = false;
    _isListening = false;
    _isLoading = false;
    _state = SpeechState.idle;
    print('SpeechProvider disposed');
    super.dispose();
  }
}