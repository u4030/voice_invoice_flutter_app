import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../models/invoice.dart';
import '../utils/app_constants.dart';

class PdfService {
  static Future<void> generateAndPrintInvoice(Invoice invoice) async {
    final pdf = await _generateInvoicePdf(invoice);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<File> saveInvoicePdf(Invoice invoice) async {
    final pdf = await _generateInvoicePdf(invoice);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/invoice_${invoice.invoiceNumber}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<pw.Document> _generateInvoicePdf(Invoice invoice) async {
    final pdf = pw.Document();

    // Load Arabic font
    // final arabicFont = await PdfGoogleFonts.notoSansArabicRegular();
    // final arabicBoldFont = await PdfGoogleFonts.notoSansArabicBold();
    // تحميل الخطوط المحلية
    final arabicFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Black.ttf'),
    );
    final arabicBoldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicBoldFont,
        ),
        build: (pw.Context context) => [
          // الترويسة
          _buildHeader(invoice),
          pw.SizedBox(height: 20),
          // جدول العناصر
          _buildItemsTable(invoice),
          pw.SizedBox(height: 20),
          // الإجمالي الكلي
          _buildTotal(invoice),
          pw.SizedBox(height: 20),
          // الملاحظات (إن وجدت)
          if (invoice.notes != null && invoice.notes!.isNotEmpty)
            _buildNotes(invoice),
          pw.Spacer(),
          // التذييل
          _buildFooter(),
        ],
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'صفحة ${context.pageNumber} من ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 12),
          ),
        ),
      ),
    );

    return pdf;
  }

  static pw.Widget _buildHeader(Invoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.green,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'فاتورة',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                'رقم الفاتورة: ${invoice.invoiceNumber}',
                style: pw.TextStyle(
                  fontSize: 16,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                invoice.dayName, // Added day name
                style: pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                DateFormat(AppConstants.dateFormat).format(invoice.date),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(Invoice invoice) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FixedColumnWidth(50), // الرقم
        1: const pw.FlexColumnWidth(2),   // الوصف
        2: const pw.FixedColumnWidth(100), // السعر
        3: const pw.FixedColumnWidth(100), // الإجمالي
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        // رأس الجدول
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableCell('الرقم', isHeader: true),
            _buildTableCell('الوصف', isHeader: true),
            _buildTableCell('السعر', isHeader: true),
            _buildTableCell('الإجمالي', isHeader: true),
          ],
        ),
        // عناصر الفاتورة
        ...invoice.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return pw.TableRow(
            children: [
              _buildTableCell((index + 1).toString()),
              _buildTableCell(item.description, wrap: true),
              _buildTableCell('${item.price.toStringAsFixed(2)} ${AppConstants.currencySymbol}'),
              _buildTableCell('${item.total.toStringAsFixed(2)} ${AppConstants.currencySymbol}'),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false, bool wrap = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: wrap
          ? pw.Wrap(
        direction: pw.Axis.horizontal,
        children: [
          pw.Text(
            text,
            style: pw.TextStyle(
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isHeader ? 12 : 10,
            ),
            textAlign: pw.TextAlign.right,
            softWrap: true,
          ),
        ],
      )
          : pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 12 : 10,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildTotal(Invoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(color: PdfColors.green),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'الإجمالي الكلي:',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green,
            ),
          ),
          pw.Text(
            '${invoice.total.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildNotes(Invoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ملاحظات:',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            invoice.notes!,
            style: const pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(
        border  : pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Center(
        child: pw.Text(
          'شكراً لتعاملكم معنا',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green,
          ),
        ),
      ),
    );
  }

  // Generate expense report
  static Future<void> generateAndPrintExpenseReport(
      List<dynamic> expenses,
      DateTime startDate,
      DateTime endDate,
      ) async {
    final pdf = await _generateExpenseReportPdf(expenses, startDate, endDate);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<pw.Document> _generateExpenseReportPdf(
      List<dynamic> expenses,
      DateTime startDate,
      DateTime endDate,
      ) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.notoSansArabicRegular();
    final arabicBoldFont = await PdfGoogleFonts.notoSansArabicBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicBoldFont,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'تقرير المصروفات',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      'من ${DateFormat(AppConstants.dateFormat).format(startDate)} إلى ${DateFormat(AppConstants.dateFormat).format(endDate)}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Expenses Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildTableCell('التاريخ', isHeader: true),
                      _buildTableCell('الوصف', isHeader: true),
                      _buildTableCell('الفئة', isHeader: true),
                      _buildTableCell('المبلغ', isHeader: true),
                    ],
                  ),
                  // Expenses
                  ...expenses.map((expense) => pw.TableRow(
                    children: [
                      _buildTableCell(DateFormat(AppConstants.dateFormat).format(expense.date)),
                      _buildTableCell(expense.description),
                      _buildTableCell(expense.category),
                      _buildTableCell('${expense.amount.toStringAsFixed(2)} ${AppConstants.currencySymbol}'),
                    ],
                  )),
                ],
              ),

              pw.SizedBox(height: 20),

              // Total
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  border: pw.Border.all(color: PdfColors.orange),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'إجمالي المصروفات:',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.orange,
                      ),
                    ),
                    pw.Text(
                      '${expenses.fold(0.0, (sum, expense) => sum + expense.amount).toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }
}