import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
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
  bool _isIntentsInitialized = false; // متغير لتتبع حالة التهيئة
  final Map<String, String> _numberWords = {
    'واحد': '1',
    'اثنين': '2',
    'ثلاثة': '3',
    'اربعة': '4',
    'خمسة': '5',
    'ستة': '6',
    'سبعة': '7',
    'ثمانية': '8',
    'تسعة': '9',
    'عشرة': '10',
    'احد عشر': '11',
    'اثني عشر': '12',
    'ثلاثة عشر': '13',
    'اربعة عشر': '14',
    'خمسة عشر': '15',
    'ستة عشر': '16',
    'سبعة عشر': '17',
    'ثمانية عشر': '18',
    'تسعة عشر': '19',
    'عشرين': '20',
    'ثلاثين': '30',
    'اربعين': '40',
    'خمسين': '50',
    'ستين': '60',
    'سبعين': '70',
    'ثمانين': '80',
    'تسعين': '90',
    'مائة': '100',
    'واحدة': '1',
    'اثنتين': '2',
    'ثلاث': '3',
    'اربع': '4',
    'خمس': '5',
    'ست': '6',
    'سبع': '7',
    'ثمان': '8',
    'تسع': '9',
    'عشر': '10',
    'بواحد': '1',
    'باثنين': '2',
    'بثلاثة': '3',
    'باربعة': '4',
    'بخمسة': '5',
    'بستة': '6',
    'بسبعة': '7',
    'بثمانية': '8',
    'بتسعة': '9',
    'بعشرة': '10',
    'بخمس': '5',
    'بست': '6',
    'بسبع': '7',
    'بثمان': '8',
    'بتسع': '9',
    'دنانير': '',
    'دينار': '',
  };

  LocalNluService() {
    _regexMap = {
      'add_invoice_item': RegExp(r'^(?:ضيفلي|سجلي|ضيف لي|ضيف لي عندك|سجلي عندك)\s+(.+?)(?:\s*ب\s*(\d+(?:\.\d+)?)?)?', caseSensitive: false),
      'edit_invoice': RegExp(r'^(?:عدّل|غير|تعديل)\s+الفاتورة\s+رقم\s*(\d+)\s*(.+)?', caseSensitive: false),
      'delete_item': RegExp(r'^(?:احذف|شيل|امسح)\s+(.+)', caseSensitive: false),
      'query_invoice': RegExp(r'^(?:اعرض|عرض|اطلع لي)\s+الفاتورة\s+رقم\s*(\d+)', caseSensitive: false),
      'print_invoice': RegExp(r'^(?:اطبع|طباعة)', caseSensitive: false),
      'create_invoice': RegExp(r'^(?:أنشئ|ابدأ)\s+فاتورة', caseSensitive: false),
    };
  }

  Future<void> loadIntents() async {
    if (_isIntentsInitialized) {
      print('Intents already initialized, skipping load.');
      return;
    }
    final String jsonString = await rootBundle.loadString('assets/intents.json');
    final List<dynamic> jsonData = jsonDecode(jsonString);
    _intents = jsonData.map((json) => _IntentDef.fromJson(json)).toList();
    _isIntentsInitialized = true; // تحديث حالة التهيئة
    print('Intents initialized successfully.');
  }

  // دالة لاسترداد أنماط نية معينة
  List<String> getIntentPatterns(String intentName) {
    final intent = _intents.firstWhere(
          (def) => def.name == intentName,
      orElse: () => _IntentDef(name: intentName, patterns: [], response: ''),
    );
    return intent.patterns;
  }

  // دالة لاسترداد استجابة النية
  String getIntentResponse(String intentName) {
    final intent = _intents.firstWhere(
          (def) => def.name == intentName,
      orElse: () => _IntentDef(name: intentName, patterns: [], response: ''),
    );
    return intent.response;
  }

  String _convertNumberWords(String text) {
    String processedText = text.toLowerCase();
    final sortedKeys = _numberWords.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final key in sortedKeys) {
      processedText = processedText.replaceAll(key, _numberWords[key]!);
    }
    return processedText;
  }

  Future<NluResult> parse(String text) async {
    text = _convertNumberWords(text);
    print('Processed text after number conversion: $text');
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
        print('NLU Result: Intent=$intentName, Slots=$ents');
        return NluResult(intentName, ents);
      }
    }

    for (var def in _intents) {
      for (var p in def.patterns) {
        if (text == p.toLowerCase()) {
          print('NLU Result: Intent=${def.name}, Slots={}');
          return NluResult(def.name);
        }
      }
    }

    print('NLU Result: Intent=fallback, Slots={}');
    return NluResult('fallback');
  }
}