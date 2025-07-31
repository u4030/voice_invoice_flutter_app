import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:picovoice_flutter/picovoice_flutter.dart';
import 'package:picovoice_flutter/picovoice_error.dart';

class VoiceProcessingService {
  PicovoiceManager? _picovoiceManager;
  final Function _onWakeWordDetected;
  final Function(RhinoInference) _onInference;

  // IMPORTANT: Replace with your Picovoice Access Key
  static const String _accessKey = 'YOUR_PICOVOICE_ACCESS_KEY';

  // IMPORTANT: Ensure this path matches your asset folder structure
  static const String _keywordPath = 'assets/wake-word/marhaban-kinan.ppn';
  // IMPORTANT: This must match the name of the .rhn file you created
  static const String _contextPath = 'assets/nlu/kinan_invoice_editor_ar.rhn';

  VoiceProcessingService(this._onWakeWordDetected, this._onInference);

  Future<void> initialize() async {
    try {
      _picovoiceManager = await PicovoiceManager.create(
        _accessKey,
        _keywordPath,
        _wakeWordCallback,
        _contextPath,
        _inferenceCallback,
        (error) {
          print("Picovoice process error: $error");
        }
      );
    } on PicovoiceException catch (e) {
      print("Failed to initialize Picovoice: ${e.message}");
    }
  }

  void _wakeWordCallback() {
    print("Wake word detected!");
    _onWakeWordDetected();
  }

  void _inferenceCallback(RhinoInference inference) {
    print("Inference result: $inference");
    if (inference.isUnderstood ?? false) {
      _onInference(inference);
    } else {
      print("Command not understood.");
      // Optionally, provide feedback to the user that the command was not understood
    }
  }

  Future<void> start() async {
    if (_picovoiceManager != null) {
      try {
        await _picovoiceManager?.start();
      } on PicovoiceException catch (e) {
        print("Failed to start Picovoice: ${e.message}");
      }
    } else {
      print("Cannot start, PicovoiceManager is not initialized.");
    }
  }

  Future<void> stop() async {
    if (_picovoiceManager != null) {
      try {
        await _picovoiceManager?.stop();
      } on PicovoiceException catch (e) {
        print("Failed to stop Picovoice: ${e.message}");
      }
    }
  }

  Future<void> release() async {
    if (_picovoiceManager != null) {
      await _picovoiceManager?.stop();
      // The PicovoiceManager doesn't have a dispose/release method in this version.
      // The resources are released when the app is killed.
      _picovoiceManager = null;
    }
  }
}
