import 'package:vosk_flutter_2/vosk_flutter_2.dart';

class VoskService {
  String? _modelPath;
  Model? _model; // ✅ كائن Model
  Recognizer? _recognizer;
  SpeechService? _speechService;

  Function(String) onResult;
  Function(String) onPartialResult;
  Function(String) onError;

  VoskService({
    required this.onResult,
    required this.onPartialResult,
    required this.onError,
  });

  Future<void> initialize({List<String>? grammar}) async {
    try {
      final vosk = VoskFlutterPlugin.instance();
      final loader = ModelLoader();

      // تحميل النموذج كمسار نصي
      _modelPath = await loader.loadFromAssets('assets/models/vosk-model-ar-mgb2-0.4.zip');

      // إنشاء كائن Model من المسار
      _model = await vosk.createModel(_modelPath!);

      // تمرير كائن _model (ليس المسار النصي)
      _recognizer = await vosk.createRecognizer(model: _model!, sampleRate: 16000, grammar: grammar);

      _speechService = await vosk.initSpeechService(_recognizer!);

      _speechService!.onResult().listen(onResult);
      _speechService!.onPartial().listen(onPartialResult);
    } catch (e) {
      onError(e.toString());
    }
  }

  void startListening() {
    _speechService?.start();
  }

  void stopListening() {
    _speechService?.stop();
  }

  void dispose() {
    _speechService?.dispose();
    _model?.dispose(); // ✅ تحرير النموذج
  }
}