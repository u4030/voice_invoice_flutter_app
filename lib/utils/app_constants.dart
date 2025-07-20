class AppConstants {
  static const String appName = 'تطبيق الفواتير الصوتي';
  static const String appVersion = '1.0.0';

  static const String databaseName = 'voice_invoice.db';
  static const int databaseVersion = 2;

  static const String invoicesTable = 'invoices';
  static const String invoiceItemsTable = 'invoice_items';
  static const String expensesTable = 'expenses';
  static const String settingsTable = 'settings';

  static const String defaultLocale = 'ar-SA';
  static const Duration speechTimeout = Duration(seconds: 30);
  static const Duration pauseTimeout = Duration(seconds: 3);

  static const List<String> activateMicCommands = [
    'فعل الميكروفون',
    'ابدأ التسجيل',
    'شغل الميكروفون',
    'ابدأ الاستماع',
  ];

  static const List<String> deactivateMicCommands = [
    'أوقف التسجيل',
    'أوقف الميكروفون',
    'اطفئ الميكروفون',
    'توقف عن الاستماع',
  ];

  static const List<String> confirmTextCommands = [
    'أكد النص',
    'احفظ النص',
    'موافق',
    'تأكيد',
  ];

  static const List<String> cancelTextCommands = [
    'امسح النص',
    'ألغي النص',
    'إلغاء',
    'مسح',
  ];

  static const List<String> retryCommands = [
    'أعد التسجيل',
    'جرب مرة أخرى',
    'إعادة',
  ];

  static const List<String> newInvoiceCommands = [
    'فاتورة جديدة',
    'إنشاء فاتورة',
    'فاتورة',
  ];

  static const List<String> printInvoiceCommands = [
    'اطبع الفاتورة',
    'طباعة',
    'اطبع',
  ];

  static const List<String> saveInvoiceCommands = [
    'احفظ الفاتورة',
    'حفظ',
    'احفظ',
  ];

  static const List<String> expenseCategories = [
    'التسوق',
    'الطعام',
    'النقل',
    'المنزل',
    'الصحة',
    'التعليم',
    'الترفيه',
    'أخرى',
  ];

  static const String currency = 'دينار';
  static const String currencySymbol = 'د.أ';

  static const String dateFormat = 'dd/MM/yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';

  static const String invoicesPath = 'invoices';
  static const String expensesPath = 'expenses';
  static const String backupPath = 'backup';

  static const String keyFirstRun = 'first_run';
  static const String keyUserName = 'user_name';
  static const String keyCompanyName = 'company_name';
  static const String keyCompanyAddress = 'company_address';
  static const String keyCompanyPhone = 'company_phone';
  static const String keyAutoSave = 'auto_save';
  static const String keyVoiceEnabled = 'voice_enabled';
  static const String keyDarkMode = 'dark_mode';

  static const Duration shortAnimation = Duration(milliseconds: 300);
  static const Duration mediumAnimation = Duration(milliseconds: 500);
  static const Duration longAnimation = Duration(milliseconds: 800);

  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;

  static const int maxInvoiceItems = 50;
  static const double maxItemPrice = 999999.99;
  static const int invoiceNumberLength = 6;

  static const String errorMicrophonePermission = 'يرجى السماح بالوصول للميكروفون';
  static const String errorSpeechNotAvailable = 'خدمة التعرف على الكلام غير متوفرة';
  static const String errorNetworkConnection = 'يرجى التحقق من اتصال الإنترنت';
  static const String errorDatabaseConnection = 'خطأ في الاتصال بقاعدة البيانات';
  static const String errorInvalidInput = 'المدخل غير صحيح';

  static const String successInvoiceSaved = 'تم حفظ الفاتورة بنجاح';
  static const String successInvoicePrinted = 'تم طباعة الفاتورة بنجاح';
  static const String successExpenseAdded = 'تم إضافة المصروف بنجاح';
  static const String successDataExported = 'تم تصدير البيانات بنجاح';
}