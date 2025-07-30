import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/invoice.dart';
import '../models/expense.dart';
import '../utils/app_constants.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConstants.databaseName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.invoicesTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL UNIQUE,
        date TEXT NOT NULL,
        day_name TEXT NOT NULL, -- Added day name
        total REAL NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.invoiceItemsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        item_number INTEGER NOT NULL, -- Added item number
        description TEXT NOT NULL,
        price REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES ${AppConstants.invoicesTable} (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.expensesTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.settingsTable} (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<int> createInvoice(Invoice invoice) async {
    final db = await instance.database;

    return await db.transaction((txn) async {
      final invoiceId = await txn.insert(AppConstants.invoicesTable, invoice.toMap());

      for (final item in invoice.items) {
        await txn.insert(
          AppConstants.invoiceItemsTable,
          item.copyWith(invoiceId: invoiceId).toMap(),
        );
      }

      return invoiceId;
    });
  }

  Future<List<Invoice>> getAllInvoices() async {
    final db = await instance.database;
    final result = await db.query(
      AppConstants.invoicesTable,
      orderBy: 'created_at DESC',
    );

    List<Invoice> invoices = [];
    for (final map in result) {
      final invoice = Invoice.fromMap(map);
      final items = await getInvoiceItems(invoice.id!);
      invoices.add(invoice.copyWith(items: items));
    }

    return invoices;
  }

  Future<Invoice?> getInvoice(int id) async {
    final db = await instance.database;
    final result = await db.query(
      AppConstants.invoicesTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      final invoice = Invoice.fromMap(result.first);
      final items = await getInvoiceItems(id);
      return invoice.copyWith(items: items);
    }
    return null;
  }

  Future<List<InvoiceItem>> getInvoiceItems(int invoiceId) async {
    final db = await instance.database;
    final result = await db.query(
      AppConstants.invoiceItemsTable,
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'item_number ASC', // Order by item number
    );

    return result.map((map) => InvoiceItem.fromMap(map)).toList();
  }

  Future<int> updateInvoice(Invoice invoice) async {
    final db = await instance.database;

    return await db.transaction((txn) async {
      await txn.update(
        AppConstants.invoicesTable,
        invoice.toMap(),
        where: 'id = ?',
        whereArgs: [invoice.id],
      );

      await txn.delete(
        AppConstants.invoiceItemsTable,
        where: 'invoice_id = ?',
        whereArgs: [invoice.id],
      );

      for (final item in invoice.items) {
        await txn.insert(
          AppConstants.invoiceItemsTable,
          item.copyWith(invoiceId: invoice.id).toMap(),
        );
      }

      return invoice.id!;
    });
  }

  Future<int> deleteInvoice(int id) async {
    final db = await instance.database;
    return await db.delete(
      AppConstants.invoicesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> createExpense(Expense expense) async {
    final db = await instance.database;
    return await db.insert(AppConstants.expensesTable, expense.toMap());
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await instance.database;
    final result = await db.query(
      AppConstants.expensesTable,
      orderBy: 'created_at DESC',
    );

    return result.map((map) => Expense.fromMap(map)).toList();
  }

  Future<List<Expense>> getExpensesByCategory(String category) async {
    final db = await instance.database;
    final result = await db.query(
      AppConstants.expensesTable,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'created_at DESC',
    );

    return result.map((map) => Expense.fromMap(map)).toList();
  }

  Future<List<Expense>> getExpensesByDateRange(DateTime start, DateTime end) async {
    final db = await instance.database;
    final result = await db.query(
      AppConstants.expensesTable,
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );

    return result.map((map) => Expense.fromMap(map)).toList();
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;
    return await db.update(
      AppConstants.expensesTable,
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    return await db.delete(
      AppConstants.expensesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      AppConstants.settingsTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await instance.database;
    final result = await db.query(
      AppConstants.settingsTable,
      where: 'key = ?',
      whereArgs: [key],
    );

    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return null;
  }

  Future<String> generateInvoiceNumber() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.invoicesTable}',
    );

    final count = result.first['count'] as int;
    return (count + 1).toString().padLeft(AppConstants.invoiceNumberLength, '0');
  }

  Future<double> getTotalInvoicesAmount() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(total) as total FROM ${AppConstants.invoicesTable}',
    );

    return (result.first['total'] as double?) ?? 0.0;
  }

  Future<double> getTotalExpensesAmount() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM ${AppConstants.expensesTable}',
    );

    return (result.first['total'] as double?) ?? 0.0;
  }

  Future<Map<String, double>> getExpensesCategoryTotals() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT category, SUM(amount) as total FROM ${AppConstants.expensesTable} GROUP BY category',
    );

    Map<String, double> categoryTotals = {};
    for (final row in result) {
      categoryTotals[row['category'] as String] = row['total'] as double;
    }

    return categoryTotals;
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}