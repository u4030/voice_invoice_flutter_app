import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/nlu_result.dart';

class _IntentDef {
  final String name;
  final List<String> patterns;
  final String response;
  _IntentDef({required this.name, required this.patterns, required this.response});
  factory _IntentDef.fromJson(Map<String, dynamic> j) => _IntentDef(
    name: j['intent'],
    patterns: List<String>.from(j['patterns']),
    response: j['response'],
  );
}

class LocalNluService {
  late final List<_IntentDef> _intents;

  Future<void> loadIntents() async {
    final raw = await rootBundle.loadString('assets/intents.json');
    final list = jsonDecode(raw) as List;
    _intents = list.map((e) => _IntentDef.fromJson(e)).toList();
  }

  /// Make sure to call loadIntents() once in initState
  Future<NluResult> parse(String text) async {
    text = text.toLowerCase();
    for (var def in _intents) {
      for (var p in def.patterns) {
        if (text.contains(p)) {
          final ents = <String, dynamic>{};
          if (def.name == 'edit_invoice') {
            final mId = RegExp(r'رقم\s*(\d+)').firstMatch(text);
            final mVal = RegExp(r'إلى\s*(\d+)').firstMatch(text);
            if (mId != null) ents['invoiceId'] = mId.group(1);
            if (mVal != null) ents['value']     = mVal.group(1);
          }
          // Add other entity extraction logic here for other intents
          return NluResult(def.name, ents);
        }
      }
    }
    // If no pattern matched
    return NluResult('fallback');
  }
}
