import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../providers/speech_provider_old.dart';
import '../widgets/voice_control_widget.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExpenseProvider>(context, listen: false).loadExpenses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المصروفات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddExpenseDialog,
          ),
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, expenseProvider, child) {
          if (expenseProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Voice Control
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

              // Expenses List
              Expanded(
                child: expenseProvider.expenses.isEmpty
                    ? const Center(
                        child: Text('لا توجد مصروفات'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppConstants.defaultPadding),
                        itemCount: expenseProvider.expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenseProvider.expenses[index];
                          return Card(
                            child: ListTile(
                              title: Text(expense.description),
                              subtitle: Text(expense.category),
                              trailing: Text(
                                '${expense.amount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleVoiceCommand(String command) {
    // Handle voice commands
  }

  void _handleTextRecognized(String text) {
    final speechProvider = Provider.of<SpeechProvider>(context, listen: false);
    final expense = speechProvider.parseExpense(text);

    if (expense != null) {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      expenseProvider.addExpense(
        description: expense['description'],
        amount: expense['amount'],
        category: expense['category'],
      );
    }
  }

  void _showAddExpenseDialog() {
    // Show add expense dialog
  }
}

