import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

Future<bool> requestPermissions() async {
  final permissions = <Permission>[];
  permissions.add(Permission.microphone); // طلب الميكروفون دائمًا

  // التحقق من إصدار Android
  bool isAndroid11OrAbove = false;
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;
    isAndroid11OrAbove = sdkInt >= 30; // Android 11+
    if (sdkInt >= 33) {
      permissions.add(Permission.audio); // Android 13+
    } else if (sdkInt < 30) {
      permissions.add(Permission.storage); // Android 10 أو أقدم
    }
  }

  // طلب الأذونات
  Map<Permission, PermissionStatus> statuses = await permissions.request();

  bool allPermissionsGranted = true;
  if (!statuses[Permission.microphone]!.isGranted) {
    print('Microphone permission denied');
    allPermissionsGranted = false;
  }
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;
    if (sdkInt >= 33) {
      if (!statuses[Permission.audio]!.isGranted) {
        print('Audio permission denied');
        allPermissionsGranted = false;
      }
    } else if (sdkInt < 30) {
      if (!statuses[Permission.storage]!.isGranted) {
        print('Storage permission denied');
        allPermissionsGranted = false;
      }
    }
  }

  // طلب MANAGE_EXTERNAL_STORAGE على Android 11+
  if (Platform.isAndroid && isAndroid11OrAbove) {
    final manageStorageStatus = await Permission.manageExternalStorage.status;
    if (!manageStorageStatus.isGranted) {
      final result = await Permission.manageExternalStorage.request();
      if (!result.isGranted) {
        print('MANAGE_EXTERNAL_STORAGE not granted. Redirecting to app settings.');
        allPermissionsGranted = false;
        await openAppSettings();
      }
    }
  }

  return allPermissionsGranted;
}