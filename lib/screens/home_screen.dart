import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:voice_invoice_app/providers/speech_provider.dart';
import 'package:voice_invoice_app/providers/invoice_provider.dart';
import 'package:voice_invoice_app/providers/expense_provider.dart';
import 'package:voice_invoice_app/widgets/voice_control_widget.dart';
import 'package:voice_invoice_app/widgets/home_card_widget.dart';
import 'package:voice_invoice_app/widgets/statistics_widget.dart';
import 'package:voice_invoice_app/utils/app_theme.dart';
import 'package:voice_invoice_app/utils/app_constants.dart';
import 'package:voice_invoice_app/screens/invoice_screen.dart' as invoice_screen;
import 'package:voice_invoice_app/screens/expenses_screen.dart';
import 'package:voice_invoice_app/screens/invoices_list_screen.dart';
import 'package:voice_invoice_app/screens/reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final speechProvider = Provider.of<SpeechProvider>(context, listen: false);
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

    if (!speechProvider.isInitialized) {
      await speechProvider.initialize(context); // تهيئة الخدمة
    }
    await invoiceProvider.loadInvoices();
    await expenseProvider.loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تطبيق الفواتير الصوتي'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
          Consumer<SpeechProvider>(
            builder: (context, speechProvider, child) {
              return IconButton(
                icon: Icon(
                  speechProvider.useOnlineMode ? Icons.wifi : Icons.wifi_off,
                  color: Colors.white,
                ),
                tooltip: 'تبديل إلى ${speechProvider.useOnlineMode ? 'الوضع الخارجي' : 'الوضع الأونلاين'}',
                onPressed: () async {
                  if (speechProvider.isListening) {
                    await speechProvider.stopListening(); // إيقاف الاستماع أولاً
                  }
                  if (speechProvider.useOnlineMode) {
                    await speechProvider.switchToOfflineMode(context); // إضافة context
                  } else {
                    speechProvider.useOnlineMode = true; // تعيين الوضع الأونلاين
                    await speechProvider.initialize(context); // إعادة تهيئة للوضع الأونلاين
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<SpeechProvider>(
        builder: (context, speechProvider, child) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppConstants.largeBorderRadius),
                    bottomRight: Radius.circular(AppConstants.largeBorderRadius),
                  ),
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
                      const StatisticsWidget(),
                      const SizedBox(height: AppConstants.defaultPadding),
                      Text(
                        'الإجراءات السريعة',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      AnimationLimiter(
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: AppConstants.defaultPadding,
                          mainAxisSpacing: AppConstants.defaultPadding,
                          childAspectRatio: 0.9,
                          children: AnimationConfiguration.toStaggeredList(
                            duration: AppConstants.mediumAnimation,
                            childAnimationBuilder: (widget) => SlideAnimation(
                              horizontalOffset: 50.0,
                              child: FadeInAnimation(child: widget),
                            ),
                            children: [
                              HomeCardWidget(
                                title: 'فاتورة جديدة',
                                subtitle: 'إنشاء فاتورة جديدة',
                                icon: Icons.receipt_long,
                                color: AppTheme.primaryColor,
                                onTap: _createNewInvoice,
                              ),
                              HomeCardWidget(
                                title: 'الفواتير السابقة',
                                subtitle: 'عرض جميع الفواتير',
                                icon: Icons.history,
                                color: AppTheme.secondaryColor,
                                onTap: _viewInvoices,
                              ),
                              HomeCardWidget(
                                title: 'المصروفات',
                                subtitle: 'إدارة المصروفات',
                                icon: Icons.money_off,
                                color: Colors.orange,
                                onTap: _viewExpenses,
                              ),
                              HomeCardWidget(
                                title: 'التقارير',
                                subtitle: 'عرض التقارير والإحصائيات',
                                icon: Icons.analytics,
                                color: Colors.blue,
                                onTap: _viewReports,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleVoiceCommand(String command) {
    final speechProvider = Provider.of<SpeechProvider>(context, listen: false);
    print('Handling voice command in HomeScreen: $command');

    if (speechProvider.containsNewInvoiceCommand(command)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التعرف على أمر "فاتورة جديدة"، جاري الإنشاء...'),
          duration: Duration(seconds: 2),
        ),
      );
      _createNewInvoice();
    } else if (command.toLowerCase().contains('مصروف')) {
      _handleExpenseCommand(command);
    } else if (command.toLowerCase().contains('فواتير') ||
        command.toLowerCase().contains('سابق')) {
      _viewInvoices();
    } else if (command.toLowerCase().contains('تقارير') ||
        command.toLowerCase().contains('إحصائيات')) {
      _viewReports();
    } else if (command.toLowerCase().contains('مصروفات')) {
      _viewExpenses();
    } else {
      print('No voice command matched: $command');
    }
  }

  void _handleTextRecognized(String text) {
    final speechProvider = Provider.of<SpeechProvider>(context, listen: false);
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);

    print('Handling recognized text in HomeScreen: $text');
    final invoiceItem = speechProvider.parseInvoiceItem(text);
    if (invoiceItem != null) {
      print('Invoice item detected in HomeScreen: $invoiceItem');
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('تم التعرف على عنصر: ${invoiceItem['description']}'),
          duration: const Duration(seconds: 2),
        ),
      );
      if (!invoiceProvider.hasCurrentInvoice) {
        print('Creating new invoice for item: $invoiceItem');
        invoiceProvider.createNewInvoice().then((_) {
          if (invoiceProvider.currentInvoice != null) {
            print('Navigating to InvoiceScreen with item: $invoiceItem');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => invoice_screen.InvoiceScreen(initialItemData: invoiceItem),
              ),
            );
          } else {
            print('Failed to create invoice: ${invoiceProvider.errorMessage}');
            scaffoldMessenger.showSnackBar(
              SnackBar(content: Text('فشل إنشاء الفاتورة: ${invoiceProvider.errorMessage}')),
            );
          }
        });
      } else {
        print('Navigating to InvoiceScreen with existing invoice and item: $invoiceItem');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => invoice_screen.InvoiceScreen(initialItemData: invoiceItem),
          ),
        );
      }
      return;
    }

    final expense = speechProvider.parseExpense(text);
    if (expense != null) {
      print('Expense detected in HomeScreen: $expense');
      _addQuickExpense(expense);
      return;
    }

    if (speechProvider.containsNewInvoiceCommand(text)) {
      print('New invoice command detected: $text');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التعرف على أمر "فاتورة جديدة"، جاري الإنشاء...'),
          duration: Duration(seconds: 2),
        ),
      );
      _createNewInvoice(showAddItemDialog: true);
      return;
    }

    print('No invoice item, expense, or new invoice command detected: $text');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لم يتم التعرف على الأمر، حاول مرة أخرى'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _createNewInvoice({bool showAddItemDialog = false}) {
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    invoiceProvider.createNewInvoice().then((_) {
      if (invoiceProvider.currentInvoice != null) {
        print('Navigating to InvoiceScreen for new invoice, showAddItemDialog: $showAddItemDialog');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => invoice_screen.InvoiceScreen(showAddItemDialog: showAddItemDialog),
          ),
        );
      } else {
        print('Failed to create invoice: ${invoiceProvider.errorMessage}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إنشاء الفاتورة: ${invoiceProvider.errorMessage}')),
        );
      }
    });
  }

  void _viewInvoices() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InvoicesListScreen()),
    );
  }

  void _viewExpenses() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExpensesScreen()),
    );
  }

  void _viewReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReportsScreen()),
    );
  }

  void _addQuickExpense(Map<String, dynamic> expenseData) {
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

    expenseProvider.addExpense(
      description: expenseData['description'],
      amount: expenseData['amount'],
      category: expenseData['category'] ?? 'غير محدد',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم إضافة مصروف "${expenseData['description']}"'),
        action: SnackBarAction(
          label: 'عرض المصروفات',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ExpensesScreen()),
            );
          },
        ),
      ),
    );
  }

  void _handleExpenseCommand(String command) {
    final speechProvider = Provider.of<SpeechProvider>(context, listen: false);
    final expense = speechProvider.parseExpense(command);

    if (expense != null) {
      _addQuickExpense(expense);
    } else {
      _viewExpenses();
    }
  }
}