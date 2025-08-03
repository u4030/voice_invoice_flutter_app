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
  late final Map<String, RegExp> _regexMap;

  Future<void> loadIntents() async {
    final raw = await rootBundle.loadString('assets/intents.json');
    final list = jsonDecode(raw) as List;
    _intents = list.map((e) => _IntentDef.fromJson(e)).toList();
    _buildRegexMap();
  }

  void _buildRegexMap() {
    _regexMap = {
      'add_invoice_item': RegExp(r'^(?:ضيف|سجل|ضيفلي|سجلي)\s*(?:لي)?\s*(?:عندك)?\s+(.+?)\s+(\d+)\s*(?:دينار)?$', caseSensitive: false),
      'edit_invoice': RegExp(r'^(?:عدل|غير)\s+الفاتورة\s+رقم\s*(\d+)\s+إلى\s*(\d+)', caseSensitive: false),
      'delete_item': RegExp(r'^(?:احذف|شيل|امسح)\s+(.+)', caseSensitive: false),
      'query_invoice': RegExp(r'^(?:اعرض|عرض|اطلع لي)\s+الفاتورة\s+رقم\s*(\d+)', caseSensitive: false),
      'print_invoice': RegExp(r'^(?:اطبع|طباعة)', caseSensitive: false),
      'create_invoice': RegExp(r'^(?:أنشئ|ابدأ)\s+فاتورة', caseSensitive: false),
    };
  }

  /// Make sure to call loadIntents() once in initState
  Future<NluResult> parse(String text) async {
    text = text.trim().toLowerCase();

    for (var intentName in _regexMap.keys) {
      final match = _regexMap[intentName]!.firstMatch(text);
      if (match != null) {
        final ents = <String, dynamic>{};
        if (intentName == 'add_invoice_item') {
          ents['description'] = match.group(1)?.trim();
          ents['price'] = match.group(2);
        } else if (intentName == 'edit_invoice') {
          ents['invoiceId'] = match.group(1);
          ents['value'] = match.group(2);
        } else if (intentName == 'delete_item') {
          ents['description'] = match.group(1)?.trim();
        } else if (intentName == 'query_invoice') {
          ents['invoiceId'] = match.group(1);
        }
        // Other intents like print_invoice and create_invoice have no slots.

        return NluResult(intentName, ents);
      }
    }

    // Fallback for simple greetings or if no regex matched
    for (var def in _intents) {
      for (var p in def.patterns) {
        if (text == p) {
          return NluResult(def.name);
        }
      }
    }

    return NluResult('fallback');
  }
}
