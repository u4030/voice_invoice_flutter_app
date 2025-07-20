import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/database_service.dart';
import '../utils/app_constants.dart';

class ExpenseProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;

  List<Expense> _expenses = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _selectedCategory = '';

  // Getters
  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;

  // Add new expense
  Future<bool> addExpense({
    required String description,
    required double amount,
    required String category,
    String? notes,
    DateTime? date,
  }) async {
    try {
      _setLoading(true);
      _setError('');

      final now = DateTime.now();
      final expense = Expense(
        description: description,
        amount: amount,
        category: category,
        date: date ?? now,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );

      await _databaseService.createExpense(expense);
      await loadExpenses();
      return true;
    } catch (e) {
      _setError('خطأ في إضافة المصروف: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Load all expenses
  Future<void> loadExpenses() async {
    try {
      _setLoading(true);
      _setError('');

      _expenses = await _databaseService.getAllExpenses();
      notifyListeners();
    } catch (e) {
      _setError('خطأ في تحميل المصروفات: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load expenses by category
  Future<void> loadExpensesByCategory(String category) async {
    try {
      _setLoading(true);
      _setError('');

      _selectedCategory = category;
      if (category.isEmpty) {
        _expenses = await _databaseService.getAllExpenses();
      } else {
        _expenses = await _databaseService.getExpensesByCategory(category); // تمرير الوسيط category
      }
      notifyListeners();
    } catch (e) {
      _setError('خطأ في تحميل المصروفات: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load expenses by date range
  Future<void> loadExpensesByDateRange(DateTime start, DateTime end) async {
    try {
      _setLoading(true);
      _setError('');

      _expenses = await _databaseService.getExpensesByDateRange(start, end);
      notifyListeners();
    } catch (e) {
      _setError('خطأ في تحميل المصروفات: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Update expense
  Future<bool> updateExpense(Expense expense) async {
    try {
      _setLoading(true);
      _setError('');

      final updatedExpense = expense.copyWith(updatedAt: DateTime.now());
      await _databaseService.updateExpense(updatedExpense);
      await loadExpenses();
      return true;
    } catch (e) {
      _setError('خطأ في تحديث المصروف: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete expense
  Future<bool> deleteExpense(int id) async {
    try {
      _setLoading(true);
      _setError('');

      await _databaseService.deleteExpense(id);
      await loadExpenses();
      return true;
    } catch (e) {
      _setError('خطأ في حذف المصروف: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get total expenses amount
  Future<double> getTotalExpensesAmount() async {
    try {
      return await _databaseService.getTotalExpensesAmount();
    } catch (e) {
      _setError('خطأ في حساب إجمالي المصروفات: $e');
      return 0.0;
    }
  }

  // Get expenses by category
  Future<Map<String, double>> getExpensesByCategory() async {
    try {
      return await _databaseService.getExpensesCategoryTotals();
    } catch (e) {
      _setError('خطأ في تحميل المصروفات حسب الفئة: $e');
      return {};
    }
  }

  // Search expenses
  List<Expense> searchExpenses(String query) {
    if (query.isEmpty) return _expenses;

    final lowerQuery = query.toLowerCase();
    return _expenses.where((expense) {
      return expense.description.toLowerCase().contains(lowerQuery) ||
          expense.category.toLowerCase().contains(lowerQuery) ||
          (expense.notes?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // Filter expenses by category
  List<Expense> filterExpensesByCategory(String category) {
    if (category.isEmpty) return _expenses;
    return _expenses.where((expense) => expense.category == category).toList();
  }

  // Filter expenses by date range
  List<Expense> filterExpensesByDateRange(DateTime start, DateTime end) {
    return _expenses.where((expense) {
      return expense.date.isAfter(start.subtract(const Duration(days: 1))) &&
          expense.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  // Get expenses statistics
  Map<String, dynamic> getExpensesStatistics() {
    if (_expenses.isEmpty) {
      return {
        'totalExpenses': 0,
        'totalAmount': 0.0,
        'averageAmount': 0.0,
        'thisMonthExpenses': 0,
        'thisMonthAmount': 0.0,
        'categoriesCount': 0,
      };
    }

    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);

    final thisMonthExpenses = _expenses.where((expense) {
      return expense.date.isAfter(thisMonth.subtract(const Duration(days: 1))) &&
          expense.date.isBefore(nextMonth);
    }).toList();

    final totalAmount = _expenses.fold(0.0, (sum, expense) => sum + expense.amount);
    final thisMonthAmount = thisMonthExpenses.fold(0.0, (sum, expense) => sum + expense.amount);

    final categories = _expenses.map((e) => e.category).toSet();

    return {
      'totalExpenses': _expenses.length,
      'totalAmount': totalAmount,
      'averageAmount': totalAmount / _expenses.length,
      'thisMonthExpenses': thisMonthExpenses.length,
      'thisMonthAmount': thisMonthAmount,
      'categoriesCount': categories.length,
    };
  }

  // Get monthly expenses trend
  Map<String, double> getMonthlyExpensesTrend() {
    final Map<String, double> monthlyTrend = {};

    for (final expense in _expenses) {
      final monthKey = '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}';
      monthlyTrend[monthKey] = (monthlyTrend[monthKey] ?? 0.0) + expense.amount;
    }

    return monthlyTrend;
  }

  // Get category distribution
  Map<String, double> getCategoryDistribution() {
    final Map<String, double> distribution = {};

    for (final expense in _expenses) {
      distribution[expense.category] = (distribution[expense.category] ?? 0.0) + expense.amount;
    }

    return distribution;
  }

  // Set selected category
  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // Clear selected category
  void clearSelectedCategory() {
    _selectedCategory = '';
    notifyListeners();
  }

  // Private methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }
}