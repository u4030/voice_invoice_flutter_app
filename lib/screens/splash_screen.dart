import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart'; // إضافة هذا الاستيراد
import 'package:provider/provider.dart';
import '../providers/speech_provider_old.dart';
import 'home_screen.dart';
import '../utils/permissions.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'جارٍ التحقق من أذونات الميكروفون والتخزين...';

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized(); // إضافة هذه الخطوة
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // طلب الأذونات
    bool permissionsGranted = await requestPermissions();
    final speechProvider = Provider.of<SpeechProvider>(context, listen: false);

    // التحقق من إصدار Android
    bool isAndroid11OrAbove = false;
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      isAndroid11OrAbove = androidInfo.version.sdkInt >= 30; // Android 11+
    }

    if (!permissionsGranted) {
      String errorMessage = isAndroid11OrAbove
          ? 'يرجى منح أذونات الميكروفون والتخزين الشاملة. يرجى الذهاب إلى إعدادات النظام وتمكين "إدارة جميع الملفات".'
          : 'يرجى منح أذونات الميكروفون والتخزين لتتمكن من استخدام التطبيق.';
      speechProvider.updateErrorMessage(errorMessage);
      setState(() {
        _statusMessage = 'فشل التحقق من الأذونات';
      });
      return;
    }

    // فحص حالة MANAGE_EXTERNAL_STORAGE إذا كان Android 11+
    if (Platform.isAndroid && isAndroid11OrAbove) {
      final manageStorageStatus = await Permission.manageExternalStorage.status;
      if (!manageStorageStatus.isGranted) {
        speechProvider.updateErrorMessage(
            'يرجى تمكين "إدارة جميع الملفات" يدويًا من إعدادات النظام.');
        setState(() {
          _statusMessage = 'فشل التحقق من أذونات التخزين الشاملة';
        });
        await openAppSettings();
        return;
      }
    }

    // تحديث حالة التهيئة
    setState(() {
      _statusMessage = 'جارٍ تهيئة التعرف الصوتي...';
    });

    // تهيئة SpeechProvider
    await speechProvider.initialize(context);

    if (speechProvider.isInitialized) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      setState(() {
        _statusMessage = 'فشل التهيئة، يرجى المحاولة مرة أخرى. (الخطأ: ${speechProvider.errorMessage})';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Consumer<SpeechProvider>(
              builder: (context, speechProvider, child) {
                if (speechProvider.errorMessage.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          speechProvider.errorMessage,
                          style: const TextStyle(color: Colors.red, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            openAppSettings();
                          },
                          child: const Text('فتح إعدادات الأذونات'),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}