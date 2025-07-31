import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../providers/speech_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/expense_provider.dart';
import '../widgets/voice_control_widget.dart';
import '../widgets/home_card_widget.dart';
import '../widgets/statistics_widget.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import 'invoice_screen.dart' as invoice_screen;
import 'expenses_screen.dart';
import 'invoices_list_screen.dart';
import 'reports_screen.dart';
import '../services/command_manager.dart';
import '../services/nlu_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _commandManager = CommandManager();
  StreamSubscription<NluResult>? _nluSubscription;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure the context is mounted before accessing providers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  void _initializeApp() {
    final speechProvider = Provider.of<SpeechProvider>(context, listen: false);
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

    // Initialize all providers
    invoiceProvider.loadInvoices();
    expenseProvider.loadExpenses();
    speechProvider.initialize().then((_) {
      // After initialization, start the wake word listener
      speechProvider.start();
    });

    // Listen for NLU results from the provider's stream
    _nluSubscription = speechProvider.nluResultStream.listen(_handleNluResult);
  }

  @override
  void dispose() {
    _nluSubscription?.cancel();
    _commandManager.dispose();
    super.dispose();
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
                child: const VoiceControlWidget(),
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

  void _handleNluResult(NluResult result) {
    // Special handling for navigation or complex UI changes from HomeScreen
    if (result.intent == 'create_invoice') {
      _createNewInvoice(showAddItemDialog: true);
    } else if (result.intent == 'add_invoice_item') {
      // If user says "add item" from home screen, create a new invoice first
      final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
      if (!invoiceProvider.hasCurrentInvoice) {
        invoiceProvider.createNewInvoice().then((_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const invoice_screen.InvoiceScreen(),
            ),
          ).then((_) {
            // After returning from invoice screen, re-evaluate the command
            _commandManager.executeCommand(result, context);
          });
        });
      }
    }
    else {
      _commandManager.executeCommand(result, context);
    }
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
}