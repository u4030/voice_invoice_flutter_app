import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../services/database_service.dart';

class InvoiceProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;

  List<Invoice> _invoices = [];
  Invoice? _currentInvoice;
  bool _isLoading = false;
  String _errorMessage = '';

  List<Invoice> get invoices => _invoices;
  Invoice? get currentInvoice => _currentInvoice;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get hasCurrentInvoice => _currentInvoice != null;

  // Future<void> createNewInvoice() async {
  //   try {
  //     _setLoading(true);
  //     _setError('');
  //
  //     final invoiceNumber = await _databaseService.generateInvoiceNumber();
  //     final now = DateTime.now();
  //     final dayName = DateFormat('EEEE', 'ar').format(now); // Get day name in Arabic
  //
  //     _currentInvoice = Invoice(
  //       invoiceNumber: invoiceNumber,
  //       date: now,
  //       dayName: dayName, // Added day name
  //       items: [],
  //       total: 0.0,
  //       createdAt: now,
  //       updatedAt: now,
  //     );
  //
  //     notifyListeners();
  //   } catch (e) {
  //     _setError('خطأ في إنشاء فاتورة جديدة: $e');
  //   } finally {
  //     _setLoading(false);
  //   }
  // }

  Future<void> createNewInvoice() async {
    try {
      _setLoading(true);
      _setError('');

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // البحث عن فاتورة لهذا اليوم
      final todayInvoices = _invoices.where((invoice) {
        return invoice.date.isAfter(todayStart.subtract(const Duration(days: 1))) &&
            invoice.date.isBefore(todayEnd);
      }).toList();

      if (todayInvoices.isNotEmpty) {
        // إذا وجدت فاتورة، قم بتحميلها
        _currentInvoice = todayInvoices.first;
        print('Loaded existing invoice for today: ${_currentInvoice!.invoiceNumber}');
      } else {
        // إذا لم توجد فاتورة، قم بإنشاء واحدة جديدة
        final invoiceNumber = await _databaseService.generateInvoiceNumber();
        final dayName = DateFormat('EEEE', 'ar').format(now);

        _currentInvoice = Invoice(
          invoiceNumber: invoiceNumber,
          date: now,
          dayName: dayName,
          items: [],
          total: 0.0,
          createdAt: now,
          updatedAt: now,
        );
        print('Created new invoice: $invoiceNumber');
      }

      notifyListeners();
    } catch (e) {
      _setError('خطأ في إنشاء أو تحميل فاتورة: $e');
    } finally {
      _setLoading(false);
    }
  }

  void addItemToCurrentInvoice({
    required String description,
    required double price,
    required double total,
  }) {
    if (_currentInvoice == null) return;

    final itemNumber = _currentInvoice!.items.length + 1; // Auto-generate item number
    final item = InvoiceItem(
      itemNumber: itemNumber, // Set item number
      description: description,
      price: price,
      total: total,
    );

    final updatedItems = List<InvoiceItem>.from(_currentInvoice!.items)..add(item);
    final newTotal = updatedItems.fold(0.0, (sum, item) => sum + item.total);

    _currentInvoice = _currentInvoice!.copyWith(
      items: updatedItems,
      total: newTotal,
      updatedAt: DateTime.now(),
    );

    notifyListeners();
  }

  void updateItemInCurrentInvoice(int index, {
    String? description,
    double? price,
    double? total,
  }) {
    if (_currentInvoice == null || index >= _currentInvoice!.items.length) return;

    final updatedItems = List<InvoiceItem>.from(_currentInvoice!.items);
    final currentItem = updatedItems[index];

    updatedItems[index] = currentItem.copyWith(
      description: description ?? currentItem.description,
      price: price ?? currentItem.price,
      total: total ?? currentItem.total,
    );

    // Reassign item numbers
    for (int i = 0; i < updatedItems.length; i++) {
      updatedItems[i] = updatedItems[i].copyWith(itemNumber: i + 1);
    }

    final newTotal = updatedItems.fold(0.0, (sum, item) => sum + item.total);

    _currentInvoice = _currentInvoice!.copyWith(
      items: updatedItems,
      total: newTotal,
      updatedAt: DateTime.now(),
    );

    notifyListeners();
  }

  void removeItemFromCurrentInvoice(int index) {
    if (_currentInvoice == null || index >= _currentInvoice!.items.length) return;

    final updatedItems = List<InvoiceItem>.from(_currentInvoice!.items)..removeAt(index);

    // Reassign item numbers
    for (int i = 0; i < updatedItems.length; i++) {
      updatedItems[i] = updatedItems[i].copyWith(itemNumber: i + 1);
    }

    final newTotal = updatedItems.fold(0.0, (sum, item) => sum + item.total);

    _currentInvoice = _currentInvoice!.copyWith(
      items: updatedItems,
      total: newTotal,
      updatedAt: DateTime.now(),
    );

    notifyListeners();
  }

  void updateInvoiceNotes(String notes) {
    if (_currentInvoice == null) return;

    _currentInvoice = _currentInvoice!.copyWith(
      notes: notes,
      updatedAt: DateTime.now(),
    );

    notifyListeners();
  }

  Future<bool> saveCurrentInvoice() async {
    if (_currentInvoice == null) return false;

    try {
      _setLoading(true);
      _setError('');

      if (_currentInvoice!.id == null) {
        final id = await _databaseService.createInvoice(_currentInvoice!);
        _currentInvoice = _currentInvoice!.copyWith(id: id);
      } else {
        await _databaseService.updateInvoice(_currentInvoice!);
      }

      await loadInvoices();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('خطأ في حفظ الفاتورة: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadInvoices() async {
    try {
      _setLoading(true);
      _setError('');

      _invoices = await _databaseService.getAllInvoices();
      notifyListeners();
    } catch (e) {
      _setError('خطأ في تحميل الفواتير: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadInvoice(int id) async {
    try {
      _setLoading(true);
      _setError('');

      _currentInvoice = await _databaseService.getInvoice(id);
      notifyListeners();
    } catch (e) {
      _setError('خطأ في تحميل الفاتورة: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteInvoice(int id) async {
    try {
      _setLoading(true);
      _setError('');

      await _databaseService.deleteInvoice(id);
      await loadInvoices();

      if (_currentInvoice?.id == id) {
        _currentInvoice = null;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError('خطأ في حذف الفاتورة: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void clearCurrentInvoice() {
    _currentInvoice = null;
    notifyListeners();
  }

  Future<double> getTotalInvoicesAmount() async {
    try {
      return await _databaseService.getTotalInvoicesAmount();
    } catch (e) {
      _setError('خطأ في حساب إجمالي الفواتير: $e');
      return 0.0;
    }
  }

  List<Invoice> searchInvoices(String query) {
    if (query.isEmpty) return _invoices;

    final lowerQuery = query.toLowerCase();
    return _invoices.where((invoice) {
      return invoice.invoiceNumber.toLowerCase().contains(lowerQuery) ||
          invoice.items.any((item) =>
              item.description.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  List<Invoice> filterInvoicesByDateRange(DateTime start, DateTime end) {
    return _invoices.where((invoice) {
      return invoice.date.isAfter(start.subtract(const Duration(days: 1))) &&
          invoice.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  Map<String, dynamic> getInvoicesStatistics() {
    if (_invoices.isEmpty) {
      return {
        'totalInvoices': 0,
        'totalAmount': 0.0,
        'averageAmount': 0.0,
        'thisMonthInvoices': 0,
        'thisMonthAmount': 0.0,
      };
    }

    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);

    final thisMonthInvoices = _invoices.where((invoice) {
      return invoice.date.isAfter(thisMonth.subtract(const Duration(days: 1))) &&
          invoice.date.isBefore(nextMonth);
    }).toList();

    final totalAmount = _invoices.fold(0.0, (sum, invoice) => sum + invoice.total);
    final thisMonthAmount = thisMonthInvoices.fold(0.0, (sum, invoice) => sum + invoice.total);

    return {
      'totalInvoices': _invoices.length,
      'totalAmount': totalAmount,
      'averageAmount': totalAmount / _invoices.length,
      'thisMonthInvoices': thisMonthInvoices.length,
      'thisMonthAmount': thisMonthAmount,
    };
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }
}