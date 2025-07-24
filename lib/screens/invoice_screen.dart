import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/invoice_provider.dart';
import '../providers/speech_provider_old.dart';
import '../models/invoice.dart';
import '../widgets/voice_control_widget.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import '../services/pdf_service.dart';

class InvoiceScreen extends StatefulWidget {
  final Map<String, dynamic>? initialItemData;
  final bool showAddItemDialog;

  const InvoiceScreen({
    super.key,
    this.initialItemData,
    this.showAddItemDialog = false,
  });

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> with SingleTickerProviderStateMixin {
  final _notesController = TextEditingController();
  late AnimationController _saveButtonController;
  late Animation<Color?> _saveButtonColor;

  @override
  void initState() {
    super.initState();
    _loadCurrentInvoice();
    _initializeAnimations();
    print('InvoiceScreen initState: initialItemData=${widget.initialItemData}, showAddItemDialog=${widget.showAddItemDialog}');
    if (widget.initialItemData != null || widget.showAddItemDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('Calling _showAddItemDialog with initialItemData: ${widget.initialItemData}');
        _showAddItemDialog(initialItemData: widget.initialItemData);
      });
    } else {
      print('No initial item data or showAddItemDialog provided to InvoiceScreen');
    }
    Provider.of<SpeechProvider>(context, listen: false).initialize(context);
  }

  void _initializeAnimations() {
    _saveButtonController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _saveButtonColor = ColorTween(
      begin: AppTheme.primaryColor,
      end: Colors.green,
    ).animate(_saveButtonController);
  }

  void _loadCurrentInvoice() {
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final currentInvoice = invoiceProvider.currentInvoice;

    if (currentInvoice != null) {
      _notesController.text = currentInvoice.notes ?? '';
      print('Loaded current invoice: ${currentInvoice.invoiceNumber}');
    } else {
      print('No current invoice found');
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _saveButtonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفاتورة الحالية'),
        actions: [
          Consumer<SpeechProvider>(
            builder: (context, speechProvider, child) {
              return IconButton(
                icon: const Icon(Icons.swap_horiz),
                onPressed: () => speechProvider.switchToOfflineMode(context),
                tooltip: 'تبديل الوضع (${speechProvider.useOnlineMode ? 'أول (أونلاين)' : 'ثاني (خارج الشبكة)'})',
                color: speechProvider.useOnlineMode ? Colors.blue : Colors.green,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveInvoice,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printInvoice,
          ),
        ],
      ),
      body: Consumer2<InvoiceProvider, SpeechProvider>(
        builder: (context, invoiceProvider, speechProvider, child) {
          final currentInvoice = invoiceProvider.currentInvoice;

          if (currentInvoice == null) {
            return const Center(
              child: Text('لا توجد فاتورة حالية'),
            );
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
                child: VoiceControlWidget(
                  onVoiceCommand: _handleVoiceCommand,
                  onTextRecognized: _handleTextRecognized,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInvoiceHeader(currentInvoice),
                      const SizedBox(height: AppConstants.defaultPadding),
                      _buildItemsSection(currentInvoice),
                      const SizedBox(height: AppConstants.defaultPadding),
                      _buildTotalSection(currentInvoice),
                      const SizedBox(height: AppConstants.defaultPadding),
                      _buildNotesSection(),
                      const SizedBox(height: AppConstants.defaultPadding),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
              if (speechProvider.state == SpeechState.loading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (speechProvider.errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(speechProvider.errorMessage, style: TextStyle(color: Colors.red)),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewItem,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInvoiceHeader(Invoice invoice) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'فاتورة رقم: ${invoice.invoiceNumber}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      invoice.dayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      DateFormat(AppConstants.dateFormat).format(invoice.date),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(Invoice invoice) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'عناصر الفاتورة',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addNewItem,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة عنصر'),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            if (invoice.items.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
                child: const Center(
                  child: Text(
                    'لا توجد عناصر في الفاتورة\nاستخدم الميكروفون أو اضغط على "إضافة عنصر"',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: invoice.items.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final item = invoice.items[index];
                  return _buildInvoiceItem(item, index);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItem(InvoiceItem item, int index) {
    return ListTile(
      title: Text('${item.itemNumber}. ${item.description}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${item.price.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () => _editItem(index),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteItem(index),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection(Invoice invoice) {
    return Card(
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الإجمالي:',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            Text(
              '${invoice.total.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملاحظات',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'أضف ملاحظات للفاتورة...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (value) => _updateNotes(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saveInvoice,
            icon: const Icon(Icons.save),
            label: const Text('حفظ الفاتورة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: AppConstants.defaultPadding),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _printInvoice,
            icon: const Icon(Icons.print),
            label: const Text('طباعة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _handleVoiceCommand(String command) {
    final speechProvider = Provider.of<SpeechProvider>(context, listen: false);
    print('Handling voice command in InvoiceScreen: $command');
    if (speechProvider.containsPrintCommand(command)) {
      print('Detected print command: $command');
      _printInvoice();
    } else if (speechProvider.containsSaveCommand(command)) {
      print('Detected save command: $command');
      _saveInvoice();
    } else {
      print('No action for command: $command');
    }
  }

  void _handleTextRecognized(String text) {
    final speechProvider = Provider.of<SpeechProvider>(context, listen: false);
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);

    print('Handling recognized text in InvoiceScreen: $text');
    final invoiceItem = speechProvider.parseInvoiceItem(text);
    if (invoiceItem != null) {
      print('Invoice item detected in InvoiceScreen: $invoiceItem');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم التعرف على عنصر: ${invoiceItem['description']}'),
          duration: const Duration(seconds: 2),
        ),
      );
      _showAddItemDialog(initialItemData: invoiceItem);
    } else {
      print('No invoice item detected for text: $text');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم التعرف على عنصر، حاول مرة أخرى'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _addNewItem() {
    _showAddItemDialog();
  }

  void _editItem(int index) {
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final item = invoiceProvider.currentInvoice!.items[index];
    _showEditItemDialog(item, index);
  }

  void _deleteItem(int index) {
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    invoiceProvider.removeItemFromCurrentInvoice(index);
  }

  void _showAddItemDialog({Map<String, dynamic>? initialItemData}) {
    print('Opening add item dialog with initial data: $initialItemData');
    final descriptionController = TextEditingController(
      text: initialItemData?['description']?.toString() ?? '',
    );
    final priceController = TextEditingController(
      text: initialItemData != null ? initialItemData['amount']?.toStringAsFixed(2) : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        if (initialItemData != null) {
          final description = descriptionController.text.trim();
          final price = double.tryParse(priceController.text) ?? 0.0;

          print('Checking initial item data: Description=$description, Price=$price');
          if (description.isNotEmpty && price > 0) {
            print('Scheduling auto-confirm for item: Description=$description, Price=$price');
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (!mounted) {
                print('Context not mounted, skipping auto-confirm');
                return;
              }
              _saveButtonController.forward().then((_) => _saveButtonController.reset());
              final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
              invoiceProvider.addItemToCurrentInvoice(
                description: description,
                price: price,
                total: price,
              );
              print('Auto-adding item to invoice: $description');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم إضافة العنصر: $description'),
                  duration: const Duration(seconds: 2),
                ),
              );
              _saveInvoice();
              Navigator.pop(context);
            });
          } else {
            print('Invalid initial item data for auto-confirm: Description=$description, Price=$price');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('بيانات العنصر غير صالحة، يرجى التحقق'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }

        return AlertDialog(
          title: const Text('إضافة عنصر جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  border: OutlineInputBorder(),
                ),
                enabled: initialItemData == null,
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'السعر',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                enabled: initialItemData == null,
              ),
            ],
          ),
          actions: initialItemData != null
              ? [
            TextButton(
              onPressed: () {
                print('Dialog cancelled');
                Navigator.pop(context);
              },
              child: const Text('إلغاء'),
            ),
          ]
              : [
            TextButton(
              onPressed: () {
                print('Dialog cancelled');
                Navigator.pop(context);
              },
              child: const Text('إلغاء'),
            ),
            AnimatedBuilder(
              animation: _saveButtonController,
              builder: (context, child) {
                return ElevatedButton(
                  onPressed: () {
                    final description = descriptionController.text.trim();
                    final price = double.tryParse(priceController.text) ?? 0.0;

                    if (description.isNotEmpty && price > 0) {
                      print('Manually adding item: Description=$description, Price=$price');
                      _saveButtonController.forward().then((_) => _saveButtonController.reset());
                      final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
                      invoiceProvider.addItemToCurrentInvoice(
                        description: description,
                        price: price,
                        total: price,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم إضافة العنصر: $description'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      _saveInvoice();
                      Navigator.pop(context);
                    } else {
                      print('Invalid manual item data: Description=$description, Price=$price');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يرجى إدخال وصف وسعر صالحين'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _saveButtonColor.value,
                  ),
                  child: const Text('حفظ'),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditItemDialog(InvoiceItem item, int index) {
    final descriptionController = TextEditingController(text: item.description);
    final priceController = TextEditingController(text: item.price.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل العنصر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'الوصف'),
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'السعر'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final description = descriptionController.text.trim();
              final price = double.tryParse(priceController.text) ?? 0.0;

              if (description.isNotEmpty && price > 0) {
                final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
                invoiceProvider.updateItemInCurrentInvoice(
                  index,
                  description: description,
                  price: price,
                  total: price,
                );
                final success = await invoiceProvider.saveCurrentInvoice();
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(AppConstants.successInvoiceSaved)),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في حفظ الفاتورة: ${invoiceProvider.errorMessage}')),
                  );
                }
                Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _updateNotes() {
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    invoiceProvider.updateInvoiceNotes(_notesController.text);
  }

  Future<void> _saveInvoice() async {
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final success = await invoiceProvider.saveCurrentInvoice();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppConstants.successInvoiceSaved)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(invoiceProvider.errorMessage)),
      );
    }
  }

  Future<void> _printInvoice() async {
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final currentInvoice = invoiceProvider.currentInvoice;

    if (currentInvoice != null) {
      try {
        await PdfService.generateAndPrintInvoice(currentInvoice);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppConstants.successInvoicePrinted)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الطباعة: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد فاتورة للطباعة')),
      );
    }
  }
}