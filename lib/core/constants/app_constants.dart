// ignore_for_file: constant_identifier_names
/// ثوابت مركزية للتطبيق
class AppConstants {
  static const String appNameEn = 'SANAD';
  static const String appNameAr = 'سند';
  static const String appFullName = 'SANAD — سند';

  // Document prefixes
  static const String recPrefix = 'REC';
  static const String delPrefix = 'DEL';
  static const String invPrefix = 'INV';
  static const String supPrefix = 'SUP';
  static const String cusPrefix = 'CUS';

  // Sequences keys
  static const String seqReceipt = 'receipt';
  static const String seqDelivery = 'delivery';
  static const String seqInventory = 'inventory';
  static const String seqSupplier = 'supplier';
  static const String seqCustomer = 'customer';

  // Scanner
  static const int scannerDebounceMs = 400;
  static const String scannerBroadcastAction =
      'com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED';
  static const String scannerChannel = 'com.sanad.scanner/stream';

  // Storage folders
  static const String dirSuppliers = 'Suppliers';
  static const String dirCustomers = 'Customers';
  static const String dirInventory = 'Inventory';
  static const String dirReceipts = 'Receipts';
  static const String dirDeliveries = 'Deliveries';
  static const String dirBackups = 'Backups';

  // Settings keys
  static const String kStoreName = 'store_name';
  static const String kCompanyName = 'company_name';
  static const String kAddress = 'address';
  static const String kPhone = 'phone';
  static const String kAllowNegativeStock = 'allow_negative_stock';
  static const String kScannerBeep = 'scanner_beep';
  static const String kScannerVibrate = 'scanner_vibrate';
  static const String kScannerDebounce = 'scanner_debounce_ms';
  // الإرسال للكمبيوتر عبر الشبكة المحلية (SMB)
  static const String kPcHost = 'pc_host';
  static const String kPcShare = 'pc_share';
  static const String kPcUser = 'pc_user';
  static const String kPcPass = 'pc_pass';
  static const String kPcFolder = 'pc_folder';
  // الأرشفة الأسبوعية التلقائية للكمبيوتر
  static const String kLastAutoArchive = 'last_auto_archive';
  static const int autoArchiveEveryDays = 7;
}
