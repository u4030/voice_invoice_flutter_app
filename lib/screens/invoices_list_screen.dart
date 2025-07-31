import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // استيراد مكتبة intl لـ DateFormat
import '../models/invoice.dart'; // استيراد ملف invoice.dart لتعريف Invoice
import '../providers/invoice_provider.dart';
import '../utils/app_constants.dart';
import '../services/pdf_service.dart';
import 'invoice_screen.dart' as invoice_screen;

class InvoicesListScreen extends StatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  State<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends State<InvoicesListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير السابقة'),
      ),
      body: Consumer<InvoiceProvider>(
        builder: (context, invoiceProvider, child) {
          if (invoiceProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            itemCount: invoiceProvider.invoices.length,
            itemBuilder: (context, index) {
              final invoice = invoiceProvider.invoices[index];
              return Card(
                child: ListTile(
                  title: Text('فاتورة رقم: ${invoice.invoiceNumber}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('التاريخ: ${invoice.dayName} ${DateFormat(AppConstants.dateFormat).format(invoice.date)}'),
                      Text('عدد العناصر: ${invoice.items.length}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${invoice.total.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editInvoice(invoice.id!),
                      ),
                      IconButton(
                        icon: const Icon(Icons.print, color: Colors.green),
                        onPressed: () => _printInvoice(invoice),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteInvoice(invoice.id!),
                      ),
                    ],
                  ),
                  onTap: () => _showInvoiceDetails(invoice),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _editInvoice(int invoiceId) async {
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    await invoiceProvider.loadInvoice(invoiceId);
    if (invoiceProvider.currentInvoice != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => invoice_screen.InvoiceScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل الفاتورة: ${invoiceProvider.errorMessage}')),
      );
    }
  }

  void _printInvoice(Invoice invoice) async {
    try {
      await PdfService.generateAndPrintInvoice(invoice);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppConstants.successInvoicePrinted)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الطباعة: $e')),
      );
    }
  }

  void _deleteInvoice(int invoiceId) async {
    final success = await Provider.of<InvoiceProvider>(context, listen: false).deleteInvoice(invoiceId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الفاتورة بنجاح')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حذف الفاتورة: ${Provider.of<InvoiceProvider>(context, listen: false).errorMessage}')),
      );
    }
  }

  void _showInvoiceDetails(Invoice invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل الفاتورة رقم: ${invoice.invoiceNumber}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('التاريخ: ${invoice.dayName} ${DateFormat(AppConstants.dateFormat).format(invoice.date)}'),
              const SizedBox(height: 8),
              Text('الإجمالي: ${invoice.total.toStringAsFixed(2)} ${AppConstants.currencySymbol}'),
              const SizedBox(height: 8),
              Text('الملاحظات: ${invoice.notes ?? "لا توجد ملاحظات"}'),
              const SizedBox(height: 8),
              Text('العناصر:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...invoice.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item.itemNumber}. ${item.description}'),
                    Text('${item.price.toStringAsFixed(2)} ${AppConstants.currencySymbol}'),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}