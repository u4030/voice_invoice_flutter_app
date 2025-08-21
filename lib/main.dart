

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'services/vosk_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

import 'providers/speech_provider.dart';
import 'providers/invoice_provider.dart';
import 'providers/expense_provider.dart';
import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'utils/app_theme.dart';
import 'utils/app_constants.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  final voskService = VoskService(
    onResult: (result) {
      if (result.contains('مرحبا')) {
        service.invoke('wakeDetected');
      }
    },
    onPartialResult: (partial) {
      if (partial.contains('مرحبا')) {
        service.invoke('wakeDetected');
      }
    },
    onError: (error) {
      print('Background Vosk Error: $error');
    },
  );

  await voskService.initialize();
  voskService.startListening();
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'تطبيق الفواتير الصوتي',
      initialNotificationContent: 'يعمل في الخلفية',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );
  await service.startService();
}

Future<void> _createNotificationChannel() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', // نفس ID اللي بنستخدمه في الخدمة
    'خدمة التطبيق',
    description: 'القناة الخاصة بالخدمة الخلفية',
    importance: Importance.high,
  );

  final androidPlugin =
  flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(channel);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // إنشاء قناة إشعار FGS
  if (Platform.isAndroid) {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    await _createNotificationChannel();
  }

  // اطلب الأذونات
  await _requestPermissions();

  // ابدأ الخدمة
  await initializeService();

  // قاعدة البيانات
  await DatabaseService.instance.database;

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const VoiceInvoiceApp());
}

Future<void> _requestPermissions() async {
  final permissions = [
    Permission.microphone,
    Permission.notification,
  ];
  for (var permission in permissions) {
    if (await permission.isDenied) {
      await permission.request();
    }
  }
}

class VoiceInvoiceApp extends StatelessWidget {
  const VoiceInvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SpeechProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'تطبيق الفواتير الصوتي',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: const Locale('ar', 'JO'),
        supportedLocales: const [
          Locale('ar', 'JO'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeScreen(),
      ),
    );
  }
}
