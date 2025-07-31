import 'package:picovoice_flutter/picovoice_flutter.dart';

class NluResult {
  final bool isUnderstood;
  final String intent;
  final Map<String, String> slots;

  NluResult({
    required this.isUnderstood,
    required this.intent,
    required this.slots,
  });

  factory NluResult.fromRhinoInference(RhinoInference inference) {
    return NluResult(
      isUnderstood: inference.isUnderstood ?? false,
      intent: inference.intent ?? 'unknown',
      slots: inference.slots ?? {},
    );
  }

  @override
  String toString() {
    if (!isUnderstood) {
      return "Not Understood";
    }
    return 'Intent: $intent, Slots: $slots';
  }
}
