import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/invoice_provider.dart';
import '../providers/expense_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والإحصائيات'),
      ),
      body: Consumer2<InvoiceProvider, ExpenseProvider>(
        builder: (context, invoiceProvider, expenseProvider, child) {
          final invoiceStats = invoiceProvider.getInvoicesStatistics();
          final expenseStats = expenseProvider.getExpensesStatistics();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'إجمالي الفواتير',
                        '${invoiceStats['totalAmount']?.toStringAsFixed(2) ?? '0.00'} ${AppConstants.currencySymbol}',
                        Icons.receipt_long,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: AppConstants.defaultPadding),
                    Expanded(
                      child: _buildStatCard(
                        'إجمالي المصروفات',
                        '${expenseStats['totalAmount']?.toStringAsFixed(2) ?? '0.00'} ${AppConstants.currencySymbol}',
                        Icons.money_off,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppConstants.defaultPadding),
                
                // Chart placeholder
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الرسم البياني',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: AppConstants.defaultPadding),
                        Container(
                          height: 200,
                          child: const Center(
                            child: Text('الرسم البياني سيتم إضافته هنا'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const Spacer(),
              ],
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

