import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// مدير خدمات الصوت - يدير التبديل بين الوضع الأونلاين والأوفلاين
/// ويحل مشكلة تضارب الخدمات
class SpeechServiceManager extends ChangeNotifier {
  static final SpeechServiceManager _instance = SpeechServiceManager._internal();
  factory SpeechServiceManager() => _instance;
  SpeechServiceManager._internal();

  // حالة المدير
  bool _isInitialized = false;
  bool _isOnlineMode = true;
  bool _isListening = false;
  bool _isLoading = false;
  String _errorMessage = '';
  String _lastRecognizedText = '';

  // خدمات الصوت
  dynamic _onlineService;
  dynamic _offlineService;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isOnlineMode => _isOnlineMode;
  bool get isListening => _isListening;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get lastRecognizedText => _lastRecognizedText;

  /// تهيئة المدير
  Future<bool> initialize(BuildContext context) async {
    if (_isInitialized) {
      print('SpeechServiceManager already initialized');
      return true;
    }

    try {
      _isLoading = true;
      notifyListeners();

      // التحقق من إذن الميكروفون
      if (!await _checkMicrophonePermission()) {
        _errorMessage = 'لم يتم منح إذن الميكروفون';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // تهيئة الخدمة الأونلاين أولاً
      await _initializeOnlineService();

      // مراقبة حالة الاتصال
      // _setupConnectivityListener();

      _isInitialized = true;
      _isLoading = false;
      _errorMessage = '';
      notifyListeners();

      print('SpeechServiceManager initialized successfully');
      return true;
    } catch (e) {
      _errorMessage = 'خطأ في تهيئة مدير خدمات الصوت: $e';
      _isLoading = false;
      notifyListeners();
      print('SpeechServiceManager initialization failed: $e');
      return false;
    }
  }

  /// التحقق من إذن الميكروفون
  Future<bool> _checkMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  /// تهيئة الخدمة الأونلاين
  Future<void> _initializeOnlineService() async {
    try {
      // هنا يمكن تهيئة خدمة speech_to_text
      print('Online service initialized');
    } catch (e) {
      print('Error initializing online service: $e');
      throw e;
    }
  }

  /// تهيئة الخدمة الأوفلاين
  Future<void> _initializeOfflineService(BuildContext context) async {
    try {
      // تنظيف أي خدمة أوفلاين موجودة
      await _cleanupOfflineService();

      // هنا يمكن تهيئة خدمة Vosk
      print('Offline service initialized');
    } catch (e) {
      print('Error initializing offline service: $e');
      throw e;
    }
  }

  /// تنظيف الخدمة الأوفلاين
  Future<void> _cleanupOfflineService() async {
    if (_offlineService != null) {
      try {
        // إيقاف الخدمة الحالية
        await _offlineService.dispose();
        _offlineService = null;
        
        // انتظار للتأكد من التحرير الكامل
        await Future.delayed(Duration(milliseconds: 1000));
        
        print('Offline service cleaned up');
      } catch (e) {
        print('Error cleaning up offline service: $e');
        _offlineService = null;
      }
    }
  }

  /// إعداد مراقب حالة الاتصال
  // void _setupConnectivityListener() {
  //   _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
  //     bool hasConnection = result != ConnectivityResult.none;
  //
  //     if (!hasConnection && _isOnlineMode) {
  //       print('Connection lost, suggesting offline mode');
  //       _suggestOfflineMode();
  //     } else if (hasConnection && !_isOnlineMode) {
  //       print('Connection restored, suggesting online mode');
  //       _suggestOnlineMode();
  //     }
  //   }) as StreamSubscription<ConnectivityResult>?;
  // }

  /// اقتراح التبديل للوضع الأوفلاين
  void _suggestOfflineMode() {
    _errorMessage = 'انقطع الاتصال بالإنترنت. يُنصح بالتبديل للوضع الأوفلاين.';
    notifyListeners();
  }

  /// اقتراح التبديل للوضع الأونلاين
  void _suggestOnlineMode() {
    _errorMessage = 'تم استعادة الاتصال بالإنترنت. يمكنك التبديل للوضع الأونلاين.';
    notifyListeners();
  }

  /// التبديل بين الأوضاع
  Future<bool> switchMode(BuildContext context, {bool? forceOffline}) async {
    if (!_isInitialized || _isListening) {
      _errorMessage = 'لا يمكن التبديل أثناء الاستماع أو قبل التهيئة';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      bool targetMode = forceOffline ?? !_isOnlineMode;

      if (targetMode) {
        // التبديل للوضع الأوفلاين
        await _cleanupOfflineService();
        await _initializeOfflineService(context);
        _isOnlineMode = false;
        _showMessage(context, 'تم التبديل للوضع الأوفلاين');
      } else {
        // التبديل للوضع الأونلاين
        await _cleanupOfflineService();
        await _initializeOnlineService();
        _isOnlineMode = true;
        _showMessage(context, 'تم التبديل للوضع الأونلاين');
      }

      _isLoading = false;
      _errorMessage = '';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'خطأ في التبديل بين الأوضاع: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// بدء الاستماع
  Future<void> startListening({
    required BuildContext context,
    required Function(String) onResult,
    Function(String)? onPartialResult,
    Function()? onComplete,
    Function(String)? onError,
  }) async {
    if (!_isInitialized || _isListening || _isLoading) {
      onError?.call('الخدمة غير متاحة حالياً');
      return;
    }

    try {
      _isListening = true;
      notifyListeners();

      if (_isOnlineMode) {
        await _startOnlineListening(
          context: context,
          onResult: onResult,
          onPartialResult: onPartialResult,
          onComplete: onComplete,
          onError: onError,
        );
      } else {
        await _startOfflineListening(
          context: context,
          onResult: onResult,
          onPartialResult: onPartialResult,
          onComplete: onComplete,
          onError: onError,
        );
      }
    } catch (e) {
      _isListening = false;
      onError?.call('خطأ في بدء الاستماع: $e');
      notifyListeners();
    }
  }

  /// بدء الاستماع الأونلاين
  Future<void> _startOnlineListening({
    required BuildContext context,
    required Function(String) onResult,
    Function(String)? onPartialResult,
    Function()? onComplete,
    Function(String)? onError,
  }) async {
    // تنفيذ الاستماع الأونلاين
    print('Starting online listening...');
    
    // محاكاة الاستماع
    await Future.delayed(Duration(seconds: 2));
    
    _lastRecognizedText = 'نص تجريبي من الوضع الأونلاين';
    onResult(_lastRecognizedText);
    onComplete?.call();
    
    _isListening = false;
    notifyListeners();
  }

  /// بدء الاستماع الأوفلاين
  Future<void> _startOfflineListening({
    required BuildContext context,
    required Function(String) onResult,
    Function(String)? onPartialResult,
    Function()? onComplete,
    Function(String)? onError,
  }) async {
    // تنفيذ الاستماع الأوفلاين
    print('Starting offline listening...');
    
    // محاكاة الاستماع
    await Future.delayed(Duration(seconds: 3));
    
    _lastRecognizedText = 'نص تجريبي من الوضع الأوفلاين';
    onResult(_lastRecognizedText);
    onComplete?.call();
    
    _isListening = false;
    notifyListeners();
  }

  /// إيقاف الاستماع
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      if (_isOnlineMode) {
        // إيقاف الاستماع الأونلاين
        print('Stopping online listening...');
      } else {
        // إيقاف الاستماع الأوفلاين
        print('Stopping offline listening...');
      }

      _isListening = false;
      notifyListeners();
    } catch (e) {
      print('Error stopping listening: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  /// عرض رسالة للمستخدم
  void _showMessage(BuildContext context, String message) {
    if (ScaffoldMessenger.maybeOf(context) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// تنظيف الموارد
  Future<void> dispose() async {
    print('Disposing SpeechServiceManager...');
    
    await stopListening();
    await _cleanupOfflineService();
    await _connectivitySubscription?.cancel();
    
    _isInitialized = false;
    _isListening = false;
    _isLoading = false;
    
    super.dispose();
    print('SpeechServiceManager disposed');
  }

  /// إعادة تعيين المدير
  Future<void> reset() async {
    await dispose();
    _isInitialized = false;
    _errorMessage = '';
    _lastRecognizedText = '';
  }

  /// الحصول على معلومات حالة الخدمة
  Map<String, dynamic> getServiceInfo() {
    return {
      'isInitialized': _isInitialized,
      'isOnlineMode': _isOnlineMode,
      'isListening': _isListening,
      'isLoading': _isLoading,
      'errorMessage': _errorMessage,
      'lastRecognizedText': _lastRecognizedText,
    };
  }
}

