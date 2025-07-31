import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/nlu_result.dart';
import '../providers/invoice_provider.dart';
import '../providers/speech_provider.dart';
import '../providers/expense_provider.dart';

class CommandManager {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> executeCommand(NluResult result, BuildContext context) async {
    // Get providers, but don't listen for changes
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final speechProvider = Provider.of<SpeechProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

    if (result.intent == 'fallback') {
      _showFeedback(context, "لم أكن متأكداً مما قلته، هل يمكنك تكرار ذلك؟");
      return;
    }

    print('Executing command for intent: ${result.intent} with slots: ${result.slots}');

    // --- CONTEXT MANAGEMENT ---
    // Check for an invoice number slot to set the context.
    final invoiceIdStr = result.slots['invoiceNumber'];
    if (invoiceIdStr != null) {
      final invoiceId = int.tryParse(invoiceIdStr);
      if (invoiceId != null) {
        await invoiceProvider.loadInvoice(invoiceId);
        _showFeedback(context, 'تم تحميل الفاتورة رقم $invoiceId.');
      }
    }

    switch (result.intent) {
      case 'create_invoice':
        _handleCreateInvoice(invoiceProvider, context);
        break;

      case 'add_invoice_item':
        _handleAddInvoiceItem(result, invoiceProvider, context);
        break;

      case 'edit_invoice':
        _handleUpdateInvoiceItem(result, invoiceProvider, context);
        break;

      case 'delete_item':
        _handleDeleteInvoiceItem(result, invoiceProvider, context);
        break;

      case 'add_expense':
        _handleAddExpense(result, expenseProvider, context);
        break;

      default:
        print('Unknown intent: ${result.intent}');
        _showFeedback(context, "أنا آسف، لم أفهم هذا الأمر.");
    }
  }

  void _handleCreateInvoice(InvoiceProvider invoiceProvider, BuildContext context) {
    print('Handling createInvoice intent.');
    invoiceProvider.createNewInvoice();
    _showFeedback(context, "تم إنشاء فاتورة جديدة.");
  }

  void _handleAddInvoiceItem(NluResult result, InvoiceProvider invoiceProvider, BuildContext context) {
    print('Handling addInvoiceItem intent.');

    if (invoiceProvider.currentInvoice == null) {
      _showFeedback(context, "الرجاء تحديد فاتورة أولاً، مثلاً 'اعرض الفاتورة رقم 5'.");
      return;
    }

    final description = result.slots['description'];
    final priceStr = result.slots['price'];
    final price = priceStr != null ? double.tryParse(priceStr) : null;

    if (description != null && price != null && price > 0) {
      invoiceProvider.addItemToCurrentInvoice(
        description: description,
        price: price,
        total: price,
      );
      _showFeedback(context, 'تمت إضافة "$description" إلى الفاتورة.');
      invoiceProvider.saveCurrentInvoice();
    } else {
      _showFeedback(context, "لم أتمكن من تحديد العنصر أو السعر. حاول أن تقول 'أضف [العنصر] بسعر [السعر]'.");
    }
  }

  void _handleDeleteInvoiceItem(NluResult result, InvoiceProvider invoiceProvider, BuildContext context) async {
    print('Handling deleteInvoiceItem intent.');

    if (invoiceProvider.currentInvoice == null) {
      _showFeedback(context, "الرجاء تحديد فاتورة أولاً.");
      return;
    }

    final descriptionToDelete = result.slots['description'];
    if (descriptionToDelete == null) {
      _showFeedback(context, "لم أتمكن من تحديد العنصر الذي تريد حذفه.");
      return;
    }

    final currentInvoice = invoiceProvider.currentInvoice!;
    final itemIndex = currentInvoice.items.indexWhere(
            (item) => item.description.toLowerCase().contains(descriptionToDelete.toLowerCase())
    );

    if (itemIndex == -1) {
      _showFeedback(context, 'لم أتمكن من العثور على عنصر باسم "$descriptionToDelete".');
      return;
    }

    final confirmed = await _showConfirmationDialog(
      context,
      'تأكيد الحذف',
      'هل أنت متأكد من أنك تريد حذف العنصر "${currentInvoice.items[itemIndex].description}"؟',
    );

    if (confirmed == true) {
      invoiceProvider.removeItemFromCurrentInvoice(itemIndex);
      _showFeedback(context, "تم حذف العنصر بنجاح.");
      invoiceProvider.saveCurrentInvoice();
    } else {
      _showFeedback(context, "تم إلغاء عملية الحذف.");
    }
  }

  void _handleUpdateInvoiceItem(NluResult result, InvoiceProvider invoiceProvider, BuildContext context) async {
    print('Handling updateInvoiceItem intent.');

    if (invoiceProvider.currentInvoice == null) {
      _showFeedback(context, "الرجاء تحديد فاتورة أولاً.");
      return;
    }

    final descriptionToUpdate = result.slots['description'];
    final newPriceStr = result.slots['price'];
    final newPrice = newPriceStr != null ? double.tryParse(newPriceStr) : null;

    if (descriptionToUpdate == null || newPrice == null || newPrice <= 0) {
      _showFeedback(context, "لم أتمكن من تحديد العنصر أو السعر الجديد.");
      return;
    }

    final currentInvoice = invoiceProvider.currentInvoice!;
    final itemIndex = currentInvoice.items.indexWhere(
            (item) => item.description.toLowerCase().contains(descriptionToUpdate.toLowerCase())
    );

    if (itemIndex == -1) {
      _showFeedback(context, 'لم أتمكن من العثور على عنصر باسم "$descriptionToUpdate".');
      return;
    }

    final confirmed = await _showConfirmationDialog(
      context,
      'تأكيد التعديل',
      'هل تريد تغيير سعر "${currentInvoice.items[itemIndex].description}" إلى $newPrice؟',
    );

    if (confirmed == true) {
      invoiceProvider.updateItemInCurrentInvoice(
        itemIndex,
        price: newPrice,
        total: newPrice,
      );
      _showFeedback(context, "تم تعديل العنصر بنجاح.");
      invoiceProvider.saveCurrentInvoice();
    } else {
      _showFeedback(context, "تم إلغاء عملية التعديل.");
    }
  }

  Future<bool?> _showConfirmationDialog(BuildContext context, String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('تأكيد'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  void dispose() {
    _audioPlayer.dispose();
  }

  void _handleAddExpense(NluResult result, ExpenseProvider expenseProvider, BuildContext context) {
    print('Handling addExpense intent.');

    final description = result.slots['description'];
    final amountStr = result.slots['amount'];
    final amount = amountStr != null ? double.tryParse(amountStr) : null;

    if (description != null && amount != null && amount > 0) {
      expenseProvider.addExpense(
        description: description,
        amount: amount,
        category: result.slots['category'] ?? 'عام',
      );
      _showFeedback(context, 'تمت إضافة مصروف "$description".');
    } else {
      _showFeedback(context, "لم أتمكن من تحديد المصروف أو المبلغ.");
    }
  }

  void _showFeedback(BuildContext context, String message, {bool playSound = true}) {
    final speechProvider = Provider.of<SpeechProvider>(context, listen: false);

    // 1. Speak the feedback
    speechProvider.speak(message);

    // 2. Show a visual snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );

    // 3. Play an audio cue
    if (playSound) {
      _audioPlayer.play(AssetSource('sounds/ding.mp3'));
    }
  }
}
