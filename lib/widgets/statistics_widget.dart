import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/invoice_provider.dart';
import '../providers/expense_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';

class StatisticsWidget extends StatelessWidget {
  const StatisticsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<InvoiceProvider, ExpenseProvider>(
      builder: (context, invoiceProvider, expenseProvider, child) {
        final invoiceStats = invoiceProvider.getInvoicesStatistics();
        final expenseStats = expenseProvider.getExpensesStatistics();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'نظرة عامة',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    'إجمالي الفواتير',
                    '${invoiceStats['totalAmount']?.toStringAsFixed(2) ?? '0.00'} ${AppConstants.currencySymbol}',
                    Icons.receipt_long,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    'إجمالي المصروفات',
                    '${expenseStats['totalAmount']?.toStringAsFixed(2) ?? '0.00'} ${AppConstants.currencySymbol}',
                    Icons.money_off,
                    Colors.red,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppConstants.smallPadding),
            
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    'فواتير هذا الشهر',
                    '${invoiceStats['thisMonthInvoices'] ?? 0}',
                    Icons.calendar_today,
                    AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    'مصروفات هذا الشهر',
                    '${expenseStats['thisMonthExpenses'] ?? 0}',
                    Icons.trending_down,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: color,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppConstants.smallPadding),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

