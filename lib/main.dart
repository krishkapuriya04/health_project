import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

part 'top_menu_module.dart';
part 'data_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HealthDatabase.instance.initialize();
  await hydrateAppDataFromDatabase();
  runApp(const MyApp());
}

void nextFocus(BuildContext context, FocusNode? next) {
  if (next != null) {
    FocusScope.of(context).requestFocus(next);
  } else {
    FocusScope.of(context).unfocus();
  }
}

KeyEventResult handleEnterToNext(
  BuildContext context,
  FocusNode? next,
  KeyEvent event,
) {
  if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
    nextFocus(context, next);
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

KeyEventResult handleEnterAction(KeyEvent event, VoidCallback action) {
  if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
    action();
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

String sortingType = 'AccountWise';

List<Map<String, dynamic>> accounts = [];
List<Map<String, dynamic>> products = [];
List<Map<String, dynamic>> doctors = [];
List<Map<String, dynamic>> generics = [];
List<Map<String, dynamic>> accountGroups = [];
List<Map<String, dynamic>> connectedBanks = [];
List<Map<String, dynamic>> openingBalances = [];
List<Map<String, dynamic>> companies = [];
List<Map<String, dynamic>> users = [];
List<Map<String, dynamic>> billings = [];
List<Map<String, dynamic>> patients = [];
List<Map<String, dynamic>> stockPoints = [];
List<Map<String, dynamic>> preFormates = [];
List<Map<String, dynamic>> happyHours = [];
List<Map<String, dynamic>> creditDebitNotes = [];
List<Map<String, dynamic>> deliveryMemos = [];
List<Map<String, dynamic>> stockTransferRecords = [];
List<Map<String, dynamic>> conversionRecords = [];
List<Map<String, dynamic>> otherIssueReceiptRecords = [];
List<Map<String, dynamic>> otherInputsRcmRecords = [];
List<Map<String, dynamic>> cashierRecords = [];
List<Map<String, dynamic>> shortageNotifierRecords = [];
List<Map<String, dynamic>> salesInvoiceRecords = [];
List<Map<String, dynamic>> purchaseBillRecords = [];
/// Order chits / counter orders (Special → Order Chit Register).
List<Map<String, dynamic>> orderChitRecords = [];
int _orderChitSeed = 1;
/// Schedule rows (Special → Schedule Register).
List<Map<String, dynamic>> scheduleRegisterRecords = [];
int _scheduleRegisterSeed = 1;
/// Proforma / draft invoices (Special → Proforma screens).
List<Map<String, dynamic>> proformaInvoiceRecords = [];
int _proformaInvoiceSeed = 1;
/// Discount rules: `scope` product|category|customer, `target`, `percent`.
List<Map<String, dynamic>> discountRules = [];
int _discountRuleSeed = 1;
/// Schemes: buyX, getY, combo label, active.
List<Map<String, dynamic>> schemeOffers = [];
int _schemeOfferSeed = 1;
/// Doctor commission config: doctorName, percent, notes.
List<Map<String, dynamic>> doctorCommissions = [];
int _doctorCommissionSeed = 1;
/// End-of-day snapshots (Periodical → Daily Closing).
List<Map<String, dynamic>> dailyClosingRecords = [];
int _dailyClosingSeed = 1;
/// In-memory session backup (Utility → Backup / Restore).
DateTime? lastAppBackupAt;
String? appDataBackupJson;
/// User-facing activity log (ActiveWork / audit).
List<Map<String, dynamic>> appActivityLog = [];
/// Pending operational tasks (ActiveWork).
List<Map<String, dynamic>> pendingWorkItems = [];
int _pendingWorkSeed = 1;
/// Store-wide settings (Utility → Store Settings).
final Map<String, dynamic> globalMedicalStoreSettings = {
  'storeName': 'Medical Store',
  'gstNumber': '',
  'currency': 'INR',
  'themeHint': 'system',
};
/// Printer / label queue messages (last job).
String? lastPrintJobSummary;
/// Infoserver last sync (UI state).
DateTime? lastInfoserverSyncAt;
String? lastInfoserverSyncMessage;
/// Sales bill no → `Pending` | `Generated` (e-invoicing UI).
final Map<String, String> einvoiceStatusByBillNo = {};
final Map<String, List<Map<String, dynamic>>> accountModuleRecords = {};
final Map<String, int> accountModuleSeed = {};

int _accountSeed = 1;
int _productSeed = 1;
int _doctorSeed = 1;
int _genericSeed = 1;
int _accountGroupSeed = 1;
int _connectedBankSeed = 1;
int _openingBalanceSeed = 1;
int _companySeed = 1;
int _userSeed = 1;
int _billingSeed = 1;
int _patientSeed = 1;
int _stockPointSeed = 1;
int _preFormateSeed = 1;
int _happyHourSeed = 1;
int _creditDebitNoteSeed = 1;
int _creditNoteNumberSeed = 1001;
int _debitNoteNumberSeed = 1001;
int _deliveryMemoSeed = 1001;
int _stockTransferSeed = 1001;
int _conversionSeed = 1001;
int _otherIssueReceiptSeed = 1001;
int _otherInputsRcmSeed = 1001;
int _cashierSeed = 1001;
int _shortageNotifierSeed = 1001;
int _salesInvoiceSeed = 2001;
int _purchaseBillSeed = 3001;

class HealthDatabase {
  HealthDatabase._();
  static final HealthDatabase instance = HealthDatabase._();

  static const String dbFileName = 'health_plus.db';
  Database? _db;
  bool _useMemoryStore = false;

  int _accountMemoryId = 0;
  int _productMemoryId = 0;
  int _doctorMemoryId = 0;
  final List<Map<String, Object?>> _accountMemoryTable = [];
  final List<Map<String, Object?>> _productMemoryTable = [];
  final List<Map<String, Object?>> _doctorMemoryTable = [];

  static Future<void> _createJsonStoreTables(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS json_documents (
  collection TEXT NOT NULL,
  doc_id INTEGER NOT NULL,
  payload TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (collection, doc_id)
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS app_kv (
  k TEXT PRIMARY KEY,
  v TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
  }

  bool get hasPersistentSql => !_useMemoryStore && _db != null;

  Future<void> upsertJsonDocument(
    String collection,
    int docId,
    Map<String, dynamic> doc,
  ) async {
    if (!hasPersistentSql) return;
    try {
      final db = _db!;
      await db.insert(
        'json_documents',
        {
          'collection': collection,
          'doc_id': docId,
          'payload': jsonEncode(doc),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<void> deleteJsonDocument(String collection, int docId) async {
    if (!hasPersistentSql) return;
    try {
      final db = _db!;
      await db.delete(
        'json_documents',
        where: 'collection = ? AND doc_id = ?',
        whereArgs: [collection, docId],
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> loadJsonCollection(
    String collection,
  ) async {
    if (!hasPersistentSql) return [];
    try {
      final db = _db!;
      final rows = await db.query(
        'json_documents',
        where: 'collection = ?',
        whereArgs: [collection],
      );
      final out = <Map<String, dynamic>>[];
      for (final row in rows) {
        final raw = row['payload'] as String?;
        if (raw == null || raw.isEmpty) continue;
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          out.add(Map<String, dynamic>.from(decoded));
        } else if (decoded is Map) {
          out.add(Map<String, dynamic>.from(decoded));
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> putAppKv(String key, String value) async {
    if (!hasPersistentSql) return;
    try {
      final db = _db!;
      await db.insert(
        'app_kv',
        {
          'k': key,
          'v': value,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<String?> getAppKv(String key) async {
    if (!hasPersistentSql) return null;
    try {
      final db = _db!;
      final rows = await db.query(
        'app_kv',
        where: 'k = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['v'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize() async {
    if (_db != null) {
      return;
    }

    if (kIsWeb) {
      _useMemoryStore = true;
      return;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      final String dbPath = p.join(await getDatabasesPath(), dbFileName);
      _db = await openDatabase(
        dbPath,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE account_master (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              mobile TEXT,
              city TEXT,
              gst TEXT,
              address TEXT,
              created_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE product_master (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              company TEXT,
              mrp REAL,
              sale_rate REAL,
              gst TEXT,
              stock REAL,
              created_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE doctor_master (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              mobile TEXT,
              city TEXT,
              speciality TEXT,
              created_at TEXT NOT NULL
            )
          ''');
          await _createJsonStoreTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createJsonStoreTables(db);
          }
        },
      );
    } catch (_) {
      _useMemoryStore = true;
    }
  }

  Future<Database> get database async {
    if (_db == null) {
      await initialize();
    }
    return _db!;
  }

  Future<int> insertAccount(Map<String, Object?> values) async {
    if (_useMemoryStore) {
      final row = Map<String, Object?>.from(values);
      row['id'] = ++_accountMemoryId;
      _accountMemoryTable.add(row);
      return row['id'] as int;
    }
    final db = await database;
    return db.insert('account_master', values);
  }

  Future<int> updateAccount(int id, Map<String, Object?> values) async {
    if (_useMemoryStore) {
      final int idx = _accountMemoryTable.indexWhere((row) => row['id'] == id);
      if (idx == -1) {
        return 0;
      }
      _accountMemoryTable[idx] = {..._accountMemoryTable[idx], ...values};
      return 1;
    }
    final db = await database;
    return db.update(
      'account_master',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAccount(int id) async {
    if (_useMemoryStore) {
      final int before = _accountMemoryTable.length;
      _accountMemoryTable.removeWhere((row) => row['id'] == id);
      return before - _accountMemoryTable.length;
    }
    final db = await database;
    return db.delete('account_master', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> fetchAccounts() async {
    if (_useMemoryStore) {
      return _accountMemoryTable.reversed
          .map((row) => Map<String, Object?>.from(row))
          .toList();
    }
    final db = await database;
    return db.query('account_master', orderBy: 'id DESC');
  }

  Future<int> insertProduct(Map<String, Object?> values) async {
    if (_useMemoryStore) {
      final row = Map<String, Object?>.from(values);
      row['id'] = ++_productMemoryId;
      _productMemoryTable.add(row);
      return row['id'] as int;
    }
    final db = await database;
    return db.insert('product_master', values);
  }

  Future<int> updateProduct(int id, Map<String, Object?> values) async {
    if (_useMemoryStore) {
      final int idx = _productMemoryTable.indexWhere((row) => row['id'] == id);
      if (idx == -1) {
        return 0;
      }
      _productMemoryTable[idx] = {..._productMemoryTable[idx], ...values};
      return 1;
    }
    final db = await database;
    return db.update(
      'product_master',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteProduct(int id) async {
    if (_useMemoryStore) {
      final int before = _productMemoryTable.length;
      _productMemoryTable.removeWhere((row) => row['id'] == id);
      return before - _productMemoryTable.length;
    }
    final db = await database;
    return db.delete('product_master', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> fetchProducts() async {
    if (_useMemoryStore) {
      return _productMemoryTable.reversed
          .map((row) => Map<String, Object?>.from(row))
          .toList();
    }
    final db = await database;
    return db.query('product_master', orderBy: 'id DESC');
  }

  Future<int> insertDoctor(Map<String, Object?> values) async {
    if (_useMemoryStore) {
      final row = Map<String, Object?>.from(values);
      row['id'] = ++_doctorMemoryId;
      _doctorMemoryTable.add(row);
      return row['id'] as int;
    }
    final db = await database;
    return db.insert('doctor_master', values);
  }

  Future<int> updateDoctor(int id, Map<String, Object?> values) async {
    if (_useMemoryStore) {
      final int idx = _doctorMemoryTable.indexWhere((row) => row['id'] == id);
      if (idx == -1) {
        return 0;
      }
      _doctorMemoryTable[idx] = {..._doctorMemoryTable[idx], ...values};
      return 1;
    }
    final db = await database;
    return db.update('doctor_master', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteDoctor(int id) async {
    if (_useMemoryStore) {
      final int before = _doctorMemoryTable.length;
      _doctorMemoryTable.removeWhere((row) => row['id'] == id);
      return before - _doctorMemoryTable.length;
    }
    final db = await database;
    return db.delete('doctor_master', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> fetchDoctors() async {
    if (_useMemoryStore) {
      return _doctorMemoryTable.reversed
          .map((row) => Map<String, Object?>.from(row))
          .toList();
    }
    final db = await database;
    return db.query('doctor_master', orderBy: 'id DESC');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health+',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFFF6F2C2)),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  final String? initialModule;
  const HomePage({super.key, this.initialModule});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Menu shortcut — `id` matches entries wired in [_handleOpenShortcut].
class _OpenMenuShortcutIntent extends Intent {
  const _OpenMenuShortcutIntent(this.id);
  final String id;
}

class _HomePageState extends State<HomePage> {
  bool isMenuHovered = false;
  bool isDropdownHovered = false;
  String? activeMenu;
  String? activeTaskbarMenu;
  bool _showAccountMaster = false;
  bool _showProductMaster = false;
  bool _showDoctorMaster = false;
  bool _showGenericMaster = false;
  bool _showAccountInformationEdit = false;
  bool _showAccountGroup = false;
  bool _showConnectedBank = false;
  bool _showOpeningBalance = false;
  bool _showCompanyMaster = false;
  bool _showUserMaster = false;
  bool _showBillingMaster = false;
  bool _showPatientMaster = false;
  bool _showStockPoint = false;
  bool _showPreFormates = false;
  bool _showHappyHours = false;
  bool _showCreditDebitNote = false;
  bool _showDeliveryMemo = false;
  bool _showStockTransfer = false;
  bool _showConversion = false;
  bool _showOtherIssueReceipt = false;
  bool _showOtherInputsRcm = false;
  bool _showCashier = false;
  bool _showShortageNotifier = false;
  bool _showSalesInvoice = false;
  bool _showPurchaseBill = false;
  bool _showInvoicePrint = false;
  bool _showCrDrNotePrint = false;
  String? _activeAccountModule;
  String? _placeholderMasterTitle;
  /// Top menu: Special / Periodical / Utility / Printers / ActiveWork / Infoserver.
  String? _appModuleGroup;
  String? _appModuleItem;
  Offset _taskbarMenuPosition = Offset.zero;
  double _taskbarButtonHeight = 0;
  late Timer closeTimer;
  final Map<String, double> _menuPositions = {};
  final GlobalKey masterKey = GlobalKey();
  final GlobalKey invoiceKey = GlobalKey();
  final GlobalKey accountKey = GlobalKey();
  final GlobalKey specialKey = GlobalKey();
  final GlobalKey periodicalKey = GlobalKey();
  final GlobalKey utilityKey = GlobalKey();
  final GlobalKey calculatorKey = GlobalKey();
  final GlobalKey exitKey = GlobalKey();
  int _totalAccounts = 0;
  int _totalProducts = 0;
  double _todaySales = 0;
  int _pendingBills = 0;
  double _totalPurchase = 0;
  int _lowStockCount = 0;
  double _todayRevenue = 0;

  static const Map<String, List<String>> _taskbarSubMenuItems = {
    'Master': ['Product Master', 'Company Master', 'Patient Master'],
    'Invoice': [
      'Sales Invoice',
      'Purchase Bill',
      'Delivery Memo',
      'Other Inputs (RCM)',
      'Stock Transfer',
      'Conversion',
      'Other Issue/Receipt',
      'Credit/Debit Note',
      'Cashier',
      'Shortage Notifier',
      'Invoice Print',
      'Cr/Dr Note Print',
    ],
    'Account': ['Account Master', 'Account Ledger', 'Payment Entry'],
    'Special': [
      'Discount Management',
      'Scheme / Offers',
      'Doctor Commission',
      'Daily Issue/Receipt',
    ],
    'Periodical': [
      'Expiry Management',
      'Physical Verification',
      'Backup & Restore',
      'Daily Closing',
    ],
    'Utility': [
      'Import / Export Data',
      'Backup',
      'Restore',
      'Store Settings',
    ],
  };

  @override
  void initState() {
    super.initState();
    closeTimer = Timer(Duration.zero, () {});
    _showAccountMaster = widget.initialModule == 'account';
    _showProductMaster = widget.initialModule == 'product';
    _showDoctorMaster = widget.initialModule == 'doctor';
    _showGenericMaster = widget.initialModule == 'generic';
    _showAccountInformationEdit = widget.initialModule == 'account-info-edit';
    _showAccountGroup = widget.initialModule == 'account-group';
    _showConnectedBank = widget.initialModule == 'connected-bank';
    _showOpeningBalance = widget.initialModule == 'opening-balance';
    _showCompanyMaster = widget.initialModule == 'company-master';
    _showUserMaster = widget.initialModule == 'user-master';
    _showBillingMaster = widget.initialModule == 'billing-master';
    _showPatientMaster = widget.initialModule == 'patient-master';
    _showStockPoint = widget.initialModule == 'stock-point';
    _showPreFormates = widget.initialModule == 'pre-formates';
    _showHappyHours = widget.initialModule == 'happy-hours';
    _showCreditDebitNote = widget.initialModule == 'credit-debit-note';
    _showDeliveryMemo = widget.initialModule == 'delivery-memo';
    _showStockTransfer = widget.initialModule == 'stock-transfer';
    _showConversion = widget.initialModule == 'conversion';
    _showOtherIssueReceipt = widget.initialModule == 'other-issue-receipt';
    _showOtherInputsRcm = widget.initialModule == 'other-inputs-rcm';
    _showCashier = widget.initialModule == 'cashier';
    _showShortageNotifier = widget.initialModule == 'shortage-notifier';
    _showSalesInvoice = widget.initialModule == 'sales-invoice';
    _showPurchaseBill = widget.initialModule == 'purchase-bill';
    _showInvoicePrint = widget.initialModule == 'invoice-print';
    _showCrDrNotePrint = widget.initialModule == 'crdr-note-print';
    _loadDashboardStats();
  }

  void _clearAllMasterAndInvoiceScreens() {
    _showAccountMaster = false;
    _showProductMaster = false;
    _showDoctorMaster = false;
    _showGenericMaster = false;
    _showAccountInformationEdit = false;
    _showAccountGroup = false;
    _showConnectedBank = false;
    _showOpeningBalance = false;
    _showCompanyMaster = false;
    _showUserMaster = false;
    _showBillingMaster = false;
    _showPatientMaster = false;
    _showStockPoint = false;
    _showPreFormates = false;
    _showHappyHours = false;
    _showCreditDebitNote = false;
    _showDeliveryMemo = false;
    _showStockTransfer = false;
    _showConversion = false;
    _showOtherIssueReceipt = false;
    _showOtherInputsRcm = false;
    _showCashier = false;
    _showShortageNotifier = false;
    _showSalesInvoice = false;
    _showPurchaseBill = false;
    _showInvoicePrint = false;
    _showCrDrNotePrint = false;
    _activeAccountModule = null;
    _placeholderMasterTitle = null;
  }

  void _openScreen(String screen, {String? placeholderTitle}) {
    setState(() {
      activeMenu = null;
      activeTaskbarMenu = null;
      _appModuleGroup = null;
      _appModuleItem = null;
      _clearAllMasterAndInvoiceScreens();
      _showAccountMaster = screen == 'account';
      _showProductMaster = screen == 'product';
      _showDoctorMaster = screen == 'doctor';
      _showGenericMaster = screen == 'generic';
      _showAccountInformationEdit = screen == 'account-info-edit';
      _showAccountGroup = screen == 'account-group';
      _showConnectedBank = screen == 'connected-bank';
      _showOpeningBalance = screen == 'opening-balance';
      _showCompanyMaster = screen == 'company-master';
      _showUserMaster = screen == 'user-master';
      _showBillingMaster = screen == 'billing-master';
      _showPatientMaster = screen == 'patient-master';
      _showStockPoint = screen == 'stock-point';
      _showPreFormates = screen == 'pre-formates';
      _showHappyHours = screen == 'happy-hours';
      _showCreditDebitNote = screen == 'credit-debit-note';
      _showDeliveryMemo = screen == 'delivery-memo';
      _showStockTransfer = screen == 'stock-transfer';
      _showConversion = screen == 'conversion';
      _showOtherIssueReceipt = screen == 'other-issue-receipt';
      _showOtherInputsRcm = screen == 'other-inputs-rcm';
      _showCashier = screen == 'cashier';
      _showShortageNotifier = screen == 'shortage-notifier';
      _showSalesInvoice = screen == 'sales-invoice';
      _showPurchaseBill = screen == 'purchase-bill';
      _showInvoicePrint = screen == 'invoice-print';
      _showCrDrNotePrint = screen == 'crdr-note-print';
      _activeAccountModule = screen.startsWith('account-module:')
          ? screen.replaceFirst('account-module:', '')
          : null;
      _placeholderMasterTitle = screen == 'placeholder'
          ? placeholderTitle
          : null;
    });
  }

  void _openTopMenuModule(String group, String item) {
    appendAppActivityLog('$group → $item');
    setState(() {
      activeMenu = null;
      activeTaskbarMenu = null;
      _clearAllMasterAndInvoiceScreens();
      _appModuleGroup = group;
      _appModuleItem = item;
    });
  }

  void _routeTopMenuSelection(String group, String rawLabel) {
    final label = normalizeTopMenuLabel(rawLabel);

    void openTop() => _openTopMenuModule(group, label);

    if (group == 'Special') {
      switch (label) {
        case 'Daily Issue/Receipt':
          _openScreen('other-issue-receipt');
          return;
        case 'Bank Receipt (IP)':
          _openScreen('account-module:Receipt');
          return;
        case 'Master List':
          _openScreen('account-group');
          return;
        case 'Admit Patient':
          _openScreen('patient-master');
          return;
      }
    }

    if (group == 'Utility') {
      switch (label) {
        case 'Product Information':
        case 'Product Info (Extra)':
          _openScreen('product');
          return;
        case 'Patient Information':
          _openScreen('patient-master');
          return;
        case 'Generic Information':
          _openScreen('generic');
          return;
        case 'Doctor Information':
          _openScreen('doctor');
          return;
        case 'Stockist Information':
          _openScreen('account');
          return;
        case 'Schedule Information':
          _openScreen('pre-formates');
          return;
        case 'Provisional Purchase':
          _openScreen('purchase-bill');
          return;
        case 'Address Book':
          _openScreen('account');
          return;
        case 'Task Scheduler':
          openTop();
          return;
        case 'Help (F1)':
          _openScreen(
            'placeholder',
            placeholderTitle: 'Help — use Invoice / Master menus for modules.',
          );
          return;
        case 'Log Out (User Change)':
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Switch user from User Master (Utility).'),
            ),
          );
          return;
        case 'Prompt InfoServer':
          _openTopMenuModule('Infoserver', 'Sync Data');
          return;
        case 'GST Updation':
        case 'Config / Administration':
          _openTopMenuModule('Utility', 'Store Settings');
          return;
      }
    }

    if (group == 'Printers') {
      switch (label) {
        case 'Invoice Print':
          _openScreen('invoice-print');
          return;
        case 'Cr/Dr Note Print':
        case 'Credit/Debit Note Print':
          _openScreen('crdr-note-print');
          return;
      }
    }

    openTop();
  }

  void _openAccountMenuItem(String label) {
    switch (label) {
      case 'Account Master':
        _openScreen('account');
        break;
      case 'Cash Receipt':
      case 'Bank Receipt':
      case 'Advance Receipt':
      case 'Receipt':
        _openScreen('account-module:Receipt');
        break;
      case 'Cash Payment':
      case 'Bank Payment':
      case 'Advance Payment':
      case 'Payment':
        _openScreen('account-module:Payment');
        break;
      case 'Daily Register':
      case 'Monthly Register':
      case 'Yearly Register':
      case 'Receipt/Payment Register':
        _openScreen('account-module:Receipt/Payment Register');
        break;
      case 'Bank Statement':
      case 'Reconcile Transactions':
      case 'Bank Balance':
      case 'Bank Reconciliation':
        _openScreen('account-module:Bank Reconciliation');
        break;
      case 'Profit & Loss':
      case 'Balance Sheet':
      case 'Trial Balance':
      case 'Final Reports':
        _openScreen('account-module:Final Reports');
        break;
      default:
        _openScreen('account-module:$label');
        break;
    }
  }

  void _openInvoiceMenuItem(String label) {
    switch (label) {
      case 'Sales Invoice':
        _openScreen('sales-invoice');
        break;
      case 'Purchase Bill':
        _openScreen('purchase-bill');
        break;
      case 'Delivery Memo':
        _openScreen('delivery-memo');
        break;
      case 'Other Inputs (RCM)':
      case 'Other Inputs/RCM':
        _openScreen('other-inputs-rcm');
        break;
      case 'Stock Transfer':
        _openScreen('stock-transfer');
        break;
      case 'Conversion':
        _openScreen('conversion');
        break;
      case 'Other Issue/Receipt':
        _openScreen('other-issue-receipt');
        break;
      case 'Credit/Debit Note':
        _openScreen('credit-debit-note');
        break;
      case 'Cashier':
        _openScreen('cashier');
        break;
      case 'Shortage Notifier':
        _openScreen('shortage-notifier');
        break;
      case 'Invoice Print':
        _openScreen('invoice-print');
        break;
      case 'Cr/Dr Note Print':
        _openScreen('crdr-note-print');
        break;
      default:
        _openScreen('placeholder', placeholderTitle: label);
        break;
    }
  }

  void _openMasterMenuItem(String label) {
    switch (label) {
      case 'Account Master':
        _openScreen('account');
        break;
      case 'Account Info Edit':
        _openScreen('account-info-edit');
        break;
      case 'Product Master':
        _openScreen('product');
        break;
      case 'Doctor Master':
        _openScreen('doctor');
        break;
      case 'Generic Master':
        _openScreen('generic');
        break;
      case 'Account Group':
        _openScreen('account-group');
        break;
      case 'Connected Bank':
        _openScreen('connected-bank');
        break;
      case 'Opening Balance':
        _openScreen('opening-balance');
        break;
      case 'Company Master':
        _openScreen('company-master');
        break;
      case 'User Master':
        _openScreen('user-master');
        break;
      case 'Billing Master':
        _openScreen('billing-master');
        break;
      case 'Patient Master':
        _openScreen('patient-master');
        break;
      case 'Stock Point':
        _openScreen('stock-point');
        break;
      case 'Pre-formates':
        _openScreen('pre-formates');
        break;
      case 'Happy Hours':
        _openScreen('happy-hours');
        break;
      default:
        _openScreen('placeholder', placeholderTitle: label);
        break;
    }
  }

  Future<void> _loadDashboardStats() async {
    if (!mounted) {
      return;
    }

    final todayKey = DateTime.now().toIso8601String().split('T').first;
    double totalSales = 0;
    double totalPurchase = 0;
    double todayRevenue = 0;

    for (final row in salesInvoiceRecords) {
      final value = (row['grandTotal'] as num?)?.toDouble() ?? 0;
      totalSales += value;
      final date = (row['date'] ?? '').toString();
      if (date == todayKey) {
        todayRevenue += value;
      }
    }

    for (final row in purchaseBillRecords) {
      totalPurchase += (row['grandTotal'] as num?)?.toDouble() ?? 0;
    }

    final lowStock = products.where((product) {
      final stock = double.tryParse((product['stock'] ?? '0').toString()) ?? 0;
      final reorder =
          double.tryParse(
            (product['reorderQty'] ?? product['minStock'] ?? '0').toString(),
          ) ??
          0;
      return reorder > 0 && stock <= reorder;
    }).length;

    setState(() {
      _totalAccounts = accounts.length;
      _totalProducts = products.length;
      _todaySales = totalSales;
      _pendingBills = salesInvoiceRecords.length;
      _totalPurchase = totalPurchase;
      _lowStockCount = lowStock;
      _todayRevenue = todayRevenue;
    });
  }

  @override
  void dispose() {
    closeTimer.cancel();
    super.dispose();
  }

  void _scheduleClose() {
    closeTimer.cancel();
    closeTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && !isMenuHovered && !isDropdownHovered) {
        setState(() {
          activeMenu = null;
        });
      }
    });
  }

  void _onMenuHoverEnter(String menuName) {
    setState(() {
      closeTimer.cancel();
      isMenuHovered = true;
      activeMenu = menuName;
    });
  }

  void _onMenuHoverExit() {
    setState(() {
      isMenuHovered = false;
      _scheduleClose();
    });
  }

  void _onDropdownHoverEnter() {
    setState(() {
      closeTimer.cancel();
      isDropdownHovered = true;
    });
  }

  void _onDropdownHoverExit() {
    setState(() {
      isDropdownHovered = false;
      _scheduleClose();
    });
  }

  void _onMenuPositionChanged(String menuName, double position) {
    setState(() {
      _menuPositions[menuName] = position;
    });
  }

  bool _isTypingInEditableField() {
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null) {
      return false;
    }
    final context = focused.context;
    if (context == null) {
      return false;
    }
    if (context.widget is EditableText) {
      return true;
    }
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _showShortcutSnackbar(String title) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Opened: $title'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _performShortcut(String title, VoidCallback action) {
    action();
    _showShortcutSnackbar(title);
  }

  void _handleOpenShortcut(String id) {
    if (_isTypingInEditableField()) {
      return;
    }
    switch (id) {
      case 'account_master':
        _performShortcut(
          'Account Master',
          () => _openMasterMenuItem('Account Master'),
        );
        break;
      case 'stockist_master':
        _performShortcut(
          'Stockist Master',
          () => _openMasterMenuItem('Stockist Master'),
        );
        break;
      case 'generic_master':
        _performShortcut(
          'Generic Master',
          () => _openMasterMenuItem('Generic Master'),
        );
        break;
      case 'sales_invoice':
        _performShortcut(
          'Sales Invoice',
          () => _openInvoiceMenuItem('Sales Invoice'),
        );
        break;
      case 'purchase_bill':
        _performShortcut(
          'Purchase Bill',
          () => _openInvoiceMenuItem('Purchase Bill'),
        );
        break;
      case 'delivery_memo':
        _performShortcut(
          'Delivery Memo',
          () => _openInvoiceMenuItem('Delivery Memo'),
        );
        break;
      case 'other_issue_receipt':
        _performShortcut(
          'Other Issue/Receipt',
          () => _openInvoiceMenuItem('Other Issue/Receipt'),
        );
        break;
      case 'credit_debit_note':
        _performShortcut(
          'Credit/Debit Note',
          () => _openInvoiceMenuItem('Credit/Debit Note'),
        );
        break;
      case 'currency_reconciliation':
        _performShortcut(
          'Currency Reconciliation',
          () => _openAccountMenuItem('Currency Reconciliation'),
        );
        break;
      case 'general_ledger':
        _performShortcut(
          'General Ledger',
          () => _openAccountMenuItem('General Ledger'),
        );
        break;
      case 'daily_issue_receipt':
        _performShortcut(
          'Daily Issue/Receipt',
          () => _routeTopMenuSelection('Special', 'Daily Issue/Receipt'),
        );
        break;
      case 'sales_margin':
        _performShortcut(
          'Sales Margin',
          () => _routeTopMenuSelection('Periodical', 'Sales Margin'),
        );
        break;
      case 'calculator':
        _performShortcut(
          'Calculator',
          () => showDialog<void>(
            context: context,
            barrierDismissible: true,
            builder: (dialogContext) => const MedicalCalculatorDialog(),
          ),
        );
        break;
      case 'address_book':
        _performShortcut(
          'Address Book',
          () => _routeTopMenuSelection('Utility', 'Address Book'),
        );
        break;
      case 'provisional_purchase':
        _performShortcut(
          'Provisional Purchase',
          () => _routeTopMenuSelection('Utility', 'Provisional Purchase'),
        );
        break;
      case 'task_scheduler':
        _performShortcut(
          'Task Scheduler',
          () => _routeTopMenuSelection('Utility', 'Task Scheduler'),
        );
        break;
      case 'product_information':
        _performShortcut(
          'Product Information',
          () => _routeTopMenuSelection('Utility', 'Product Information'),
        );
        break;
      case 'patient_information':
        _performShortcut(
          'Patient Information',
          () => _routeTopMenuSelection('Utility', 'Patient Information'),
        );
        break;
      case 'stockist_information':
        _performShortcut(
          'Stockist Information',
          () => _routeTopMenuSelection('Utility', 'Stockist Information'),
        );
        break;
      case 'generic_information':
        _performShortcut(
          'Generic Information',
          () => _routeTopMenuSelection('Utility', 'Generic Information'),
        );
        break;
      case 'doctor_information':
        _performShortcut(
          'Doctor Information',
          () => _routeTopMenuSelection('Utility', 'Doctor Information'),
        );
        break;
      case 'product_info_extra':
        _performShortcut(
          'Product Info (Extra)',
          () => _routeTopMenuSelection('Utility', 'Product Info (Extra)'),
        );
        break;
      case 'logout':
        _performShortcut(
          'Log Out (User Change)',
          () => _routeTopMenuSelection('Utility', 'Log Out (User Change)'),
        );
        break;
      case 'prompt_infoserver':
        _performShortcut(
          'Prompt InfoServer',
          () => _routeTopMenuSelection('Utility', 'Prompt InfoServer'),
        );
        break;
      case 'backup':
        _performShortcut(
          'Backup',
          () => _routeTopMenuSelection('Utility', 'Backup'),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            _OpenMenuShortcutIntent('account_master'),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _OpenMenuShortcutIntent('stockist_master'),
        const SingleActivator(LogicalKeyboardKey.keyG, control: true):
            _OpenMenuShortcutIntent('generic_master'),
        const SingleActivator(LogicalKeyboardKey.keyI, control: true):
            _OpenMenuShortcutIntent('sales_invoice'),
        const SingleActivator(LogicalKeyboardKey.keyP, control: true):
            _OpenMenuShortcutIntent('purchase_bill'),
        const SingleActivator(LogicalKeyboardKey.keyD, control: true):
            _OpenMenuShortcutIntent('delivery_memo'),
        const SingleActivator(LogicalKeyboardKey.keyC, control: true):
            _OpenMenuShortcutIntent('credit_debit_note'),
        const SingleActivator(
          LogicalKeyboardKey.f1,
          control: true,
          shift: true,
        ): _OpenMenuShortcutIntent('other_issue_receipt'),
        const SingleActivator(LogicalKeyboardKey.f4, control: true):
            _OpenMenuShortcutIntent('currency_reconciliation'),
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            _OpenMenuShortcutIntent('general_ledger'),
        const SingleActivator(LogicalKeyboardKey.f1, shift: true):
            _OpenMenuShortcutIntent('daily_issue_receipt'),
        const SingleActivator(LogicalKeyboardKey.keyM, control: true):
            _OpenMenuShortcutIntent('sales_margin'),
        const SingleActivator(LogicalKeyboardKey.f1, control: true):
            _OpenMenuShortcutIntent('calculator'),
        const SingleActivator(LogicalKeyboardKey.f12, shift: true):
            _OpenMenuShortcutIntent('address_book'),
        const SingleActivator(LogicalKeyboardKey.f2, shift: true):
            _OpenMenuShortcutIntent('provisional_purchase'),
        const SingleActivator(LogicalKeyboardKey.f3, shift: true):
            _OpenMenuShortcutIntent('task_scheduler'),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            _OpenMenuShortcutIntent('product_information'),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            _OpenMenuShortcutIntent('patient_information'),
        const SingleActivator(LogicalKeyboardKey.keyX, control: true):
            _OpenMenuShortcutIntent('stockist_information'),
        const SingleActivator(LogicalKeyboardKey.keyW, control: true):
            _OpenMenuShortcutIntent('generic_information'),
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            _OpenMenuShortcutIntent('doctor_information'),
        const SingleActivator(LogicalKeyboardKey.keyJ, control: true):
            _OpenMenuShortcutIntent('product_info_extra'),
        const SingleActivator(LogicalKeyboardKey.keyU, control: true):
            _OpenMenuShortcutIntent('logout'),
        const SingleActivator(LogicalKeyboardKey.keyQ, control: true):
            _OpenMenuShortcutIntent('prompt_infoserver'),
        const SingleActivator(LogicalKeyboardKey.keyB, control: true):
            _OpenMenuShortcutIntent('backup'),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenMenuShortcutIntent: CallbackAction<_OpenMenuShortcutIntent>(
            onInvoke: (intent) {
              _handleOpenShortcut(intent.id);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFE8F4F8),
                          const Color(0xFFECF8F5),
                          const Color(0xFFF5FAFC),
                          const Color(0xFFF8FAFF),
                        ],
                        stops: const [0.0, 0.35, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.045,
                      child: Center(
                        child: Icon(
                          Icons.local_pharmacy_rounded,
                          size: 340,
                          color: const Color(0xFF0D9488),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _MedicalWatermarkPainter(),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Column(
                  children: [
                    const TitleBar(),
                    MenuBar(
                      activeMenu: activeMenu,
                      onMenuHoverEnter: _onMenuHoverEnter,
                      onMenuHoverExit: _onMenuHoverExit,
                      onMenuPositionChanged: _onMenuPositionChanged,
                    ),
                    ShortcutBar(
                      activeMenu: activeTaskbarMenu,
                      menuKeys: {
                        'Master': masterKey,
                        'Invoice': invoiceKey,
                        'Account': accountKey,
                        'Special': specialKey,
                        'Periodical': periodicalKey,
                        'Utility': utilityKey,
                        'Calculator': calculatorKey,
                        'Exit': exitKey,
                      },
                      onMenuTap: (menu, key) {
                        if (menu == 'Calculator') {
                          setState(() {
                            activeTaskbarMenu = null;
                          });
                          showDialog<void>(
                            context: context,
                            builder: (dialogContext) {
                              return const MedicalCalculatorDialog();
                            },
                          );
                          return;
                        }

                        if (menu == 'Exit') {
                          setState(() {
                            activeTaskbarMenu = null;
                          });
                          showDialog<void>(
                            context: context,
                            builder: (dialogContext) {
                              return AlertDialog(
                                title: const Text('Exit Application'),
                                content: const Text('Do you want to exit?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                    child: const Text('No'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                    child: const Text('Yes'),
                                  ),
                                ],
                              );
                            },
                          );
                          return;
                        }

                        final RenderBox? box =
                            key.currentContext?.findRenderObject()
                                as RenderBox?;
                        if (box == null) {
                          return;
                        }
                        final Offset position = box.localToGlobal(Offset.zero);

                        setState(() {
                          if (activeTaskbarMenu == menu) {
                            activeTaskbarMenu = null;
                          } else {
                            activeTaskbarMenu = menu;
                            _taskbarMenuPosition = position;
                            _taskbarButtonHeight = box.size.height;
                          }
                        });
                      },
                    ),
                    Expanded(
                      child: _showGenericMaster
                          ? GenericMasterScreen(
                              onClose: () {
                                setState(() => _showGenericMaster = false);
                              },
                            )
                          : _showShortageNotifier
                          ? ShortageNotifierScreen(
                              onClose: () {
                                setState(() => _showShortageNotifier = false);
                              },
                            )
                          : _showCashier
                          ? CashierScreen(
                              onClose: () {
                                setState(() => _showCashier = false);
                              },
                            )
                          : _showOtherInputsRcm
                          ? OtherInputsRcmScreen(
                              onClose: () {
                                setState(() => _showOtherInputsRcm = false);
                              },
                            )
                          : _showOtherIssueReceipt
                          ? OtherIssueReceiptScreen(
                              onClose: () {
                                setState(() => _showOtherIssueReceipt = false);
                              },
                            )
                          : _showPurchaseBill
                          ? PurchaseBillScreen(
                              onClose: () {
                                setState(() => _showPurchaseBill = false);
                              },
                            )
                          : _showSalesInvoice
                          ? SalesInvoiceScreen(
                              onClose: () {
                                setState(() => _showSalesInvoice = false);
                              },
                            )
                          : _showConversion
                          ? ConversionScreen(
                              onClose: () {
                                setState(() => _showConversion = false);
                              },
                            )
                          : _showStockTransfer
                          ? StockTransferScreen(
                              onClose: () {
                                setState(() => _showStockTransfer = false);
                              },
                            )
                          : _showDeliveryMemo
                          ? DeliveryMemoScreen(
                              onClose: () {
                                setState(() => _showDeliveryMemo = false);
                              },
                            )
                          : _showCreditDebitNote
                          ? CreditDebitNoteScreen(
                              onClose: () {
                                setState(() => _showCreditDebitNote = false);
                              },
                            )
                          : _showCrDrNotePrint
                          ? CreditDebitNotePrintScreen(
                              onClose: () {
                                setState(() => _showCrDrNotePrint = false);
                              },
                            )
                          : _showInvoicePrint
                          ? InvoicePrintScreen(
                              onClose: () {
                                setState(() => _showInvoicePrint = false);
                              },
                            )
                          : _showHappyHours
                          ? HappyHoursScreen(
                              onClose: () {
                                setState(() => _showHappyHours = false);
                              },
                            )
                          : _showPreFormates
                          ? PreFormatesScreen(
                              onClose: () {
                                setState(() => _showPreFormates = false);
                              },
                            )
                          : _showStockPoint
                          ? StockPointScreen(
                              onClose: () {
                                setState(() => _showStockPoint = false);
                              },
                            )
                          : _showPatientMaster
                          ? PatientMasterScreen(
                              onClose: () {
                                setState(() => _showPatientMaster = false);
                              },
                            )
                          : _showBillingMaster
                          ? BillingMasterScreen(
                              onClose: () {
                                setState(() => _showBillingMaster = false);
                              },
                            )
                          : _showUserMaster
                          ? UserMasterScreen(
                              onClose: () {
                                setState(() => _showUserMaster = false);
                              },
                            )
                          : _showCompanyMaster
                          ? CompanyMasterScreen(
                              onClose: () {
                                setState(() => _showCompanyMaster = false);
                              },
                            )
                          : _showOpeningBalance
                          ? OpeningBalanceScreen(
                              onClose: () {
                                setState(() => _showOpeningBalance = false);
                              },
                            )
                          : _showConnectedBank
                          ? ConnectedBankScreen(
                              onClose: () {
                                setState(() => _showConnectedBank = false);
                              },
                            )
                          : _showAccountGroup
                          ? AccountGroupScreen(
                              onClose: () {
                                setState(() => _showAccountGroup = false);
                              },
                            )
                          : _placeholderMasterTitle != null
                          ? MasterPlaceholderScreen(
                              title: _placeholderMasterTitle!,
                              onClose: () {
                                setState(() => _placeholderMasterTitle = null);
                              },
                            )
                          : _showAccountInformationEdit
                          ? AccountInformationEditScreen(
                              onClose: () {
                                setState(
                                  () => _showAccountInformationEdit = false,
                                );
                              },
                            )
                          : _showDoctorMaster
                          ? DoctorMasterScreen(
                              onClose: () {
                                setState(() => _showDoctorMaster = false);
                                _loadDashboardStats();
                              },
                            )
                          : _showProductMaster
                          ? ProductMasterScreen(
                              onClose: () {
                                setState(() => _showProductMaster = false);
                                _loadDashboardStats();
                              },
                            )
                          : _showAccountMaster
                          ? AccountMasterScreen(
                              onClose: () {
                                setState(() => _showAccountMaster = false);
                                _loadDashboardStats();
                              },
                            )
                          : _activeAccountModule != null
                          ? AccountModuleScreen(
                              title: _activeAccountModule!,
                              onClose: () {
                                setState(() => _activeAccountModule = null);
                              },
                            )
                          : _appModuleGroup != null && _appModuleItem != null
                          ? TopMenuModuleScreen(
                              group: _appModuleGroup!,
                              item: _appModuleItem!,
                              onClose: () {
                                setState(() {
                                  _appModuleGroup = null;
                                  _appModuleItem = null;
                                });
                              },
                              onNavigate: _openScreen,
                              onRefresh: () {
                                setState(() {});
                                _loadDashboardStats();
                              },
                            )
                          : HomeCenterContent(
                              totalAccounts: _totalAccounts,
                              totalProducts: _totalProducts,
                              todaySales: _todaySales,
                              pendingBills: _pendingBills,
                              totalPurchase: _totalPurchase,
                              lowStock: _lowStockCount,
                              todayRevenue: _todayRevenue,
                              recentActivity: appActivityLog,
                              onAddAccount: () {
                                _openScreen('account');
                              },
                              onAddProduct: () {
                                _openScreen('product');
                              },
                              onAddDoctor: () {
                                _openScreen('doctor');
                              },
                              onCreateInvoice: () {
                                _openInvoiceMenuItem('Sales Invoice');
                              },
                              onNewCustomer: () {
                                _openScreen('account');
                              },
                            ),
                    ),
                    const StatusBar(),
                  ],
                ),
                // Dropdown overlay
                if (activeMenu != null &&
                    _menuPositions.containsKey(activeMenu))
                  Positioned(
                    top: 30 + 28, // TitleBar height + MenuBar height
                    left: _menuPositions[activeMenu]!,
                    child: _buildDropdownMenu(activeMenu!),
                  ),
                if (activeTaskbarMenu != null &&
                    _taskbarSubMenuItems.containsKey(activeTaskbarMenu))
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        setState(() {
                          activeTaskbarMenu = null;
                        });
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                if (activeTaskbarMenu != null &&
                    _taskbarSubMenuItems.containsKey(activeTaskbarMenu))
                  Positioned(
                    left: _taskbarMenuPosition.dx,
                    top: _taskbarMenuPosition.dy + _taskbarButtonHeight,
                    child: DropdownMenu(
                      items: _taskbarSubMenuItems[activeTaskbarMenu]!,
                      onItemTap: (item) {
                        if (activeTaskbarMenu == 'Master') {
                          _openMasterMenuItem(item);
                          setState(() => activeTaskbarMenu = null);
                          return;
                        }
                        if (activeTaskbarMenu == 'Account') {
                          _openAccountMenuItem(item);
                          setState(() => activeTaskbarMenu = null);
                          return;
                        }
                        if (item == 'Sales Invoice' ||
                            item == 'Purchase Bill' ||
                            item == 'Delivery Memo' ||
                            item == 'Other Inputs (RCM)' ||
                            item == 'Other Inputs/RCM' ||
                            item == 'Stock Transfer' ||
                            item == 'Conversion' ||
                            item == 'Other Issue/Receipt' ||
                            item == 'Credit/Debit Note' ||
                            item == 'Cashier' ||
                            item == 'Shortage Notifier' ||
                            item == 'Invoice Print' ||
                            item == 'Cr/Dr Note Print') {
                          _openInvoiceMenuItem(item);
                          setState(() => activeTaskbarMenu = null);
                          return;
                        }
                        if (activeTaskbarMenu == 'Special') {
                          _routeTopMenuSelection('Special', item);
                          setState(() => activeTaskbarMenu = null);
                          return;
                        }
                        if (activeTaskbarMenu == 'Periodical') {
                          _routeTopMenuSelection('Periodical', item);
                          setState(() => activeTaskbarMenu = null);
                          return;
                        }
                        if (activeTaskbarMenu == 'Utility') {
                          _routeTopMenuSelection('Utility', item);
                          setState(() => activeTaskbarMenu = null);
                          return;
                        }
                        setState(() {
                          activeTaskbarMenu = null;
                        });
                        debugPrint('$item clicked');
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownMenu(String menuName) {
    switch (menuName) {
      case 'Master':
        return MasterDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
          onMenuItemTap: _openMasterMenuItem,
        );
      case 'Invoice':
        return InvoiceDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
          onMenuItemTap: _openInvoiceMenuItem,
        );
      case 'Account':
        return AccountDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
          onMenuItemTap: _openAccountMenuItem,
        );
      case 'Special':
        return SpecialDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
          onMenuItemTap: (l) => _routeTopMenuSelection('Special', l),
        );
      case 'Periodical':
        return PeriodicalDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
          onMenuItemTap: (l) => _routeTopMenuSelection('Periodical', l),
        );
      case 'Utility':
        return UtilityDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
          onMenuItemTap: (l) => _routeTopMenuSelection('Utility', l),
        );
      case 'Printers':
        return PrintersDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
          onMenuItemTap: (l) => _routeTopMenuSelection('Printers', l),
        );
      case 'ActiveWork':
        return ActiveWorkDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
          onMenuItemTap: (l) => _routeTopMenuSelection('ActiveWork', l),
        );
      case 'Infoserver':
        return InfoserverDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
          onMenuItemTap: (l) => _routeTopMenuSelection('Infoserver', l),
        );
      case 'Exit':
        return ExitDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.local_pharmacy, size: 18, color: Color(0xFF4F46E5)),
          const SizedBox(width: 8),
          const Text(
            'Health+ MEDICAL STORE (2025-26) - Home',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class MenuBar extends StatefulWidget {
  final String? activeMenu;
  final Function(String) onMenuHoverEnter;
  final VoidCallback onMenuHoverExit;
  final Function(String, double) onMenuPositionChanged;

  const MenuBar({
    super.key,
    required this.activeMenu,
    required this.onMenuHoverEnter,
    required this.onMenuHoverExit,
    required this.onMenuPositionChanged,
  });

  @override
  State<MenuBar> createState() => _MenuBarState();
}

class _MenuBarState extends State<MenuBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFEEF2FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          bottom: BorderSide(color: Colors.indigo.shade100, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _menuItem('Master'),
          _menuItem('Invoice'),
          _menuItem('Account'),
          _menuItem('Special'),
          _menuItem('Periodical'),
          _menuItem('Utility'),
          _menuItem('Printers'),
          _menuItem('ActiveWork'),
          _menuItem('Infoserver'),
          _menuItem('Exit'),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _menuItem(String text) {
    bool isActive = widget.activeMenu == text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: MenuItemButton(
        text: text,
        isActive: isActive,
        onHoverEnter: () => widget.onMenuHoverEnter(text),
        onHoverExit: widget.onMenuHoverExit,
        onPositionChanged: (position) =>
            widget.onMenuPositionChanged(text, position),
      ),
    );
  }
}

class MasterMenuButton extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;

  const MasterMenuButton({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
  });

  @override
  State<MasterMenuButton> createState() => _MasterMenuButtonState();
}

class _MasterMenuButtonState extends State<MasterMenuButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() {
        isHovered = true;
        widget.onHoverEnter();
      }),
      onExit: (_) => setState(() {
        isHovered = false;
        widget.onHoverExit();
      }),
      child: Container(
        color: isHovered ? Colors.grey[280] : Colors.transparent,
        child: InkWell(
          onTap: () => widget.onHoverEnter(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Align(
              alignment: Alignment.center,
              child: Text(
                'Master',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isHovered ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MasterDropdownMenu extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final ValueChanged<String> onMenuItemTap;

  const MasterDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onMenuItemTap,
  });

  @override
  State<MasterDropdownMenu> createState() => _MasterDropdownMenuState();
}

class _MasterDropdownMenuState extends State<MasterDropdownMenu> {
  int? hoveredIndex;
  String? activeSubmenu;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MouseRegion(
          onEnter: (_) => widget.onHoverEnter(),
          onExit: (_) => widget.onHoverExit(),
          child: Container(
            width: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[350]!, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMenuItemRow(0, 'Account Master', 'Ctrl+A'),
                _buildMenuItemRow(1, 'Account Info Edit', ''),
                _buildMenuItemRow(2, 'Stockist Master', 'Ctrl+S'),
                _buildMenuItemRow(3, 'Account Group', ''),
                _buildMenuItemRow(4, 'Connected Bank', ''),
                _buildMenuItemRow(5, 'Opening Balance', ''),
                _divider(),
                _buildMenuItemRow(6, 'Company Master', ''),
                _buildMenuItemRow(7, 'Product Master', ''),
                _buildMenuItemRow(8, 'Product Info Edit', ''),
                _buildMenuItemRow(9, 'Tax Category (GST)', ''),
                _buildMenuItemRow(10, 'Opening Stock', ''),
                _divider(),
                _buildMenuItemRow(11, 'Doctor Master', ''),
                _buildMenuItemRow(12, 'Speciality Master', ''),
                _divider(),
                _buildMenuItemRow(13, 'Generic Master', 'Ctrl+G'),
                _buildMenuItemRow(14, 'Category Master', ''),
                _buildMenuItemRow(15, 'Scheduled Category', ''),
                _divider(),
                _buildMenuItemRow(16, 'Patient Master', ''),
                _buildMenuItemRow(17, 'User Master', ''),
                _divider(),
                _buildMenuItemRow(18, 'Billing Master', ''),
                _buildMenuItemRow(19, 'Stock Point', ''),
                _buildMenuItemRow(20, 'Pre-formates', ''),
                _buildMenuItemRow(21, 'Happy Hours', ''),
              ],
            ),
          ),
        ),
        // Submenu overlay
        if (activeSubmenu != null)
          Positioned(
            top: _getSubmenuTopPosition(activeSubmenu!),
            left: 240,
            child: _buildSubmenu(activeSubmenu!),
          ),
      ],
    );
  }

  double _getSubmenuTopPosition(String submenu) {
    // Calculate position based on menu item index
    switch (submenu) {
      default:
        return 0;
    }
  }

  Widget _buildSubmenu(String submenuName) {
    // Placeholder for submenu implementation
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[350]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSubmenuItem('Submenu Item 1'),
          _buildSubmenuItem('Submenu Item 2'),
        ],
      ),
    );
  }

  Widget _buildSubmenuItem(String label) {
    return MouseRegion(
      onEnter: (_) =>
          setState(() => hoveredIndex = -1), // Special index for submenu
      onExit: (_) => setState(() => hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          debugPrint('Clicked submenu: $label');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: hoveredIndex == -1 ? Colors.grey[100] : Colors.transparent,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItemRow(int index, String label, String shortcut) {
    bool isHovered = hoveredIndex == index;
    bool hasSubmenu = label.contains('>');

    if (hasSubmenu && isHovered) {
      activeSubmenu = label;
    } else if (!isHovered && activeSubmenu == label) {
      activeSubmenu = null;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => hoveredIndex = index),
      onExit: (_) => setState(() => hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          widget.onMenuItemTap(label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: isHovered ? const Color(0xFFF2F2F2) : Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  hasSubmenu ? label.replaceAll(' >', '') : label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isHovered ? Colors.black87 : Colors.black,
                  ),
                ),
              ),
              Row(
                children: [
                  if (shortcut.isNotEmpty)
                    Text(
                      shortcut,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  if (hasSubmenu)
                    const Icon(Icons.arrow_right, size: 14, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Container(height: 1, color: Colors.grey[250]),
    );
  }
}

class MasterPlaceholderScreen extends StatelessWidget {
  final String title;
  final VoidCallback? onClose;

  const MasterPlaceholderScreen({super.key, required this.title, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 32,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4338CA),
                  Color(0xFF6366F1),
                  Color(0xFF0EA5E9),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF312E81).withValues(alpha: 0.24),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30 / 2.2,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ),
                if (onClose != null)
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(3),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Icon(Icons.close, color: Colors.white70, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.desktop_windows_outlined,
                      size: 42,
                      color: Colors.blueGrey.shade400,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Screen is available from the Master menu and opens correctly.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InvoiceDropdownMenu extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final ValueChanged<String> onMenuItemTap;

  const InvoiceDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onMenuItemTap,
  });

  @override
  State<InvoiceDropdownMenu> createState() => _InvoiceDropdownMenuState();
}

class _InvoiceDropdownMenuState extends State<InvoiceDropdownMenu> {
  int? hoveredIndex;
  String? activeSubmenu;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MouseRegion(
          onEnter: (_) => widget.onHoverEnter(),
          onExit: (_) => widget.onHoverExit(),
          child: Container(
            width: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[350]!, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMenuItemRow(0, 'Sales Invoice', 'Ctrl+I'),
                _buildMenuItemRow(1, 'Invoice Print', ''),
                _divider(),
                _buildMenuItemRow(2, 'Purchase Bill', 'Ctrl+P'),
                _buildMenuItemRow(3, 'Delivery Memo', 'Ctrl+D'),
                _buildMenuItemRow(4, 'Other Inputs (RCM)', ''),
                _divider(),
                _buildMenuItemRow(5, 'Other Issue/Receipt', 'Shift+Ctrl+F1'),
                _buildMenuItemRow(6, 'Conversion', ''),
                _buildMenuItemRow(7, 'Stock Transfer', ''),
                _divider(),
                _buildMenuItemRow(8, 'Order Management >', ''),
                _divider(),
                _buildMenuItemRow(9, 'Credit/Debit Note', 'Ctrl+C'),
                _buildMenuItemRow(10, 'Cr/Dr Note Print', ''),
                _divider(),
                _buildMenuItemRow(11, 'Cashier', ''),
                _buildMenuItemRow(12, 'Shortage Notifier', ''),
              ],
            ),
          ),
        ),
        // Submenu overlay
        if (activeSubmenu != null)
          Positioned(
            top: _getSubmenuTopPosition(activeSubmenu!),
            left: 200,
            child: _buildSubmenu(activeSubmenu!),
          ),
      ],
    );
  }

  double _getSubmenuTopPosition(String submenu) {
    // Calculate position based on menu item index
    switch (submenu) {
      case 'Order Management >':
        return 150;
      default:
        return 0;
    }
  }

  Widget _buildSubmenu(String submenuName) {
    List<String> submenuItems = [];
    switch (submenuName) {
      case 'Order Management >':
        submenuItems = [
          'New Order',
          'Order List',
          'Pending Orders',
          'Order History',
        ];
        break;
      default:
        submenuItems = ['Item 1', 'Item 2'];
    }

    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[350]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: submenuItems.map((item) => _buildSubmenuItem(item)).toList(),
      ),
    );
  }

  Widget _buildSubmenuItem(String label) {
    return MouseRegion(
      onEnter: (_) =>
          setState(() => hoveredIndex = -1), // Special index for submenu
      onExit: (_) => setState(() => hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          debugPrint('Clicked submenu: $label');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: hoveredIndex == -1
              ? const Color(0xFFF2F2F2)
              : Colors.transparent,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItemRow(int index, String label, String shortcut) {
    bool isHovered = hoveredIndex == index;
    return MouseRegion(
      onEnter: (_) => setState(() => hoveredIndex = index),
      onExit: (_) => setState(() => hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          widget.onMenuItemTap(label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isHovered ? Colors.grey[100] : Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isHovered ? Colors.black87 : Colors.black,
                ),
              ),
              if (shortcut.isNotEmpty)
                Text(
                  shortcut,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Container(height: 1, color: Colors.grey[250]),
    );
  }
}

class AccountDropdownMenu extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final ValueChanged<String> onMenuItemTap;

  const AccountDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onMenuItemTap,
  });

  @override
  State<AccountDropdownMenu> createState() => _AccountDropdownMenuState();
}

class _AccountDropdownMenuState extends State<AccountDropdownMenu> {
  int? hoveredIndex;
  String? activeSubmenu;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MouseRegion(
          onEnter: (_) => widget.onHoverEnter(),
          onExit: (_) => widget.onHoverExit(),
          child: Container(
            width: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[350]!, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMenuItemRow(0, 'Account Master', ''),
                _divider(),
                _buildMenuItemRow(1, 'Receipt >', ''),
                _buildMenuItemRow(2, 'Payment >', ''),
                _divider(),
                _buildMenuItemRow(3, 'Journal Voucher', ''),
                _divider(),
                _buildMenuItemRow(3, 'Sales Register', ''),
                _buildMenuItemRow(4, 'Purchase Register', ''),
                _divider(),
                _buildMenuItemRow(5, 'GST Reports', ''),
                _buildMenuItemRow(6, 'Actual v/s Posting', ''),
                _buildMenuItemRow(7, 'VAT Reports', ''),
                _buildMenuItemRow(8, 'eInvoicing', ''),
                _divider(),
                _buildMenuItemRow(9, 'Receipt/Payment Register >', ''),
                _buildMenuItemRow(10, 'Cr/Dr Note Register', ''),
                _buildMenuItemRow(11, 'Journal Register', ''),
                _buildMenuItemRow(12, 'Stock Transfer Register', ''),
                _divider(),
                _buildMenuItemRow(13, 'Interest Calculation', ''),
                _divider(),
                _buildMenuItemRow(14, 'Currency Reconciliation', 'Ctrl+F4'),
                _buildMenuItemRow(15, 'General Ledger', 'Ctrl+L'),
                _buildMenuItemRow(16, 'Day Book', ''),
                _buildMenuItemRow(17, 'Account Balance', ''),
                _divider(),
                _buildMenuItemRow(18, 'Bank Reconciliation >', ''),
                _buildMenuItemRow(19, 'Final Reports >', ''),
              ],
            ),
          ),
        ),
        // Submenu overlay
        if (activeSubmenu != null)
          Positioned(
            top: _getSubmenuTopPosition(activeSubmenu!),
            left: 220,
            child: _buildSubmenu(activeSubmenu!),
          ),
      ],
    );
  }

  double _getSubmenuTopPosition(String submenu) {
    // Calculate position based on menu item index
    switch (submenu) {
      case 'Receipt >':
        return 0;
      case 'Payment >':
        return 25;
      case 'Receipt/Payment Register >':
        return 125;
      case 'Bank Reconciliation >':
        return 225;
      case 'Final Reports >':
        return 250;
      default:
        return 0;
    }
  }

  Widget _buildSubmenu(String submenuName) {
    List<String> submenuItems = [];
    switch (submenuName) {
      case 'Receipt >':
        submenuItems = ['Cash Receipt', 'Bank Receipt', 'Advance Receipt'];
        break;
      case 'Payment >':
        submenuItems = ['Cash Payment', 'Bank Payment', 'Advance Payment'];
        break;
      case 'Receipt/Payment Register >':
        submenuItems = [
          'Daily Register',
          'Monthly Register',
          'Yearly Register',
        ];
        break;
      case 'Bank Reconciliation >':
        submenuItems = [
          'Bank Statement',
          'Reconcile Transactions',
          'Bank Balance',
        ];
        break;
      case 'Final Reports >':
        submenuItems = ['Profit & Loss', 'Balance Sheet', 'Trial Balance'];
        break;
      default:
        submenuItems = ['Item 1', 'Item 2'];
    }

    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[350]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: submenuItems.map((item) => _buildSubmenuItem(item)).toList(),
      ),
    );
  }

  Widget _buildSubmenuItem(String label) {
    return MouseRegion(
      onEnter: (_) =>
          setState(() => hoveredIndex = -1), // Special index for submenu
      onExit: (_) => setState(() => hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          widget.onMenuItemTap(label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: hoveredIndex == -1
              ? const Color(0xFFF2F2F2)
              : Colors.transparent,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItemRow(int index, String label, String shortcut) {
    bool isHovered = hoveredIndex == index;
    bool hasSubmenu = label.contains('>');

    if (hasSubmenu && isHovered) {
      activeSubmenu = label;
    } else if (!isHovered && activeSubmenu == label) {
      activeSubmenu = null;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => hoveredIndex = index),
      onExit: (_) => setState(() => hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          widget.onMenuItemTap(label.replaceAll(' >', ''));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: isHovered ? const Color(0xFFF2F2F2) : Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  hasSubmenu ? label.replaceAll(' >', '') : label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isHovered ? Colors.black87 : Colors.black,
                  ),
                ),
              ),
              Row(
                children: [
                  if (shortcut.isNotEmpty)
                    Text(
                      shortcut,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  if (hasSubmenu)
                    const Icon(Icons.arrow_right, size: 14, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Container(height: 1, color: Colors.grey[250]),
    );
  }
}

class SpecialDropdownMenu extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final ValueChanged<String> onMenuItemTap;

  const SpecialDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onMenuItemTap,
  });

  @override
  State<SpecialDropdownMenu> createState() => _SpecialDropdownMenuState();
}

class _SpecialDropdownMenuState extends State<SpecialDropdownMenu> {
  int? hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.onHoverEnter(),
      onExit: (_) => widget.onHoverExit(),
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[350]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMenuItemRow(0, 'Master List >', ''),
            _buildMenuItemRow(1, 'Order Chit Register', ''),
            _buildMenuItemRow(2, 'Challan Register', ''),
            _divider(),
            _buildMenuItemRow(3, 'Daily Issue/Receipt', 'Shift+F1'),
            _buildMenuItemRow(4, 'Schedule Register', ''),
            _divider(),
            _buildMenuItemRow(5, 'Daily Sale/Purchase', ''),
            _buildMenuItemRow(6, 'Daily Sales Return', ''),
            _buildMenuItemRow(7, 'Sales Margin', 'Ctrl+M'),
            _divider(),
            _buildMenuItemRow(8, 'Invoice Import', ''),
            _buildMenuItemRow(9, 'Proforma/Special Invoice', ''),
            _buildMenuItemRow(10, 'Proforma Invoice Print', ''),
            _buildMenuItemRow(11, 'Proforma Invoice Report', ''),
            _divider(),
            _buildMenuItemRow(12, 'Address Print', ''),
            _buildMenuItemRow(13, 'Redeem Points', ''),
            _buildMenuItemRow(14, 'Admit Patient', ''),
            _divider(),
            _buildMenuItemRow(15, 'Bank Receipt (IP)', ''),
            _divider(),
            _buildMenuItemRow(16, 'Branch Transfer Out', ''),
            _buildMenuItemRow(17, 'Branch Transfer In', ''),
            _buildMenuItemRow(18, 'Branch Transfer In Print', ''),
            _divider(),
            _buildMenuItemRow(19, 'Discount Management', ''),
            _buildMenuItemRow(20, 'Scheme / Offers', ''),
            _buildMenuItemRow(21, 'Doctor Commission', ''),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemRow(int index, String label, String shortcut) {
    bool isHovered = hoveredIndex == index;
    return MouseRegion(
      onEnter: (_) => setState(() => hoveredIndex = index),
      onExit: (_) => setState(() => hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          widget.onMenuItemTap(label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isHovered ? Colors.grey[100] : Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isHovered ? Colors.black87 : Colors.black,
                ),
              ),
              if (shortcut.isNotEmpty)
                Text(
                  shortcut,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Container(height: 1, color: Colors.grey[250]),
    );
  }
}

class PeriodicalDropdownMenu extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final ValueChanged<String> onMenuItemTap;

  const PeriodicalDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onMenuItemTap,
  });

  @override
  State<PeriodicalDropdownMenu> createState() => _PeriodicalDropdownMenuState();
}

class _PeriodicalDropdownMenuState extends State<PeriodicalDropdownMenu> {
  int? hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.onHoverEnter(),
      onExit: (_) => widget.onHoverExit(),
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[350]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMenuItemRow(0, 'Sales/Stock Reports >', ''),
            _buildMenuItemRow(1, 'Physical Verification', ''),
            _divider(),
            _buildMenuItemRow(2, 'Account Receivable', ''),
            _buildMenuItemRow(3, 'Account Payable', ''),
            _divider(),
            _buildMenuItemRow(4, 'Scheme/Discount Report', ''),
            _buildMenuItemRow(5, 'Doctor Analysis', ''),
            _buildMenuItemRow(6, 'Party Analysis', ''),
            _buildMenuItemRow(7, 'Patient Analysis', ''),
            _buildMenuItemRow(8, 'Toppers\' Analysis', ''),
            _buildMenuItemRow(9, 'Member Points', ''),
            _divider(),
            _buildMenuItemRow(10, 'Misc Reports', ''),
            _buildMenuItemRow(11, 'HCC Reports', ''),
            _buildMenuItemRow(12, 'TB Report', ''),
            _divider(),
            _buildMenuItemRow(13, 'Administrative/Analytical Reports >', ''),
            _divider(),
            _buildMenuItemRow(14, 'Expiry Management', ''),
            _buildMenuItemRow(15, 'Backup & Restore', ''),
            _buildMenuItemRow(16, 'Daily Closing', ''),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemRow(int index, String label, String shortcut) {
    bool isHovered = hoveredIndex == index;
    return MouseRegion(
      onEnter: (_) => setState(() => hoveredIndex = index),
      onExit: (_) => setState(() => hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          widget.onMenuItemTap(label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: isHovered ? const Color(0xFFF2F2F2) : Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isHovered ? Colors.black87 : Colors.black,
                ),
              ),
              if (shortcut.isNotEmpty)
                Text(
                  shortcut,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Container(height: 1, color: Colors.grey[250]),
    );
  }
}

class UtilityDropdownMenu extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final ValueChanged<String> onMenuItemTap;

  const UtilityDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onMenuItemTap,
  });

  @override
  State<UtilityDropdownMenu> createState() => _UtilityDropdownMenuState();
}

class _UtilityDropdownMenuState extends State<UtilityDropdownMenu> {
  int? hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.onHoverEnter(),
      onExit: (_) => widget.onHoverExit(),
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[350]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMenuItemRow(0, 'Calculator', 'Ctrl+F1'),
            _buildMenuItemRow(1, 'Address Book', 'Shift+F12'),
            _buildMenuItemRow(2, 'Provisional Purchase', 'Shift+F2'),
            _buildMenuItemRow(3, 'Task Scheduler', 'Shift+F3'),
            _divider(),
            _buildMenuItemRow(4, 'Product Information', 'Ctrl+Z'),
            _buildMenuItemRow(5, 'Patient Information', 'Ctrl+Y'),
            _buildMenuItemRow(6, 'Stockist Information', 'Ctrl+X'),
            _buildMenuItemRow(7, 'Generic Information', 'Ctrl+W'),
            _divider(),
            _buildMenuItemRow(8, 'Schedule Information', ''),
            _buildMenuItemRow(9, 'Doctor Information', 'Ctrl+V'),
            _buildMenuItemRow(10, 'Product Info (Extra)', 'Ctrl+J'),
            _divider(),
            _buildMenuItemRow(11, 'Config / Administration >', ''),
            _divider(),
            _buildMenuItemRow(12, 'Help (F1)', ''),
            _buildMenuItemRow(13, 'HO Product Mapping', ''),
            _divider(),
            _buildMenuItemRow(14, 'Log Out (User Change)', 'Ctrl+U'),
            _divider(),
            _buildMenuItemRow(15, 'Reset Receivable/Payable', ''),
            _buildMenuItemRow(16, 'Regenerate Numbers', ''),
            _buildMenuItemRow(17, 'Stock Reconciliation', ''),
            _buildMenuItemRow(18, 'Merging >', ''),
            _divider(),
            _buildMenuItemRow(19, 'Prompt InfoServer', 'Ctrl+Q'),
            _buildMenuItemRow(20, 'Backup', 'Ctrl+B'),
            _buildMenuItemRow(21, 'Restore', ''),
            _divider(),
            _buildMenuItemRow(22, 'Recalculate Balances', ''),
            _buildMenuItemRow(23, 'Recalculate Stock', ''),
            _buildMenuItemRow(24, 'Remove Blues (Null)', ''),
            _divider(),
            _buildMenuItemRow(25, 'Year Change', ''),
            _buildMenuItemRow(26, 'GST Updation', ''),
            _buildMenuItemRow(27, 'Check for Update', ''),
            _divider(),
            _buildMenuItemRow(28, 'Import / Export Data', ''),
            _buildMenuItemRow(29, 'Store Settings', ''),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemRow(int index, String label, String shortcut) {
    bool isHovered = hoveredIndex == index;
    return MouseRegion(
      onEnter: (_) => setState(() => hoveredIndex = index),
      onExit: (_) => setState(() => hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          widget.onMenuItemTap(label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: isHovered ? const Color(0xFFF2F2F2) : Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isHovered ? Colors.black87 : Colors.black,
                ),
              ),
              if (shortcut.isNotEmpty)
                Text(
                  shortcut,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Container(height: 1, color: Colors.grey[250]),
    );
  }
}

class PrintersDropdownMenu extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final ValueChanged<String> onMenuItemTap;

  const PrintersDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onMenuItemTap,
  });

  @override
  State<PrintersDropdownMenu> createState() => _PrintersDropdownMenuState();
}

class _PrintersDropdownMenuState extends State<PrintersDropdownMenu> {
  int? hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.onHoverEnter(),
      onExit: (_) => widget.onHoverExit(),
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[350]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMenuItemRow(0, 'Print Setup', ''),
            _buildMenuItemRow(1, 'Default Printer', ''),
            _buildMenuItemRow(2, 'Label Printing', ''),
            _buildMenuItemRow(3, 'Barcode Printing', ''),
            _divider(),
            _buildMenuItemRow(4, 'Invoice Print', ''),
            _buildMenuItemRow(5, 'Report Print', ''),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Container(height: 1, color: Colors.grey[250]),
    );
  }

  Widget _buildMenuItemRow(int index, String label, String shortcut) {
    bool isHovered = hoveredIndex == index;
    return MouseRegion(
      onEnter: (_) => setState(() => hoveredIndex = index),
      onExit: (_) => setState(() => hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          widget.onMenuItemTap(label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: isHovered ? const Color(0xFFF2F2F2) : Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isHovered ? Colors.black87 : Colors.black,
                ),
              ),
              if (shortcut.isNotEmpty)
                Text(
                  shortcut,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActiveWorkDropdownMenu extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final ValueChanged<String> onMenuItemTap;

  const ActiveWorkDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onMenuItemTap,
  });

  @override
  State<ActiveWorkDropdownMenu> createState() => _ActiveWorkDropdownMenuState();
}

class _ActiveWorkDropdownMenuState extends State<ActiveWorkDropdownMenu> {
  int? hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.onHoverEnter(),
      onExit: (_) => widget.onHoverExit(),
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[350]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMenuItemRow(0, 'Active Work List', ''),
            _buildMenuItemRow(1, 'Pending Tasks', ''),
            _divider(),
            _buildMenuItemRow(2, 'Current Sales Activity', ''),
            _buildMenuItemRow(3, 'User Activity Log', ''),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Container(height: 1, color: Colors.grey[250]),
    );
  }

  Widget _buildMenuItemRow(int index, String label, String shortcut) {
    bool isHovered = hoveredIndex == index;
    return MouseRegion(
      onEnter: (_) => setState(() => hoveredIndex = index),
      onExit: (_) => setState(() => hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          widget.onMenuItemTap(label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: isHovered ? const Color(0xFFF2F2F2) : Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isHovered ? Colors.black87 : Colors.black,
                ),
              ),
              if (shortcut.isNotEmpty)
                Text(
                  shortcut,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoserverDropdownMenu extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final ValueChanged<String> onMenuItemTap;

  const InfoserverDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onMenuItemTap,
  });

  @override
  State<InfoserverDropdownMenu> createState() => _InfoserverDropdownMenuState();
}

class _InfoserverDropdownMenuState extends State<InfoserverDropdownMenu> {
  int? hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.onHoverEnter(),
      onExit: (_) => widget.onHoverExit(),
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[350]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMenuItemRow(0, 'Sync Data', ''),
            _buildMenuItemRow(1, 'Upload/Download', ''),
            _buildMenuItemRow(2, 'Server Settings', ''),
            _divider(),
            _buildMenuItemRow(3, 'Analytics Dashboard', ''),
            _buildMenuItemRow(4, 'Notifications & Alerts', ''),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Container(height: 1, color: Colors.grey[250]),
    );
  }

  Widget _buildMenuItemRow(int index, String label, String shortcut) {
    bool isHovered = hoveredIndex == index;
    return MouseRegion(
      onEnter: (_) => setState(() => hoveredIndex = index),
      onExit: (_) => setState(() => hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          widget.onMenuItemTap(label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: isHovered ? const Color(0xFFF2F2F2) : Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isHovered ? Colors.black87 : Colors.black,
                ),
              ),
              if (shortcut.isNotEmpty)
                Text(
                  shortcut,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExitDropdownMenu extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;

  const ExitDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
  });

  @override
  State<ExitDropdownMenu> createState() => _ExitDropdownMenuState();
}

class _ExitDropdownMenuState extends State<ExitDropdownMenu> {
  int? hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.onHoverEnter(),
      onExit: (_) => widget.onHoverExit(),
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[350]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_buildMenuItemRow(0, 'Exit Application', '')],
        ),
      ),
    );
  }

  Widget _buildMenuItemRow(int index, String label, String shortcut) {
    bool isHovered = hoveredIndex == index;
    return MouseRegion(
      onEnter: (_) => setState(() => hoveredIndex = index),
      onExit: (_) => setState(() => hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          debugPrint('Clicked: $label');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isHovered ? Colors.grey[100] : Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isHovered ? Colors.black87 : Colors.black,
                ),
              ),
              if (shortcut.isNotEmpty)
                Text(
                  shortcut,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MenuItemButton extends StatefulWidget {
  final String text;
  final bool isActive;
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final Function(double) onPositionChanged;

  const MenuItemButton({
    super.key,
    required this.text,
    required this.isActive,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onPositionChanged,
  });

  @override
  State<MenuItemButton> createState() => _MenuItemButtonState();
}

class _MenuItemButtonState extends State<MenuItemButton> {
  bool isHovered = false;
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePosition();
    });
  }

  void _updatePosition() {
    final RenderBox? renderBox =
        _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      widget.onPositionChanged(position.dx);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() {
        isHovered = true;
        widget.onHoverEnter();
      }),
      onExit: (_) => setState(() {
        isHovered = false;
        widget.onHoverExit();
      }),
      child: Container(
        key: _key,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: widget.isActive
              ? const Color(0xFFE0E7FF)
              : isHovered
              ? const Color(0xFFEFF4FF)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isActive
                ? const Color(0xFFA5B4FC)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.center,
              child: Text(
                widget.text,
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isActive
                      ? const Color(0xFF312E81)
                      : const Color(0xFF334155),
                  fontWeight: widget.isActive || isHovered
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShortcutBar extends StatelessWidget {
  final String? activeMenu;
  final Map<String, GlobalKey> menuKeys;
  final void Function(String, GlobalKey) onMenuTap;

  const ShortcutBar({
    super.key,
    required this.activeMenu,
    required this.menuKeys,
    required this.onMenuTap,
  });

  static const List<String> _menus = [
    'Master',
    'Invoice',
    'Account',
    'Special',
    'Periodical',
    'Utility',
    'Calculator',
    'Exit',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF8FAFC),
            const Color(0xFFEFF6FF).withValues(alpha: 0.85),
            const Color(0xFFECFEFF).withValues(alpha: 0.9),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFCBD5E1).withValues(alpha: 0.65),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: _menus.map((menu) {
          final bool isActive = menu == activeMenu;
          final GlobalKey buttonKey = menuKeys[menu]!;
          return Row(
            children: [
              SubMenuButton(
                key: buttonKey,
                label: menu,
                icon: _shortcutBarIcon(menu),
                isActive: isActive,
                onTap: () => onMenuTap(menu, buttonKey),
              ),
              const SizedBox(width: 8),
            ],
          );
        }).toList(),
      ),
    );
  }
}

IconData _shortcutBarIcon(String menu) {
  switch (menu) {
    case 'Master':
      return Icons.grid_view_rounded;
    case 'Invoice':
      return Icons.receipt_long_rounded;
    case 'Account':
      return Icons.account_balance_wallet_rounded;
    case 'Special':
      return Icons.auto_awesome_rounded;
    case 'Periodical':
      return Icons.calendar_month_rounded;
    case 'Utility':
      return Icons.tune_rounded;
    case 'Calculator':
      return Icons.calculate_rounded;
    case 'Exit':
      return Icons.logout_rounded;
    default:
      return Icons.circle_outlined;
  }
}

class SubMenuButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const SubMenuButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<SubMenuButton> createState() => _SubMenuButtonState();
}

class _SubMenuButtonState extends State<SubMenuButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isActive
        ? const Color(0xFFCCFBF1).withValues(alpha: 0.95)
        : isHovered
            ? Colors.white
            : const Color(0xFFF8FAFC);
    final border = widget.isActive
        ? _DashUi.teal.withValues(alpha: 0.55)
        : isHovered
            ? _DashUi.teal.withValues(alpha: 0.28)
            : const Color(0xFFE2E8F0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: widget.isActive ? 1.2 : 1),
            boxShadow: [
              if (widget.isActive || isHovered)
                BoxShadow(
                  color: _DashUi.teal.withValues(
                    alpha: widget.isActive ? 0.22 : 0.12,
                  ),
                  blurRadius: isHovered ? 14 : 10,
                  offset: const Offset(0, 4),
                ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 17,
                color: widget.isActive ? _DashUi.tealDeep : _DashUi.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w600,
                  color: widget.isActive ? _DashUi.tealDeep : _DashUi.text,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DropdownMenu extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onItemTap;

  const DropdownMenu({super.key, required this.items, required this.onItemTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: InkWell(
              onTap: () => onItemTap(item),
              hoverColor: Colors.grey.shade200,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(item, style: const TextStyle(fontSize: 13)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class MasterScreen extends StatelessWidget {
  const MasterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Master')),
      body: const Center(child: Text('Master Page')),
    );
  }
}

class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      body: const Center(child: Text('Invoice Page')),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: const Center(child: Text('Account Page')),
    );
  }
}

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 25,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB22222), Color(0xFF4169E1)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Sales Invoice',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class FormSection extends StatelessWidget {
  const FormSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _formField('Billing Type', isDropdown: true),
                _formField('Account'),
                _formField('Doctor'),
                _formField('Patient'),
                _formField('GST Type', isDropdown: true),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _formField('Bill No'),
                _formField('Date'),
                _formField('Ref No'),
                _formField('Address'),
                _formField('Mobile'),
                _formField('Discount'),
                Row(
                  children: [
                    Checkbox(value: false, onChanged: (value) {}),
                    const Text('TB Patient', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formField(String label, {bool isDropdown = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: Row(
        children: [
          SizedBox(
            width: 65,
            child: Text('$label:', style: const TextStyle(fontSize: 10)),
          ),
          Expanded(
            child: isDropdown
                ? DropdownButton<String>(
                    items: const [],
                    onChanged: (value) {},
                    isExpanded: true,
                    style: const TextStyle(fontSize: 10),
                  )
                : TextField(
                    style: const TextStyle(fontSize: 10),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 0.5,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ProductTable extends StatelessWidget {
  const ProductTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Column(
        children: [
          _headerRow(),
          Expanded(
            child: ListView.builder(
              itemCount: 10,
              itemBuilder: (context, index) => _dataRow(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow() {
    return Row(
      children: [
        _headerCell('Sr'),
        _headerCell('Product Name'),
        _headerCell('Pack'),
        _headerCell('MRP'),
        _headerCell('Batch'),
        _headerCell('Expiry'),
        _headerCell('Qty'),
        _headerCell('Rate'),
        _headerCell('Amount'),
      ],
    );
  }

  Widget _headerCell(String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(1),
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Colors.black, width: 1)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _dataRow(int index) {
    return Row(
      children: [
        _dataCell((index + 1).toString()),
        _dataCell(''),
        _dataCell(''),
        _dataCell(''),
        _dataCell(''),
        _dataCell(''),
        _dataCell(''),
        _dataCell(''),
        _dataCell(''),
      ],
    );
  }

  Widget _dataCell(String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(0.5),
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.black, width: 1),
            bottom: BorderSide(color: Colors.black, width: 1),
          ),
        ),
        child: TextField(
          controller: TextEditingController(text: text),
          style: const TextStyle(fontSize: 10),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 0.5, vertical: 0),
          ),
        ),
      ),
    );
  }
}

class BottomPanel extends StatelessWidget {
  const BottomPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          Column(
            children: [
              Row(
                children: [
                  _button('Print'),
                  const SizedBox(width: 1),
                  _button('Quick'),
                  const SizedBox(width: 1),
                  _button('Payment'),
                ],
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  _button('Del Bill'),
                  const SizedBox(width: 1),
                  _button('Del Item'),
                  const SizedBox(width: 1),
                  _button('Clear'),
                ],
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _label('SGST (+)'),
              _label('CGST (+)'),
              _label('IGST (+)'),
              _label('Rounding Off'),
              _label('Grand Total'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _button(String text) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0.5),
        minimumSize: const Size(30, 10),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      child: Text(text, style: const TextStyle(fontSize: 7)),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.1),
      child: Text(text, style: const TextStyle(fontSize: 9)),
    );
  }
}

/// Shared palette for dashboard + shortcut strip (teal / blue / soft green; orange accent rare).
abstract final class _DashUi {
  static const Color teal = Color(0xFF0D9488);
  static const Color tealDeep = Color(0xFF0F766E);
  static const Color blue = Color(0xFF0284C7);
  static const Color blueLight = Color(0xFF38BDF8);
  static const Color text = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textSoft = Color(0xFF94A3B8);
  static const Color accentAmber = Color(0xFFFB923C);

  static TextStyle sectionTitle() => const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: text,
        letterSpacing: 1.0,
      );
}

/// Very light medical cross grid — stronger toward the right to balance empty space.
class _MedicalWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D9488).withValues(alpha: 0.055)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const step = 44.0;
    final startX = size.width * 0.48;
    for (var x = startX; x < size.width + step; x += step) {
      for (var y = -step; y < size.height + step; y += step) {
        const arm = 5.0;
        canvas.drawLine(Offset(x - arm, y), Offset(x + arm, y), paint);
        canvas.drawLine(Offset(x, y - arm), Offset(x, y + arm), paint);
      }
    }
    final soft = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF38BDF8).withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.88, size.height * 0.22),
        radius: size.shortestSide * 0.55,
      ));
    canvas.drawRect(Offset.zero & size, soft);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HomeCenterContent extends StatelessWidget {
  final int totalAccounts;
  final int totalProducts;
  final double todaySales;
  final int pendingBills;
  final double totalPurchase;
  final int lowStock;
  final double todayRevenue;
  final List<Map<String, dynamic>> recentActivity;
  final VoidCallback onAddAccount;
  final VoidCallback onAddProduct;
  final VoidCallback onAddDoctor;
  final VoidCallback onCreateInvoice;
  final VoidCallback onNewCustomer;

  const HomeCenterContent({
    super.key,
    required this.totalAccounts,
    required this.totalProducts,
    required this.todaySales,
    required this.pendingBills,
    required this.totalPurchase,
    required this.lowStock,
    required this.todayRevenue,
    required this.recentActivity,
    required this.onAddAccount,
    required this.onAddProduct,
    required this.onAddDoctor,
    required this.onCreateInvoice,
    required this.onNewCustomer,
  });

  String _todayLine() {
    final d = DateTime.now();
    const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${w[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final recent = recentActivity.take(10).toList();
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 640),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        );
      },
      child: LayoutBuilder(
        builder: (context, c) {
          final raw = c.maxWidth.isFinite ? c.maxWidth : 1280.0;
          final maxW = raw.clamp(320.0, 1320.0);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HomeWelcomeHeader(dateLine: _todayLine()),
                    const SizedBox(height: 22),
                    Text('OVERVIEW', style: _DashUi.sectionTitle()),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: 268,
                          child: _HomeMetricCard(
                            icon: Icons.trending_up_rounded,
                            title: "Today's sales",
                            subtitle: 'Invoices dated today',
                            value: '₹ ${todayRevenue.toStringAsFixed(0)}',
                            iconBg: _DashUi.teal,
                            valueBadge: todayRevenue > 0
                                ? Icon(
                                    Icons.trending_up_rounded,
                                    size: 20,
                                    color: _DashUi.teal.withValues(alpha: 0.85),
                                  )
                                : null,
                          ),
                        ),
                        SizedBox(
                          width: 268,
                          child: _HomeMetricCard(
                            icon: Icons.shopping_cart_rounded,
                            title: 'Total purchase',
                            subtitle: 'Recorded purchase bills',
                            value: '₹ ${totalPurchase.toStringAsFixed(0)}',
                            iconBg: _DashUi.blue,
                          ),
                        ),
                        SizedBox(
                          width: 268,
                          child: _HomeMetricCard(
                            icon: Icons.pending_actions_rounded,
                            title: 'Pending payments',
                            subtitle: 'Open invoices in register',
                            value: '$pendingBills',
                            iconBg: _DashUi.accentAmber,
                            accentWarm: true,
                          ),
                        ),
                        SizedBox(
                          width: 268,
                          child: _HomeMetricCard(
                            icon: Icons.inventory_rounded,
                            title: 'Stock alerts',
                            subtitle: 'At or below reorder level',
                            value: lowStock == 0 ? 'All clear' : '$lowStock SKUs',
                            iconBg: _DashUi.tealDeep,
                            valueBadge: lowStock > 0
                                ? Icon(
                                    Icons.priority_high_rounded,
                                    size: 18,
                                    color: _DashUi.accentAmber.withValues(alpha: 0.9),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Lifetime sales recorded: ₹ ${todaySales.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: _DashUi.textSoft,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text('QUICK ACTIONS', style: _DashUi.sectionTitle()),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _HomeQuickTile(
                          icon: Icons.receipt_long_rounded,
                          title: 'Create invoice',
                          subtitle: 'Sales billing',
                          colors: const [_DashUi.teal, Color(0xFF14B8A6)],
                          onTap: onCreateInvoice,
                        ),
                        _HomeQuickTile(
                          icon: Icons.add_box_rounded,
                          title: 'Add product',
                          subtitle: 'Inventory master',
                          colors: const [_DashUi.blue, _DashUi.blueLight],
                          onTap: onAddProduct,
                        ),
                        _HomeQuickTile(
                          icon: Icons.person_add_alt_1_rounded,
                          title: 'New customer',
                          subtitle: 'Account / party',
                          colors: const [Color(0xFF0891B2), Color(0xFF22D3EE)],
                          onTap: onNewCustomer,
                        ),
                        _HomeQuickTile(
                          icon: Icons.medical_services_rounded,
                          title: 'Add doctor',
                          subtitle: 'Referral master',
                          colors: const [_DashUi.tealDeep, Color(0xFF047857)],
                          onTap: onAddDoctor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text('MASTER SNAPSHOT', style: _DashUi.sectionTitle()),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatPill(
                          icon: Icons.groups_rounded,
                          label: 'Accounts',
                          value: '$totalAccounts',
                        ),
                        _StatPill(
                          icon: Icons.inventory_2_rounded,
                          label: 'Products',
                          value: '$totalProducts',
                        ),
                        _StatPill(
                          icon: Icons.receipt_long_rounded,
                          label: 'Invoices',
                          value: '$pendingBills',
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text('RECENT ACTIVITY', style: _DashUi.sectionTitle()),
                    const SizedBox(height: 10),
                    _HomeActivityPanel(entries: recent),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HomeWelcomeHeader extends StatelessWidget {
  const _HomeWelcomeHeader({required this.dateLine});

  final String dateLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _DashUi.teal.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.78),
                width: 1.2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.88),
                  const Color(0xFFF0FDFA).withValues(alpha: 0.82),
                  const Color(0xFFE0F2FE).withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [_DashUi.teal, _DashUi.blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _DashUi.teal.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_pharmacy_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome to Health+ Medical Store System',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: _DashUi.text,
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Billing · inventory · accounts · $dateLine',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _DashUi.textMuted,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeMetricCard extends StatefulWidget {
  const _HomeMetricCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.iconBg,
    this.valueBadge,
    this.accentWarm = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final Color iconBg;
  final Widget? valueBadge;
  final bool accentWarm;

  @override
  State<_HomeMetricCard> createState() => _HomeMetricCardState();
}

class _HomeMetricCardState extends State<_HomeMetricCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final warmTint = widget.accentWarm
        ? _DashUi.accentAmber.withValues(alpha: 0.06)
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.018 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                const Color(0xFFF8FAFC),
                Color.lerp(
                  const Color(0xFFF0FDFA),
                  const Color(0xFFE0F2FE),
                  0.5,
                )!,
              ],
            ),
            border: Border.all(
              color: _hover
                  ? _DashUi.teal.withValues(alpha: 0.45)
                  : const Color(0xFFE2E8F0),
              width: _hover ? 1.25 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _DashUi.teal.withValues(alpha: _hover ? 0.14 : 0.06),
                blurRadius: _hover ? 28 : 18,
                offset: Offset(0, _hover ? 12 : 8),
                spreadRadius: _hover ? 0 : -1,
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: _hover ? 0.09 : 0.05),
                blurRadius: _hover ? 22 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (widget.accentWarm)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          warmTint,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.iconBg.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: widget.iconBg.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(widget.icon, size: 26, color: widget.iconBg),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _DashUi.text,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _DashUi.textSoft,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                widget.value,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _DashUi.text,
                                  letterSpacing: -0.4,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            if (widget.valueBadge != null) ...[
                              const SizedBox(width: 6),
                              widget.valueBadge!,
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeQuickTile extends StatefulWidget {
  const _HomeQuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  State<_HomeQuickTile> createState() => _HomeQuickTileState();
}

class _HomeQuickTileState extends State<_HomeQuickTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Transform.scale(
        scale: _hover ? 1.03 : 1,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 204,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: widget.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.colors.first.withValues(alpha: _hover ? 0.5 : 0.36),
                  blurRadius: _hover ? 26 : 18,
                  offset: Offset(0, _hover ? 14 : 9),
                  spreadRadius: _hover ? -1 : -2,
                ),
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedScale(
                  scale: _hover ? 1.08 : 1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    widget.icon,
                    color: Colors.white.withValues(alpha: 0.96),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeActivityPanel extends StatelessWidget {
  const _HomeActivityPanel({required this.entries});

  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
              color: _DashUi.teal.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.history_rounded, color: _DashUi.textSoft),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No recent actions yet. Use the menu to record sales, purchases, or masters — activity will appear here.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: _DashUi.textMuted,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _DashUi.teal.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i++)
              Material(
                color: i.isEven
                    ? Colors.white.withValues(alpha: 0.55)
                    : const Color(0xFFF8FAFC),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.bolt_rounded,
                    size: 18,
                    color: _DashUi.teal,
                  ),
                  title: Text(
                    '${entries[i]['action'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _DashUi.text,
                    ),
                  ),
                  subtitle: Text(
                    '${entries[i]['user'] ?? ''} · ${_fmtActivityTime(entries[i]['at'])}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _DashUi.textSoft,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _fmtActivityTime(dynamic at) {
  final s = at?.toString() ?? '';
  if (s.isEmpty) return '';
  final d = DateTime.tryParse(s);
  if (d == null) return s;
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFCBD5E1).withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: _DashUi.teal.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: _DashUi.teal),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: _DashUi.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _DashUi.text,
            ),
          ),
        ],
      ),
    );
  }
}

class GenericMasterScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const GenericMasterScreen({super.key, this.onClose});

  @override
  State<GenericMasterScreen> createState() => _GenericMasterScreenState();
}

class _GenericMasterScreenState extends State<GenericMasterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController shortNameController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();
  final TextEditingController productController = TextEditingController();

  final FocusNode focusName = FocusNode();
  final FocusNode focusShortName = FocusNode();
  final FocusNode focusRemarks = FocusNode();
  final FocusNode focusSchedule = FocusNode();
  final FocusNode focusProduct = FocusNode();
  final FocusNode focusSave = FocusNode();

  final List<String> _products = [
    'HEPASAFE SYP. 200 ML',
    'LEU SYRUP. 200 ML',
    'AMOXICAP 500',
    'PARACET 650 TAB',
  ];

  final Set<int> _selectedProductIndexes = <int>{};
  int? _selectedRecordIndex;
  String _schedule = '(none)';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        focusName.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    shortNameController.dispose();
    remarksController.dispose();
    productController.dispose();
    focusName.dispose();
    focusShortName.dispose();
    focusRemarks.dispose();
    focusSchedule.dispose();
    focusProduct.dispose();
    focusSave.dispose();
    super.dispose();
  }

  void _saveRecord() {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name required'),
          duration: Duration(milliseconds: 900),
        ),
      );
      return;
    }

    final List<String> selectedProducts = _selectedProductIndexes
        .map((i) => _products[i])
        .toList();

    setState(() {
      generics.add({
        'id': _genericSeed++,
        'name': nameController.text.trim(),
        'shortName': shortNameController.text.trim(),
        'remarks': remarksController.text.trim(),
        'schedule': _schedule,
        'product': productController.text.trim(),
        'products': selectedProducts,
      });
      _selectedRecordIndex = generics.length - 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved Successfully'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  void _clearForm() {
    setState(() {
      nameController.clear();
      shortNameController.clear();
      remarksController.clear();
      productController.clear();
      _selectedProductIndexes.clear();
      _schedule = '(none)';
      _selectedRecordIndex = null;
    });
    focusName.requestFocus();
  }

  void _deleteLast() {
    if (generics.isEmpty) {
      return;
    }

    setState(() {
      generics.removeLast();
      _selectedRecordIndex = generics.isEmpty ? null : generics.length - 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deleted'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  void _editSample() {
    setState(() {
      nameController.text = 'AN AYURVEDIC PROP';
      shortNameController.text = 'AN AYURVEDIC';
      remarksController.text = 'Sample generic remarks';
      _schedule = '(none)';
      productController.text = 'HEPASAFE SYP. 200 ML';
      _selectedProductIndexes
        ..clear()
        ..add(0)
        ..add(1);
    });
  }

  void _loadRecord(int index) {
    final row = generics[index];
    setState(() {
      _selectedRecordIndex = index;
      nameController.text = row['name']?.toString() ?? '';
      shortNameController.text = row['shortName']?.toString() ?? '';
      remarksController.text = row['remarks']?.toString() ?? '';
      _schedule = row['schedule']?.toString() ?? '(none)';
      productController.text = row['product']?.toString() ?? '';
      _selectedProductIndexes.clear();
      final List<dynamic> selected = (row['products'] as List<dynamic>? ?? []);
      for (int i = 0; i < _products.length; i++) {
        if (selected.contains(_products[i])) {
          _selectedProductIndexes.add(i);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F1F1),
      child: Column(
        children: [
          GenericMasterHeaderBar(onBack: widget.onClose),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 380,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldRow(
                                label: 'Name',
                                field: _erpInput(
                                  controller: nameController,
                                  focusNode: focusName,
                                  nextNode: focusShortName,
                                ),
                              ),
                              _fieldRow(
                                label: 'Short Name',
                                field: _erpInput(
                                  controller: shortNameController,
                                  focusNode: focusShortName,
                                  nextNode: focusRemarks,
                                ),
                              ),
                              _fieldRow(
                                label: 'Remarks',
                                topAligned: true,
                                field: _erpInput(
                                  controller: remarksController,
                                  focusNode: focusRemarks,
                                  nextNode: focusSchedule,
                                  maxLines: 3,
                                  fillColor: const Color(0xFFF9EDC8),
                                ),
                              ),
                              _fieldRow(
                                label: 'Schedule?',
                                field: _scheduleDropdown(),
                              ),
                              _fieldRow(
                                label: 'Product',
                                field: _erpInput(
                                  controller: productController,
                                  focusNode: focusProduct,
                                  onEnterAction: _saveRecord,
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.grey.shade500,
                                    width: 0.8,
                                  ),
                                ),
                                child: ListView.builder(
                                  itemCount: _products.length,
                                  itemBuilder: (context, index) {
                                    final selected = _selectedProductIndexes
                                        .contains(index);
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (selected) {
                                            _selectedProductIndexes.remove(
                                              index,
                                            );
                                          } else {
                                            _selectedProductIndexes.add(index);
                                          }
                                        });
                                      },
                                      child: Container(
                                        height: 24,
                                        color: selected
                                            ? const Color(0xFF1E73BE)
                                            : Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _products[index],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: selected
                                                ? Colors.white
                                                : Colors.black87,
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GenericMasterRecordTable(
                        records: generics,
                        selectedIndex: _selectedRecordIndex,
                        onRowTap: _loadRecord,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F2F2),
                      border: Border(
                        left: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    alignment: Alignment.topCenter,
                    child: Opacity(
                      opacity: 0.06,
                      child: Icon(
                        Icons.medication_rounded,
                        size: 520,
                        color: Colors.blueGrey.shade500,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: GenericMasterActionPanel(
                    onEdit: _editSample,
                    onDelete: _deleteLast,
                    onSave: _saveRecord,
                    onClear: _clearForm,
                    saveFocusNode: focusSave,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldRow({
    required String label,
    required Widget field,
    bool topAligned = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: topAligned
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: Padding(
              padding: EdgeInsets.only(top: topAligned ? 5 : 0),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(child: field),
        ],
      ),
    );
  }

  Widget _scheduleDropdown() {
    return Focus(
      focusNode: focusSchedule,
      onKeyEvent: (_, event) => handleEnterToNext(context, focusProduct, event),
      child: SizedBox(
        height: 28,
        child: DropdownButtonFormField<String>(
          value: _schedule,
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          style: const TextStyle(fontSize: 12.5, color: Colors.black87),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: '(none)',
              child: Text('(none)', style: TextStyle(fontSize: 12.5)),
            ),
            DropdownMenuItem(
              value: 'H',
              child: Text('H', style: TextStyle(fontSize: 12.5)),
            ),
            DropdownMenuItem(
              value: 'H1',
              child: Text('H1', style: TextStyle(fontSize: 12.5)),
            ),
            DropdownMenuItem(
              value: 'X',
              child: Text('X', style: TextStyle(fontSize: 12.5)),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _schedule = value);
            }
          },
        ),
      ),
    );
  }

  Widget _erpInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextNode,
    VoidCallback? onEnterAction,
    int maxLines = 1,
    Color fillColor = Colors.white,
  }) {
    final bool multiline = maxLines > 1;
    return SizedBox(
      height: multiline ? 70 : 28,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) {
          if (onEnterAction != null) {
            onEnterAction();
          } else {
            FocusScope.of(context).requestFocus(nextNode);
          }
        },
        style: const TextStyle(fontSize: 12.5),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          filled: true,
          fillColor: fillColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: BorderSide(color: Colors.blueGrey.shade400, width: 1),
          ),
        ),
      ),
    );
  }
}

class GenericMasterHeaderBar extends StatelessWidget {
  final VoidCallback? onBack;
  const GenericMasterHeaderBar({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB0302D), Color(0xFF8B2FA1), Color(0xFF4A4FB5)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Generic Master',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30 / 2.2,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
          if (onBack != null)
            InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(3),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Icon(Icons.close, color: Colors.white70, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reusable action button used across all Master screens.
class MasterActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  const MasterActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onPressed,
    this.focusNode,
  });

  @override
  State<MasterActionButton> createState() => _MasterActionButtonState();
}

class _MasterActionButtonState extends State<MasterActionButton> {
  bool _hovered = false;

  Color get _resolvedAccent {
    switch (widget.label.toLowerCase()) {
      case 'save':
        return const Color(0xFF15803D);
      case 'delete':
        return const Color(0xFFDC2626);
      case 'edit':
        return const Color(0xFF2563EB);
      case 'clear':
        return const Color(0xFF64748B);
      default:
        return widget.accentColor;
    }
  }

  Color get _hoverBackground {
    return _resolvedAccent.withValues(alpha: 0.12);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        height: 40,
        width: 130,
        child: Focus(
          focusNode: widget.focusNode,
          onKeyEvent: (_, event) => handleEnterAction(event, widget.onPressed),
          child: OutlinedButton.icon(
            onPressed: widget.onPressed,
            icon: Icon(widget.icon, size: 16, color: _resolvedAccent),
            label: Text(
              widget.label,
              style: TextStyle(
                color: _resolvedAccent,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              backgroundColor: _hovered
                  ? _hoverBackground
                  : _resolvedAccent.withValues(alpha: 0.06),
              side: BorderSide(
                color: _hovered
                    ? _resolvedAccent.withValues(alpha: 0.5)
                    : _resolvedAccent.withValues(alpha: 0.24),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              splashFactory: InkRipple.splashFactory,
            ),
          ),
        ),
      ),
    );
  }
}

class GenericMasterActionPanel extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final FocusNode? saveFocusNode;

  const GenericMasterActionPanel({
    super.key,
    required this.onEdit,
    required this.onDelete,
    required this.onSave,
    required this.onClear,
    this.saveFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F1F1),
      padding: const EdgeInsets.fromLTRB(8, 10, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          MasterActionButton(
            label: 'Edit',
            icon: Icons.edit,
            accentColor: Colors.grey.shade700,
            onPressed: onEdit,
          ),
          const SizedBox(height: 10),
          MasterActionButton(
            label: 'Delete',
            icon: Icons.delete_outline,
            accentColor: Colors.red.shade600,
            onPressed: onDelete,
          ),
          const SizedBox(height: 10),
          MasterActionButton(
            label: 'Save',
            icon: Icons.save,
            accentColor: Colors.green.shade700,
            onPressed: onSave,
            focusNode: saveFocusNode,
          ),
          const SizedBox(height: 10),
          MasterActionButton(
            label: 'Clear',
            icon: Icons.cleaning_services,
            accentColor: Colors.blueGrey.shade600,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class GenericMasterRecordTable extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final int? selectedIndex;
  final ValueChanged<int> onRowTap;

  const GenericMasterRecordTable({
    super.key,
    required this.records,
    required this.selectedIndex,
    required this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        children: [
          Container(
            height: 28,
            color: const Color(0xFFE8E8E8),
            child: const Row(
              children: [
                _TableHeaderCell(text: 'Name', flex: 3),
                _TableHeaderCell(text: 'Short Name', flex: 3),
                _TableHeaderCell(text: 'Schedule', flex: 2),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: records.length,
              itemBuilder: (context, index) {
                final row = records[index];
                final bool selected = selectedIndex == index;
                return InkWell(
                  onTap: () => onRowTap(index),
                  child: Container(
                    height: 26,
                    color: selected ? const Color(0xFFDDE8FF) : Colors.white,
                    child: Row(
                      children: [
                        _TableValueCell(
                          text: (row['name'] ?? '').toString(),
                          flex: 3,
                        ),
                        _TableValueCell(
                          text: (row['shortName'] ?? '').toString(),
                          flex: 3,
                        ),
                        _TableValueCell(
                          text: (row['schedule'] ?? '').toString(),
                          flex: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AccountInformationEditScreen extends StatefulWidget {
  final VoidCallback? onClose;

  const AccountInformationEditScreen({super.key, this.onClose});

  @override
  State<AccountInformationEditScreen> createState() =>
      _AccountInformationEditScreenState();
}

class _AccountInformationEditScreenState
    extends State<AccountInformationEditScreen> {
  static const List<String> _sortingTypes = [
    'AccountWise',
    'NameWise',
    'CityWise',
  ];

  String selectedSortingType = 'AccountWise';
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    selectedSortingType = sortingType;
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _handleEdit() {
    setState(() {
      isEditing = !isEditing;
    });
  }

  void _handleSave() {
    setState(() {
      sortingType = selectedSortingType;
      isEditing = false;
    });
    debugPrint('Selected sorting type: $selectedSortingType');
    _showMessage('Saved Successfully');
  }

  void _handleClear() {
    setState(() {
      selectedSortingType = 'AccountWise';
      sortingType = 'AccountWise';
      isEditing = false;
    });
    _showMessage('Cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F1F1),
      child: Column(
        children: [
          Container(
            height: 32,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFB0302D),
                  Color(0xFF8B2FA1),
                  Color(0xFF4A4FB5),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Account Information Edit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30 / 2.2,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ),
                if (widget.onClose != null)
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(3),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Icon(Icons.close, color: Colors.white70, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 400,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 86,
                              child: Text(
                                'Sorting Type',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 28,
                                child: DropdownButtonFormField<String>(
                                  value: selectedSortingType,
                                  disabledHint: Text(
                                    selectedSortingType,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    size: 18,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(2),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade500,
                                        width: 0.8,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(2),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade500,
                                        width: 0.8,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(2),
                                      borderSide: BorderSide(
                                        color: Colors.blueGrey.shade400,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  items: _sortingTypes
                                      .map(
                                        (type) => DropdownMenuItem<String>(
                                          value: type,
                                          child: Text(
                                            type,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: isEditing
                                      ? (value) {
                                          if (value != null) {
                                            setState(() {
                                              selectedSortingType = value;
                                            });
                                          }
                                        }
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F2F2),
                      border: Border(
                        left: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: 0.07,
                      child: Icon(
                        Icons.local_pharmacy_rounded,
                        size: 260,
                        color: Colors.blueGrey.shade400,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: Container(
                    color: const Color(0xFFF1F1F1),
                    padding: const EdgeInsets.fromLTRB(8, 10, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        MasterActionButton(
                          label: 'Edit',
                          icon: Icons.edit,
                          accentColor: Colors.grey.shade700,
                          onPressed: _handleEdit,
                        ),
                        const SizedBox(height: 10),
                        MasterActionButton(
                          label: 'Save',
                          icon: Icons.save,
                          accentColor: Colors.green.shade700,
                          onPressed: _handleSave,
                        ),
                        const SizedBox(height: 10),
                        MasterActionButton(
                          label: 'Clear',
                          icon: Icons.cleaning_services,
                          accentColor: Colors.blueGrey.shade600,
                          onPressed: _handleClear,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccountGroupScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const AccountGroupScreen({super.key, this.onClose});

  @override
  State<AccountGroupScreen> createState() => _AccountGroupScreenState();
}

class _AccountGroupScreenState extends State<AccountGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _nature = 'Assets';
  int? _selectedIndex;
  int? _editingId;

  @override
  void dispose() {
    _groupNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _clearForm() {
    setState(() {
      _groupNameController.clear();
      _descriptionController.clear();
      _nature = 'Assets';
      _selectedIndex = null;
      _editingId = null;
    });
    _showMessage('Cleared');
  }

  void _editSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to edit');
      return;
    }

    final row = accountGroups[_selectedIndex!];
    setState(() {
      _editingId = row['id'] as int;
      _groupNameController.text = (row['groupName'] ?? '').toString();
      _nature = (row['nature'] ?? 'Assets').toString();
      _descriptionController.text = (row['description'] ?? '').toString();
    });
  }

  void _deleteSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to delete');
      return;
    }

    final id = accountGroups[_selectedIndex!]['id'];
    setState(() {
      accountGroups.removeWhere((row) => row['id'] == id);
      _selectedIndex = null;
      _editingId = null;
      _groupNameController.clear();
      _descriptionController.clear();
      _nature = 'Assets';
    });
    _showMessage('Deleted');
  }

  void _save() {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      _showMessage('Group Name is required');
      return;
    }

    final duplicate = accountGroups.any((row) {
      final sameName =
          (row['groupName'] ?? '').toString().toLowerCase() ==
          groupName.toLowerCase();
      final sameRecord = _editingId != null && row['id'] == _editingId;
      return sameName && !sameRecord;
    });
    if (duplicate) {
      _showMessage('Duplicate group name not allowed');
      return;
    }

    setState(() {
      if (_editingId != null) {
        final index = accountGroups.indexWhere(
          (row) => row['id'] == _editingId,
        );
        if (index != -1) {
          accountGroups[index] = {
            ...accountGroups[index],
            'groupName': groupName,
            'nature': _nature,
            'description': _descriptionController.text.trim(),
          };
        }
      } else {
        accountGroups.add({
          'id': _accountGroupSeed++,
          'groupName': groupName,
          'nature': _nature,
          'description': _descriptionController.text.trim(),
        });
      }
      _selectedIndex = null;
      _editingId = null;
      _groupNameController.clear();
      _descriptionController.clear();
      _nature = 'Assets';
    });
    _showMessage('Saved Successfully');
  }

  @override
  Widget build(BuildContext context) {
    return _MasterCrudLayout(
      title: 'Account Group',
      onClose: widget.onClose,
      formWidth: 430,
      formChild: Column(
        children: [
          _CompactFormRow(
            label: 'Group Name',
            field: _compactInput(controller: _groupNameController),
          ),
          _CompactFormRow(
            label: 'Nature',
            field: _compactDropdown(
              value: _nature,
              values: const ['Assets', 'Liability', 'Income', 'Expense'],
              onChanged: (v) => setState(() => _nature = v),
            ),
          ),
          _CompactFormRow(
            label: 'Description',
            topAligned: true,
            field: _compactInput(
              controller: _descriptionController,
              maxLines: 2,
            ),
          ),
        ],
      ),
      tableChild: _SimpleTable(
        headers: const ['Group Name', 'Nature', 'Description'],
        selectedIndex: _selectedIndex,
        rows: accountGroups
            .map(
              (row) => [
                (row['groupName'] ?? '').toString(),
                (row['nature'] ?? '').toString(),
                (row['description'] ?? '').toString(),
              ],
            )
            .toList(),
        onRowTap: (index) => setState(() => _selectedIndex = index),
      ),
      onEdit: _editSelected,
      onDelete: _deleteSelected,
      onSave: _save,
      onClear: _clearForm,
    );
  }
}

class ConnectedBankScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const ConnectedBankScreen({super.key, this.onClose});

  @override
  State<ConnectedBankScreen> createState() => _ConnectedBankScreenState();
}

class _ConnectedBankScreenState extends State<ConnectedBankScreen> {
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNoController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _openingBalanceController =
      TextEditingController();

  int? _selectedIndex;
  int? _editingId;

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNoController.dispose();
    _ifscController.dispose();
    _branchController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _clearForm() {
    setState(() {
      _bankNameController.clear();
      _accountNoController.clear();
      _ifscController.clear();
      _branchController.clear();
      _openingBalanceController.clear();
      _selectedIndex = null;
      _editingId = null;
    });
    _showMessage('Cleared');
  }

  void _editSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to edit');
      return;
    }
    final row = connectedBanks[_selectedIndex!];
    setState(() {
      _editingId = row['id'] as int;
      _bankNameController.text = (row['bankName'] ?? '').toString();
      _accountNoController.text = (row['accountNo'] ?? '').toString();
      _ifscController.text = (row['ifsc'] ?? '').toString();
      _branchController.text = (row['branch'] ?? '').toString();
      _openingBalanceController.text = (row['balance'] ?? '').toString();
    });
  }

  void _deleteSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to delete');
      return;
    }

    final id = connectedBanks[_selectedIndex!]['id'];
    setState(() {
      connectedBanks.removeWhere((row) => row['id'] == id);
      _selectedIndex = null;
      _editingId = null;
      _bankNameController.clear();
      _accountNoController.clear();
      _ifscController.clear();
      _branchController.clear();
      _openingBalanceController.clear();
    });
    _showMessage('Deleted');
  }

  void _save() {
    final bankName = _bankNameController.text.trim();
    final accountNo = _accountNoController.text.trim();
    final ifsc = _ifscController.text.trim();
    final branch = _branchController.text.trim();
    final balanceText = _openingBalanceController.text.trim();

    if (bankName.isEmpty || accountNo.isEmpty || ifsc.isEmpty) {
      _showMessage('Bank Name, Account Number and IFSC are required');
      return;
    }

    final balance = double.tryParse(balanceText);
    if (balance == null) {
      _showMessage('Opening Balance must be numeric');
      return;
    }

    final duplicate = connectedBanks.any((row) {
      final sameNo = (row['accountNo'] ?? '').toString() == accountNo;
      final sameRecord = _editingId != null && row['id'] == _editingId;
      return sameNo && !sameRecord;
    });
    if (duplicate) {
      _showMessage('Account number must be unique');
      return;
    }

    setState(() {
      if (_editingId != null) {
        final index = connectedBanks.indexWhere(
          (row) => row['id'] == _editingId,
        );
        if (index != -1) {
          connectedBanks[index] = {
            ...connectedBanks[index],
            'bankName': bankName,
            'accountNo': accountNo,
            'ifsc': ifsc,
            'branch': branch,
            'balance': balance.toStringAsFixed(2),
          };
        }
      } else {
        connectedBanks.add({
          'id': _connectedBankSeed++,
          'bankName': bankName,
          'accountNo': accountNo,
          'ifsc': ifsc,
          'branch': branch,
          'balance': balance.toStringAsFixed(2),
        });
      }

      _selectedIndex = null;
      _editingId = null;
      _bankNameController.clear();
      _accountNoController.clear();
      _ifscController.clear();
      _branchController.clear();
      _openingBalanceController.clear();
    });
    _showMessage('Saved Successfully');
  }

  @override
  Widget build(BuildContext context) {
    return _MasterCrudLayout(
      title: 'Connected Bank',
      onClose: widget.onClose,
      formWidth: 430,
      formChild: Column(
        children: [
          _CompactFormRow(
            label: 'Bank Name',
            field: _compactInput(controller: _bankNameController),
          ),
          _CompactFormRow(
            label: 'Account No',
            field: _compactInput(controller: _accountNoController),
          ),
          _CompactFormRow(
            label: 'IFSC Code',
            field: _compactInput(controller: _ifscController),
          ),
          _CompactFormRow(
            label: 'Branch Name',
            field: _compactInput(controller: _branchController),
          ),
          _CompactFormRow(
            label: 'Opening Balance',
            field: _compactInput(controller: _openingBalanceController),
          ),
        ],
      ),
      tableChild: _SimpleTable(
        headers: const ['Bank Name', 'Account No', 'IFSC', 'Balance'],
        selectedIndex: _selectedIndex,
        rows: connectedBanks
            .map(
              (row) => [
                (row['bankName'] ?? '').toString(),
                (row['accountNo'] ?? '').toString(),
                (row['ifsc'] ?? '').toString(),
                (row['balance'] ?? '').toString(),
              ],
            )
            .toList(),
        onRowTap: (index) => setState(() => _selectedIndex = index),
      ),
      onEdit: _editSelected,
      onDelete: _deleteSelected,
      onSave: _save,
      onClear: _clearForm,
    );
  }
}

class OpeningBalanceScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const OpeningBalanceScreen({super.key, this.onClose});

  @override
  State<OpeningBalanceScreen> createState() => _OpeningBalanceScreenState();
}

class _OpeningBalanceScreenState extends State<OpeningBalanceScreen> {
  final TextEditingController _amountController = TextEditingController();

  String _accountName = 'Cash A/C';
  String _type = 'Credit';
  int? _selectedIndex;
  int? _editingId;

  List<String> get _accountOptions {
    final names = <String>{'Cash A/C', 'Sales A/C', 'Purchase A/C'};
    for (final a in accounts) {
      final n = (a['name'] ?? '').toString().trim();
      if (n.isNotEmpty) {
        names.add(n);
      }
    }
    return names.toList();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _clearForm() {
    final options = _accountOptions;
    setState(() {
      _accountName = options.isEmpty ? 'Cash A/C' : options.first;
      _amountController.clear();
      _type = 'Credit';
      _selectedIndex = null;
      _editingId = null;
    });
    _showMessage('Cleared');
  }

  void _editSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to edit');
      return;
    }
    final row = openingBalances[_selectedIndex!];
    setState(() {
      _editingId = row['id'] as int;
      _accountName = (row['accountName'] ?? '').toString();
      _amountController.text = (row['amount'] ?? '').toString();
      _type = (row['type'] ?? 'Credit').toString();
    });
  }

  void _deleteSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to delete');
      return;
    }
    final id = openingBalances[_selectedIndex!]['id'];
    setState(() {
      openingBalances.removeWhere((row) => row['id'] == id);
      _selectedIndex = null;
      _editingId = null;
      _amountController.clear();
      _type = 'Credit';
      final options = _accountOptions;
      _accountName = options.isEmpty ? 'Cash A/C' : options.first;
    });
    _showMessage('Deleted');
  }

  void _save() {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null) {
      _showMessage('Amount must be numeric');
      return;
    }

    setState(() {
      if (_editingId != null) {
        final index = openingBalances.indexWhere(
          (row) => row['id'] == _editingId,
        );
        if (index != -1) {
          openingBalances[index] = {
            ...openingBalances[index],
            'accountName': _accountName,
            'amount': amount.toStringAsFixed(2),
            'type': _type,
          };
        }
      } else {
        openingBalances.add({
          'id': _openingBalanceSeed++,
          'accountName': _accountName,
          'amount': amount.toStringAsFixed(2),
          'type': _type,
        });
      }

      _selectedIndex = null;
      _editingId = null;
      _amountController.clear();
      _type = 'Credit';
      final options = _accountOptions;
      _accountName = options.isEmpty ? 'Cash A/C' : options.first;
    });
    _showMessage('Saved Successfully');
  }

  @override
  Widget build(BuildContext context) {
    final options = _accountOptions;
    final selected = options.contains(_accountName)
        ? _accountName
        : (options.isEmpty ? 'Cash A/C' : options.first);

    return _MasterCrudLayout(
      title: 'Opening Balance',
      onClose: widget.onClose,
      formWidth: 430,
      formChild: Column(
        children: [
          _CompactFormRow(
            label: 'Account Name',
            field: _compactDropdown(
              value: selected,
              values: options,
              onChanged: (v) => setState(() => _accountName = v),
            ),
          ),
          _CompactFormRow(
            label: 'Amount',
            field: _compactInput(controller: _amountController),
          ),
          _CompactFormRow(
            label: 'Type',
            field: _compactDropdown(
              value: _type,
              values: const ['Credit', 'Debit'],
              onChanged: (v) => setState(() => _type = v),
            ),
          ),
        ],
      ),
      tableChild: _SimpleTable(
        headers: const ['Account Name', 'Amount', 'Type'],
        selectedIndex: _selectedIndex,
        rows: openingBalances
            .map(
              (row) => [
                (row['accountName'] ?? '').toString(),
                (row['amount'] ?? '').toString(),
                (row['type'] ?? '').toString(),
              ],
            )
            .toList(),
        onRowTap: (index) => setState(() => _selectedIndex = index),
      ),
      onEdit: _editSelected,
      onDelete: _deleteSelected,
      onSave: _save,
      onClear: _clearForm,
    );
  }
}

class CompanyMasterScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const CompanyMasterScreen({super.key, this.onClose});

  @override
  State<CompanyMasterScreen> createState() => _CompanyMasterScreenState();
}

class _CompanyMasterScreenState extends State<CompanyMasterScreen> {
  final _companyNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();

  int? _selectedIndex;
  int? _editingId;

  @override
  void dispose() {
    _companyNameController.dispose();
    _ownerNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _clearForm() {
    setState(() {
      _companyNameController.clear();
      _ownerNameController.clear();
      _mobileController.clear();
      _emailController.clear();
      _addressController.clear();
      _gstController.clear();
      _editingId = null;
      _selectedIndex = null;
    });
    _showMessage('Cleared');
  }

  void _editSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to edit');
      return;
    }
    final row = companies[_selectedIndex!];
    setState(() {
      _editingId = row['id'] as int;
      _companyNameController.text = (row['companyName'] ?? '').toString();
      _ownerNameController.text = (row['ownerName'] ?? '').toString();
      _mobileController.text = (row['mobile'] ?? '').toString();
      _emailController.text = (row['email'] ?? '').toString();
      _addressController.text = (row['address'] ?? '').toString();
      _gstController.text = (row['gst'] ?? '').toString();
    });
  }

  void _deleteSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to delete');
      return;
    }
    final id = companies[_selectedIndex!]['id'];
    setState(() {
      companies.removeWhere((row) => row['id'] == id);
      _selectedIndex = null;
      _editingId = null;
      _companyNameController.clear();
      _ownerNameController.clear();
      _mobileController.clear();
      _emailController.clear();
      _addressController.clear();
      _gstController.clear();
    });
    _showMessage('Deleted');
  }

  void _save() {
    final companyName = _companyNameController.text.trim();
    final ownerName = _ownerNameController.text.trim();
    final mobile = _mobileController.text.trim();
    final email = _emailController.text.trim();
    final address = _addressController.text.trim();
    final gst = _gstController.text.trim();

    if (companyName.isEmpty) {
      _showMessage('Company Name is required');
      return;
    }
    if (mobile.isNotEmpty && double.tryParse(mobile) == null) {
      _showMessage('Mobile must be numeric');
      return;
    }

    setState(() {
      if (_editingId != null) {
        final index = companies.indexWhere((row) => row['id'] == _editingId);
        if (index != -1) {
          companies[index] = {
            ...companies[index],
            'companyName': companyName,
            'ownerName': ownerName,
            'mobile': mobile,
            'email': email,
            'address': address,
            'gst': gst,
          };
        }
      } else {
        companies.add({
          'id': _companySeed++,
          'companyName': companyName,
          'ownerName': ownerName,
          'mobile': mobile,
          'email': email,
          'address': address,
          'gst': gst,
        });
      }

      _selectedIndex = null;
      _editingId = null;
      _companyNameController.clear();
      _ownerNameController.clear();
      _mobileController.clear();
      _emailController.clear();
      _addressController.clear();
      _gstController.clear();
    });
    _showMessage('Saved Successfully');
  }

  @override
  Widget build(BuildContext context) {
    return _MasterCrudLayout(
      title: 'Company Master',
      onClose: widget.onClose,
      formWidth: 470,
      formChild: _SectionCard(
        title: 'Company Details',
        child: Column(
          children: [
            _CompactFormRow(
              label: 'Company Name',
              field: _compactInput(controller: _companyNameController),
            ),
            const SizedBox(height: 4),
            _CompactFormRow(
              label: 'Owner Name',
              field: _compactInput(controller: _ownerNameController),
            ),
            const SizedBox(height: 4),
            _CompactFormRow(
              label: 'Mobile',
              field: _compactInput(
                controller: _mobileController,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(height: 4),
            _CompactFormRow(
              label: 'Email',
              field: _compactInput(controller: _emailController),
            ),
            const SizedBox(height: 4),
            _CompactFormRow(
              label: 'Address',
              topAligned: true,
              field: _compactInput(controller: _addressController, maxLines: 2),
            ),
            const SizedBox(height: 4),
            _CompactFormRow(
              label: 'GST Number',
              field: _compactInput(controller: _gstController),
            ),
          ],
        ),
      ),
      tableChild: _SectionCard(
        title: 'Records',
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        expandChild: true,
        child: _SimpleTable(
          headers: const ['Company Name', 'Mobile', 'GST'],
          selectedIndex: _selectedIndex,
          rows: companies
              .map(
                (row) => [
                  (row['companyName'] ?? '').toString(),
                  (row['mobile'] ?? '').toString(),
                  (row['gst'] ?? '').toString(),
                ],
              )
              .toList(),
          onRowTap: (index) => setState(() => _selectedIndex = index),
        ),
      ),
      onEdit: _editSelected,
      onDelete: _deleteSelected,
      onSave: _save,
      onClear: _clearForm,
    );
  }
}

class UserMasterScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const UserMasterScreen({super.key, this.onClose});

  @override
  State<UserMasterScreen> createState() => _UserMasterScreenState();
}

class _UserMasterScreenState extends State<UserMasterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mobileController = TextEditingController();

  String _role = 'Admin';
  int? _selectedIndex;
  int? _editingId;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _clearForm() {
    setState(() {
      _usernameController.clear();
      _passwordController.clear();
      _mobileController.clear();
      _role = 'Admin';
      _selectedIndex = null;
      _editingId = null;
    });
    _showMessage('Cleared');
  }

  void _editSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to edit');
      return;
    }
    final row = users[_selectedIndex!];
    setState(() {
      _editingId = row['id'] as int;
      _usernameController.text = (row['username'] ?? '').toString();
      _passwordController.text = (row['password'] ?? '').toString();
      _mobileController.text = (row['mobile'] ?? '').toString();
      _role = (row['role'] ?? 'Admin').toString();
    });
  }

  void _deleteSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to delete');
      return;
    }
    final id = users[_selectedIndex!]['id'];
    setState(() {
      users.removeWhere((row) => row['id'] == id);
      _selectedIndex = null;
      _editingId = null;
      _usernameController.clear();
      _passwordController.clear();
      _mobileController.clear();
      _role = 'Admin';
    });
    _showMessage('Deleted');
  }

  void _save() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final mobile = _mobileController.text.trim();

    if (username.isEmpty) {
      _showMessage('Username is required');
      return;
    }
    if (password.isEmpty) {
      _showMessage('Password is required');
      return;
    }
    if (mobile.isNotEmpty && double.tryParse(mobile) == null) {
      _showMessage('Mobile must be numeric');
      return;
    }

    final duplicate = users.any((row) {
      final sameName =
          (row['username'] ?? '').toString().toLowerCase() ==
          username.toLowerCase();
      final sameRecord = _editingId != null && row['id'] == _editingId;
      return sameName && !sameRecord;
    });
    if (duplicate) {
      _showMessage('Username must be unique');
      return;
    }

    setState(() {
      if (_editingId != null) {
        final index = users.indexWhere((row) => row['id'] == _editingId);
        if (index != -1) {
          users[index] = {
            ...users[index],
            'username': username,
            'password': password,
            'role': _role,
            'mobile': mobile,
          };
        }
      } else {
        users.add({
          'id': _userSeed++,
          'username': username,
          'password': password,
          'role': _role,
          'mobile': mobile,
        });
      }

      _selectedIndex = null;
      _editingId = null;
      _usernameController.clear();
      _passwordController.clear();
      _mobileController.clear();
      _role = 'Admin';
    });
    _showMessage('Saved Successfully');
  }

  @override
  Widget build(BuildContext context) {
    return _MasterCrudLayout(
      title: 'User Master',
      onClose: widget.onClose,
      formWidth: 470,
      formChild: _SectionCard(
        title: 'User Details',
        child: Column(
          children: [
            _CompactFormRow(
              label: 'Username',
              field: _compactInput(controller: _usernameController),
            ),
            const SizedBox(height: 4),
            _CompactFormRow(
              label: 'Password',
              field: _compactInput(
                controller: _passwordController,
                obscureText: true,
              ),
            ),
            const SizedBox(height: 4),
            _CompactFormRow(
              label: 'Role',
              field: _compactDropdown(
                value: _role,
                values: const ['Admin', 'Staff'],
                onChanged: (v) => setState(() => _role = v),
              ),
            ),
            const SizedBox(height: 4),
            _CompactFormRow(
              label: 'Mobile',
              field: _compactInput(
                controller: _mobileController,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ),
      tableChild: _SectionCard(
        title: 'Records',
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        expandChild: true,
        child: _SimpleTable(
          headers: const ['Username', 'Role', 'Mobile'],
          selectedIndex: _selectedIndex,
          rows: users
              .map(
                (row) => [
                  (row['username'] ?? '').toString(),
                  (row['role'] ?? '').toString(),
                  (row['mobile'] ?? '').toString(),
                ],
              )
              .toList(),
          onRowTap: (index) => setState(() => _selectedIndex = index),
        ),
      ),
      onEdit: _editSelected,
      onDelete: _deleteSelected,
      onSave: _save,
      onClear: _clearForm,
    );
  }
}

class BillingMasterScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const BillingMasterScreen({super.key, this.onClose});

  @override
  State<BillingMasterScreen> createState() => _BillingMasterScreenState();
}

class _BillingMasterScreenState extends State<BillingMasterScreen> {
  final _prefixController = TextEditingController();
  final _startNumberController = TextEditingController();
  final _discountController = TextEditingController();

  String _gstEnabled = 'Yes';
  int? _selectedIndex;
  int? _editingId;

  @override
  void dispose() {
    _prefixController.dispose();
    _startNumberController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _clearForm() {
    setState(() {
      _prefixController.clear();
      _startNumberController.clear();
      _discountController.clear();
      _gstEnabled = 'Yes';
      _selectedIndex = null;
      _editingId = null;
    });
    _showMessage('Cleared');
  }

  void _editSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to edit');
      return;
    }
    final row = billings[_selectedIndex!];
    setState(() {
      _editingId = row['id'] as int;
      _prefixController.text = (row['prefix'] ?? '').toString();
      _startNumberController.text = (row['startNo'] ?? '').toString();
      _discountController.text = (row['discount'] ?? '').toString();
      _gstEnabled = (row['gst'] ?? 'Yes').toString();
    });
  }

  void _deleteSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to delete');
      return;
    }
    final id = billings[_selectedIndex!]['id'];
    setState(() {
      billings.removeWhere((row) => row['id'] == id);
      _selectedIndex = null;
      _editingId = null;
      _prefixController.clear();
      _startNumberController.clear();
      _discountController.clear();
      _gstEnabled = 'Yes';
    });
    _showMessage('Deleted');
  }

  void _save() {
    final prefix = _prefixController.text.trim();
    final startNoText = _startNumberController.text.trim();
    final discountText = _discountController.text.trim();

    if (prefix.isEmpty) {
      _showMessage('Bill Prefix is required');
      return;
    }

    final startNo = int.tryParse(startNoText);
    if (startNo == null) {
      _showMessage('Starting Number must be numeric');
      return;
    }

    final discount = double.tryParse(discountText);
    if (discount == null) {
      _showMessage('Default Discount must be numeric');
      return;
    }

    setState(() {
      if (_editingId != null) {
        final index = billings.indexWhere((row) => row['id'] == _editingId);
        if (index != -1) {
          billings[index] = {
            ...billings[index],
            'prefix': prefix,
            'startNo': startNo.toString(),
            'gst': _gstEnabled,
            'discount': discount.toStringAsFixed(2),
          };
        }
      } else {
        billings.add({
          'id': _billingSeed++,
          'prefix': prefix,
          'startNo': startNo.toString(),
          'gst': _gstEnabled,
          'discount': discount.toStringAsFixed(2),
        });
      }

      _selectedIndex = null;
      _editingId = null;
      _prefixController.clear();
      _startNumberController.clear();
      _discountController.clear();
      _gstEnabled = 'Yes';
    });
    _showMessage('Saved Successfully');
  }

  @override
  Widget build(BuildContext context) {
    return _MasterCrudLayout(
      title: 'Billing Master',
      onClose: widget.onClose,
      formWidth: 470,
      formChild: _SectionCard(
        title: 'Billing Settings',
        child: Column(
          children: [
            _CompactFormRow(
              label: 'Bill Prefix',
              field: _compactInput(controller: _prefixController),
            ),
            const SizedBox(height: 4),
            _CompactFormRow(
              label: 'Starting No',
              field: _compactInput(
                controller: _startNumberController,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(height: 4),
            _CompactFormRow(
              label: 'GST Enabled',
              field: _compactDropdown(
                value: _gstEnabled,
                values: const ['Yes', 'No'],
                onChanged: (v) => setState(() => _gstEnabled = v),
              ),
            ),
            const SizedBox(height: 4),
            _CompactFormRow(
              label: 'Default Disc %',
              field: _compactInput(
                controller: _discountController,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ),
      tableChild: _SectionCard(
        title: 'Records',
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        expandChild: true,
        child: _SimpleTable(
          headers: const ['Prefix', 'Start No', 'GST', 'Discount %'],
          selectedIndex: _selectedIndex,
          rows: billings
              .map(
                (row) => [
                  (row['prefix'] ?? '').toString(),
                  (row['startNo'] ?? '').toString(),
                  (row['gst'] ?? '').toString(),
                  (row['discount'] ?? '').toString(),
                ],
              )
              .toList(),
          onRowTap: (index) => setState(() => _selectedIndex = index),
        ),
      ),
      onEdit: _editSelected,
      onDelete: _deleteSelected,
      onSave: _save,
      onClear: _clearForm,
    );
  }
}

class StockTransferScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const StockTransferScreen({super.key, this.onClose});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  final _transferNoController = TextEditingController();
  final _dateController = TextEditingController();
  final _qtyController = TextEditingController();

  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();
  final _productFocus = FocusNode();
  final _qtyFocus = FocusNode();

  String _fromStock = 'Main Store';
  String _toStock = 'Branch A';
  String _product = 'Paracetamol 650';

  List<Map<String, dynamic>> _items = [];
  int? _selectedRecordIndex;
  int? _hoveredItemIndex;
  int? _editingId;

  static const _stocks = ['Main Store', 'Branch A', 'Branch B', 'Warehouse'];
  static const _products = [
    'Paracetamol 650',
    'Azithromycin 500',
    'Dolo 650',
    'ORS Sachet',
  ];

  @override
  void initState() {
    super.initState();
    _dateController.text = _today();
    _transferNoController.text = _nextTransferNo();
  }

  @override
  void dispose() {
    _transferNoController.dispose();
    _dateController.dispose();
    _qtyController.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    _productFocus.dispose();
    _qtyFocus.dispose();
    super.dispose();
  }

  String _today() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
  }

  String _nextTransferNo() => 'ST-$_stockTransferSeed';

  int get _totalItems => _items.length;
  int get _totalQty =>
      _items.fold<int>(0, (s, i) => s + ((i['qty'] as int?) ?? 0));

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Widget _focusDropdown({
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
  }) {
    return SizedBox(
      height: 32,
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: (_, event) =>
            handleEnterToNext(context, nextFocusNode, event),
        child: DropdownButtonFormField<String>(
          value: values.contains(value) ? value : values.first,
          style: const TextStyle(fontSize: 12.5, color: Colors.black87),
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: values
              .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _readonlyField(TextEditingController c) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: c,
        readOnly: true,
        style: const TextStyle(fontSize: 12.5),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          filled: true,
          fillColor: const Color(0xFFF1F3F4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  void _addItem() {
    if (_fromStock == _toStock) {
      _showMessage('From and To stock cannot be same');
      return;
    }
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      _showMessage('Quantity must be valid');
      return;
    }
    setState(() {
      final idx = _items.indexWhere((i) => i['product'] == _product);
      if (idx != -1) {
        _items[idx] = {
          ..._items[idx],
          'qty': (_items[idx]['qty'] as int) + qty,
        };
      } else {
        _items.add({'product': _product, 'qty': qty});
      }
      _qtyController.clear();
    });
    _productFocus.requestFocus();
  }

  void _removeItem(int i) {
    if (i < 0 || i >= _items.length) return;
    setState(() => _items.removeAt(i));
  }

  void _reset({bool focusFirst = true}) {
    setState(() {
      _fromStock = _stocks.first;
      _toStock = _stocks[1];
      _product = _products.first;
      _items = [];
      _qtyController.clear();
      _selectedRecordIndex = null;
      _editingId = null;
      _dateController.text = _today();
      _transferNoController.text = _nextTransferNo();
    });
    if (focusFirst) _fromFocus.requestFocus();
  }

  void _clear() {
    _reset();
    _showMessage('Cleared');
  }

  void _save() {
    if (_items.isEmpty) {
      _showMessage('Add at least one item');
      return;
    }
    final record = {
      'id': _editingId ?? _stockTransferSeed,
      'transferNo': _transferNoController.text,
      'date': _dateController.text,
      'from': _fromStock,
      'to': _toStock,
      'items': _items.map((e) => Map<String, dynamic>.from(e)).toList(),
      'totalItems': _totalItems,
      'totalQty': _totalQty,
    };
    setState(() {
      if (_editingId != null) {
        final idx = stockTransferRecords.indexWhere(
          (r) => r['id'] == _editingId,
        );
        if (idx != -1) stockTransferRecords[idx] = record;
      } else {
        stockTransferRecords.add(record);
        _stockTransferSeed++;
      }
    });
    unawaited(persistStockTransferDoc(record));
    _reset();
    _showMessage('Saved Successfully');
  }

  void _edit() {
    if (_selectedRecordIndex == null) {
      _showMessage('Select a transfer record');
      return;
    }
    final r = stockTransferRecords[_selectedRecordIndex!];
    setState(() {
      _editingId = r['id'] as int?;
      _transferNoController.text = (r['transferNo'] ?? '').toString();
      _dateController.text = (r['date'] ?? _today()).toString();
      _fromStock = (r['from'] ?? _stocks.first).toString();
      _toStock = (r['to'] ?? _stocks[1]).toString();
      _items = (r['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _qtyController.clear();
    });
    _fromFocus.requestFocus();
  }

  void _delete() {
    if (_selectedRecordIndex == null) {
      _showMessage('Select a transfer record');
      return;
    }
    final removed = stockTransferRecords[_selectedRecordIndex!];
    final int? docId = removed['id'] as int?;
    setState(() {
      stockTransferRecords.removeAt(_selectedRecordIndex!);
      _selectedRecordIndex = null;
    });
    if (docId != null) {
      unawaited(deleteStockTransferDoc(docId));
    }
    _showMessage('Deleted');
  }

  @override
  Widget build(BuildContext context) {
    return _MasterCrudLayout(
      title: 'Stock Transfer',
      onClose: widget.onClose,
      formWidth: 560,
      formChild: Column(
        children: [
          _SectionCard(
            title: 'Basic Info',
            child: Column(
              children: [
                _CompactFormRow(
                  label: 'From Stock',
                  field: _focusDropdown(
                    value: _fromStock,
                    values: _stocks,
                    onChanged: (v) => setState(() => _fromStock = v),
                    focusNode: _fromFocus,
                    nextFocusNode: _toFocus,
                  ),
                ),
                _CompactFormRow(
                  label: 'To Stock',
                  field: _focusDropdown(
                    value: _toStock,
                    values: _stocks,
                    onChanged: (v) => setState(() => _toStock = v),
                    focusNode: _toFocus,
                    nextFocusNode: _productFocus,
                  ),
                ),
                _CompactFormRow(
                  label: 'Transfer No',
                  field: _readonlyField(_transferNoController),
                ),
                _CompactFormRow(
                  label: 'Date',
                  field: _readonlyField(_dateController),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Product Entry',
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _focusDropdown(
                    value: _product,
                    values: _products,
                    onChanged: (v) => setState(() => _product = v),
                    focusNode: _productFocus,
                    nextFocusNode: _qtyFocus,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _compactInput(
                    controller: _qtyController,
                    focusNode: _qtyFocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addItem(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Saved Transfers',
            child: stockTransferRecords.isEmpty
                ? Text(
                    'No stock transfer records',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey.shade500,
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(stockTransferRecords.length, (i) {
                      final r = stockTransferRecords[i];
                      final selected = _selectedRecordIndex == i;
                      return InkWell(
                        onTap: () => setState(() => _selectedRecordIndex = i),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFDCEBFF)
                                : const Color(0xFFF2F4F5),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected
                                  ? Colors.blue.shade300
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            (r['transferNo'] ?? '').toString(),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
          ),
        ],
      ),
      tableChild: _SectionCard(
        title: 'Transfer Items',
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        expandChild: true,
        child: Column(
          children: [
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE9EFEC),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      'Product',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Qty',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      'Remove',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Text(
                        'No items added',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.blueGrey.shade500,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final hovered = _hoveredItemIndex == index;
                        return MouseRegion(
                          onEnter: (_) =>
                              setState(() => _hoveredItemIndex = index),
                          onExit: (_) =>
                              setState(() => _hoveredItemIndex = null),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            margin: const EdgeInsets.only(bottom: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: hovered
                                  ? const Color(0xFFF5FAF8)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    (item['product'] ?? '').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    (item['qty'] ?? '').toString(),
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                                SizedBox(
                                  width: 64,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: () => _removeItem(index),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 6),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: const Color(0xFFF3F6F5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.summarize_outlined,
                      size: 16,
                      color: Color(0xFF3A5A4B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Total Items: $_totalItems',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Total Quantity: $_totalQty',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      onEdit: _edit,
      onDelete: _delete,
      onSave: _save,
      onClear: _clear,
    );
  }
}

class ConversionScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const ConversionScreen({super.key, this.onClose});

  @override
  State<ConversionScreen> createState() => _ConversionScreenState();
}

class _ConversionScreenState extends State<ConversionScreen> {
  final _conversionNoController = TextEditingController();
  final _dateController = TextEditingController();
  final _ratioController = TextEditingController(text: '1:10');
  final _qtyController = TextEditingController();

  final _fromProductFocus = FocusNode();
  final _toProductFocus = FocusNode();
  final _ratioFocus = FocusNode();
  final _qtyFocus = FocusNode();

  String _fromProduct = 'Paracetamol 650';
  String _toProduct = 'Paracetamol Strip';

  List<Map<String, dynamic>> _rows = [];
  int? _selectedRecordIndex;
  int? _hoveredRow;
  int? _editingId;

  static const _products = [
    'Paracetamol 650',
    'Paracetamol Strip',
    'Azithromycin 500',
    'Vitamin C',
    'ORS Sachet',
  ];

  @override
  void initState() {
    super.initState();
    _dateController.text = _today();
    _conversionNoController.text = _nextNo();
  }

  @override
  void dispose() {
    _conversionNoController.dispose();
    _dateController.dispose();
    _ratioController.dispose();
    _qtyController.dispose();
    _fromProductFocus.dispose();
    _toProductFocus.dispose();
    _ratioFocus.dispose();
    _qtyFocus.dispose();
    super.dispose();
  }

  String _today() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
  }

  String _nextNo() => 'CV-$_conversionSeed';

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Widget _focusDropdown({
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
  }) {
    return SizedBox(
      height: 32,
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: (_, event) =>
            handleEnterToNext(context, nextFocusNode, event),
        child: DropdownButtonFormField<String>(
          value: values.contains(value) ? value : values.first,
          style: const TextStyle(fontSize: 12.5, color: Colors.black87),
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: values
              .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _readonlyField(TextEditingController c) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: c,
        readOnly: true,
        style: const TextStyle(fontSize: 12.5),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          filled: true,
          fillColor: const Color(0xFFF1F3F4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  double? _computeConvertedQty(int qty, String ratio) {
    final parts = ratio.split(':');
    if (parts.length != 2) return null;
    final from = double.tryParse(parts[0].trim());
    final to = double.tryParse(parts[1].trim());
    if (from == null || to == null || from <= 0 || to <= 0) return null;
    return (qty / from) * to;
  }

  void _addRow() {
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      _showMessage('Quantity must be valid');
      return;
    }
    final ratio = _ratioController.text.trim();
    final converted = _computeConvertedQty(qty, ratio);
    if (converted == null) {
      _showMessage('Ratio must be in format like 1:10');
      return;
    }
    setState(() {
      _rows.add({
        'from': _fromProduct,
        'to': _toProduct,
        'ratio': ratio,
        'qty': qty,
        'converted': converted.toStringAsFixed(2),
      });
      _qtyController.clear();
    });
    _fromProductFocus.requestFocus();
  }

  void _removeRow(int index) {
    if (index < 0 || index >= _rows.length) return;
    setState(() => _rows.removeAt(index));
  }

  void _reset({bool focusFirst = true}) {
    setState(() {
      _fromProduct = _products.first;
      _toProduct = _products[1];
      _ratioController.text = '1:10';
      _qtyController.clear();
      _rows = [];
      _selectedRecordIndex = null;
      _editingId = null;
      _dateController.text = _today();
      _conversionNoController.text = _nextNo();
    });
    if (focusFirst) _fromProductFocus.requestFocus();
  }

  void _clear() {
    _reset();
    _showMessage('Cleared');
  }

  void _save() {
    if (_rows.isEmpty) {
      _showMessage('Add at least one conversion row');
      return;
    }
    final record = {
      'id': _editingId ?? _conversionSeed,
      'conversionNo': _conversionNoController.text,
      'date': _dateController.text,
      'rows': _rows.map((e) => Map<String, dynamic>.from(e)).toList(),
    };
    setState(() {
      if (_editingId != null) {
        final idx = conversionRecords.indexWhere((r) => r['id'] == _editingId);
        if (idx != -1) conversionRecords[idx] = record;
      } else {
        conversionRecords.add(record);
        _conversionSeed++;
      }
    });
    _reset();
    _showMessage('Saved Successfully');
  }

  void _edit() {
    if (_selectedRecordIndex == null) {
      _showMessage('Select a conversion record');
      return;
    }
    final r = conversionRecords[_selectedRecordIndex!];
    final rows = (r['rows'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    setState(() {
      _editingId = r['id'] as int?;
      _conversionNoController.text = (r['conversionNo'] ?? '').toString();
      _dateController.text = (r['date'] ?? _today()).toString();
      _rows = rows;
      _qtyController.clear();
    });
    _fromProductFocus.requestFocus();
  }

  void _delete() {
    if (_selectedRecordIndex == null) {
      _showMessage('Select a conversion record');
      return;
    }
    setState(() {
      conversionRecords.removeAt(_selectedRecordIndex!);
      _selectedRecordIndex = null;
    });
    _showMessage('Deleted');
  }

  @override
  Widget build(BuildContext context) {
    return _MasterCrudLayout(
      title: 'Conversion',
      onClose: widget.onClose,
      formWidth: 560,
      formChild: Column(
        children: [
          _SectionCard(
            title: 'Basic Info',
            child: Column(
              children: [
                _CompactFormRow(
                  label: 'Conversion No',
                  field: _readonlyField(_conversionNoController),
                ),
                _CompactFormRow(
                  label: 'Date',
                  field: _readonlyField(_dateController),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Product Entry',
            child: Column(
              children: [
                _CompactFormRow(
                  label: 'From Product',
                  field: _focusDropdown(
                    value: _fromProduct,
                    values: _products,
                    onChanged: (v) => setState(() => _fromProduct = v),
                    focusNode: _fromProductFocus,
                    nextFocusNode: _toProductFocus,
                  ),
                ),
                _CompactFormRow(
                  label: 'To Product',
                  field: _focusDropdown(
                    value: _toProduct,
                    values: _products,
                    onChanged: (v) => setState(() => _toProduct = v),
                    focusNode: _toProductFocus,
                    nextFocusNode: _ratioFocus,
                  ),
                ),
                _CompactFormRow(
                  label: 'Ratio',
                  field: _compactInput(
                    controller: _ratioController,
                    focusNode: _ratioFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => nextFocus(context, _qtyFocus),
                  ),
                ),
                _CompactFormRow(
                  label: 'Quantity',
                  field: _compactInput(
                    controller: _qtyController,
                    focusNode: _qtyFocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addRow(),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Row'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Saved Conversions',
            child: conversionRecords.isEmpty
                ? Text(
                    'No conversion records',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey.shade500,
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(conversionRecords.length, (i) {
                      final r = conversionRecords[i];
                      final selected = _selectedRecordIndex == i;
                      return InkWell(
                        onTap: () => setState(() => _selectedRecordIndex = i),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFDCEBFF)
                                : const Color(0xFFF2F4F5),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected
                                  ? Colors.blue.shade300
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            (r['conversionNo'] ?? '').toString(),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
          ),
        ],
      ),
      tableChild: _SectionCard(
        title: 'Conversion Rows',
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        expandChild: true,
        child: Column(
          children: [
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE9EFEC),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'From',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'To',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Ratio',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Qty',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Converted',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      'Remove',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _rows.isEmpty
                  ? Center(
                      child: Text(
                        'No conversion rows added',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.blueGrey.shade500,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        final row = _rows[index];
                        final hovered = _hoveredRow == index;
                        return MouseRegion(
                          onEnter: (_) => setState(() => _hoveredRow = index),
                          onExit: (_) => setState(() => _hoveredRow = null),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            margin: const EdgeInsets.only(bottom: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: hovered
                                  ? const Color(0xFFF5FAF8)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    (row['from'] ?? '').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    (row['to'] ?? '').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    (row['ratio'] ?? '').toString(),
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    (row['qty'] ?? '').toString(),
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    (row['converted'] ?? '').toString(),
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                                SizedBox(
                                  width: 64,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: () => _removeRow(index),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      onEdit: _edit,
      onDelete: _delete,
      onSave: _save,
      onClear: _clear,
    );
  }
}

class OtherIssueReceiptScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const OtherIssueReceiptScreen({super.key, this.onClose});

  @override
  State<OtherIssueReceiptScreen> createState() =>
      _OtherIssueReceiptScreenState();
}

class _OtherIssueReceiptScreenState extends State<OtherIssueReceiptScreen> {
  final _entryNoController = TextEditingController();
  final _dateController = TextEditingController();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  final _typeFocus = FocusNode();
  final _accountFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _reasonFocus = FocusNode();

  String _type = 'Issue';
  String _account = 'Aarav Pharma';
  int? _selectedIndex;
  int? _hoveredIndex;
  int? _editingId;

  static const _types = ['Issue', 'Receipt'];
  static const _accounts = [
    'Aarav Pharma',
    'MediCare Plus',
    'Krishna Clinic',
    'Health First',
  ];

  @override
  void initState() {
    super.initState();
    _dateController.text = _today();
    _entryNoController.text = _nextNo();
  }

  @override
  void dispose() {
    _entryNoController.dispose();
    _dateController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    _typeFocus.dispose();
    _accountFocus.dispose();
    _amountFocus.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  String _today() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
  }

  String _nextNo() => 'OR-$_otherIssueReceiptSeed';

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Widget _focusDropdown({
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
  }) {
    return SizedBox(
      height: 32,
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: (_, event) =>
            handleEnterToNext(context, nextFocusNode, event),
        child: DropdownButtonFormField<String>(
          value: values.contains(value) ? value : values.first,
          style: const TextStyle(fontSize: 12.5, color: Colors.black87),
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: values
              .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _readonlyField(TextEditingController c) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: c,
        readOnly: true,
        style: const TextStyle(fontSize: 12.5),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          filled: true,
          fillColor: const Color(0xFFF1F3F4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  void _reset({bool focusFirst = true}) {
    setState(() {
      _type = _types.first;
      _account = _accounts.first;
      _amountController.clear();
      _reasonController.clear();
      _editingId = null;
      _selectedIndex = null;
      _dateController.text = _today();
      _entryNoController.text = _nextNo();
    });
    if (focusFirst) _typeFocus.requestFocus();
  }

  void _clear() {
    _reset();
    _showMessage('Cleared');
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.trim());
    final reason = _reasonController.text.trim();
    if (amount == null || amount <= 0) {
      _showMessage('Amount must be valid');
      return;
    }
    if (reason.isEmpty) {
      _showMessage('Reason is required');
      return;
    }
    final record = {
      'id': _editingId ?? _otherIssueReceiptSeed,
      'entryNo': _entryNoController.text,
      'date': _dateController.text,
      'type': _type,
      'account': _account,
      'amount': amount.toStringAsFixed(2),
      'reason': reason,
    };
    setState(() {
      if (_editingId != null) {
        final idx = otherIssueReceiptRecords.indexWhere(
          (r) => r['id'] == _editingId,
        );
        if (idx != -1) otherIssueReceiptRecords[idx] = record;
      } else {
        otherIssueReceiptRecords.add(record);
        _otherIssueReceiptSeed++;
      }
    });
    _reset();
    _showMessage('Saved Successfully');
  }

  void _edit() {
    if (_selectedIndex == null) {
      _showMessage('Select a record to edit');
      return;
    }
    final r = otherIssueReceiptRecords[_selectedIndex!];
    setState(() {
      _editingId = r['id'] as int?;
      _entryNoController.text = (r['entryNo'] ?? '').toString();
      _dateController.text = (r['date'] ?? _today()).toString();
      _type = (r['type'] ?? _types.first).toString();
      _account = (r['account'] ?? _accounts.first).toString();
      _amountController.text = (r['amount'] ?? '').toString();
      _reasonController.text = (r['reason'] ?? '').toString();
    });
    _typeFocus.requestFocus();
  }

  void _delete() {
    if (_selectedIndex == null) {
      _showMessage('Select a record to delete');
      return;
    }
    setState(() {
      otherIssueReceiptRecords.removeAt(_selectedIndex!);
      _selectedIndex = null;
    });
    _showMessage('Deleted');
  }

  void _deleteRow(int index) {
    if (index < 0 || index >= otherIssueReceiptRecords.length) return;
    setState(() {
      otherIssueReceiptRecords.removeAt(index);
      if (_selectedIndex == index) {
        _selectedIndex = null;
      } else if (_selectedIndex != null && _selectedIndex! > index) {
        _selectedIndex = _selectedIndex! - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _MasterCrudLayout(
      title: 'Other Issue / Receipt',
      onClose: widget.onClose,
      formWidth: 560,
      formChild: Column(
        children: [
          _SectionCard(
            title: 'Basic Info',
            child: Column(
              children: [
                _CompactFormRow(
                  label: 'Type',
                  field: _focusDropdown(
                    value: _type,
                    values: _types,
                    onChanged: (v) => setState(() => _type = v),
                    focusNode: _typeFocus,
                    nextFocusNode: _accountFocus,
                  ),
                ),
                _CompactFormRow(
                  label: 'Account Name',
                  field: _focusDropdown(
                    value: _account,
                    values: _accounts,
                    onChanged: (v) => setState(() => _account = v),
                    focusNode: _accountFocus,
                    nextFocusNode: _amountFocus,
                  ),
                ),
                _CompactFormRow(
                  label: 'Entry No',
                  field: _readonlyField(_entryNoController),
                ),
                _CompactFormRow(
                  label: 'Date',
                  field: _readonlyField(_dateController),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Entry Details',
            child: Column(
              children: [
                _CompactFormRow(
                  label: 'Amount',
                  field: _compactInput(
                    controller: _amountController,
                    focusNode: _amountFocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => nextFocus(context, _reasonFocus),
                  ),
                ),
                _CompactFormRow(
                  label: 'Reason',
                  topAligned: true,
                  field: _compactInput(
                    controller: _reasonController,
                    focusNode: _reasonFocus,
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      tableChild: _SectionCard(
        title: 'Records',
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        expandChild: true,
        child: Column(
          children: [
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE9EFEC),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'No',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Type',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Account',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Reason',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: otherIssueReceiptRecords.isEmpty
                  ? Center(
                      child: Text(
                        'No records found',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.blueGrey.shade500,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: otherIssueReceiptRecords.length,
                      itemBuilder: (context, index) {
                        final row = otherIssueReceiptRecords[index];
                        final selected = _selectedIndex == index;
                        final hovered = _hoveredIndex == index;
                        final issueType = (row['type'] ?? 'Issue').toString();
                        return MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = index),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: InkWell(
                            onTap: () => setState(() => _selectedIndex = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              margin: const EdgeInsets.only(bottom: 5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFDCEBFF)
                                    : hovered
                                    ? const Color(0xFFF5FAF8)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      (row['entryNo'] ?? '').toString(),
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      issueType,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: issueType == 'Issue'
                                            ? Colors.red.shade700
                                            : Colors.green.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      (row['account'] ?? '').toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Rs. ${(row['amount'] ?? '').toString()}',
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      (row['reason'] ?? '').toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 64,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(18),
                                        onTap: () => _deleteRow(index),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      onEdit: _edit,
      onDelete: _delete,
      onSave: _save,
      onClear: _clear,
    );
  }
}

class DeliveryMemoScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const DeliveryMemoScreen({super.key, this.onClose});

  @override
  State<DeliveryMemoScreen> createState() => _DeliveryMemoScreenState();
}

class _DeliveryMemoScreenState extends State<DeliveryMemoScreen> {
  final _deliveryNoController = TextEditingController();
  final _dateController = TextEditingController();
  final _mobileController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  final _qtyController = TextEditingController();

  final _customerFocus = FocusNode();
  final _mobileFocus = FocusNode();
  final _referenceFocus = FocusNode();
  final _notesFocus = FocusNode();
  final _productFocus = FocusNode();
  final _qtyFocus = FocusNode();

  String _customer = 'Aarav Pharma';
  String _selectedProduct = 'Paracetamol 650';
  int? _selectedMemoIndex;
  int? _hoveredItemIndex;
  int? _editingMemoId;

  List<Map<String, dynamic>> deliveryItems = [];

  static const List<String> _customers = [
    'Aarav Pharma',
    'MediCare Plus',
    'Krishna Clinic',
    'Health First',
    'City Hospital',
  ];

  static const Map<String, String> _customerMobile = {
    'Aarav Pharma': '9876543210',
    'MediCare Plus': '9898989898',
    'Krishna Clinic': '9123456780',
    'Health First': '9812345670',
    'City Hospital': '9000012345',
  };

  static const List<String> _products = [
    'Paracetamol 650',
    'Azithromycin 500',
    'Vitamin C',
    'Dolo 650',
    'ORS Sachet',
  ];

  @override
  void initState() {
    super.initState();
    _dateController.text = _today();
    _mobileController.text = _customerMobile[_customer] ?? '';
    _deliveryNoController.text = _nextDeliveryNo();
  }

  @override
  void dispose() {
    _deliveryNoController.dispose();
    _dateController.dispose();
    _mobileController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    _qtyController.dispose();
    _customerFocus.dispose();
    _mobileFocus.dispose();
    _referenceFocus.dispose();
    _notesFocus.dispose();
    _productFocus.dispose();
    _qtyFocus.dispose();
    super.dispose();
  }

  String _today() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '$dd-$mm-${now.year}';
  }

  String _nextDeliveryNo() => 'DM-$_deliveryMemoSeed';

  int get _totalItems => deliveryItems.length;
  int get _totalQty => deliveryItems.fold<int>(
    0,
    (sum, row) => sum + ((row['qty'] as int?) ?? 0),
  );

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _applyCustomerMobile(String customer) {
    _mobileController.text = _customerMobile[customer] ?? '';
  }

  void _resetAll({bool focusFirst = true}) {
    setState(() {
      _editingMemoId = null;
      _selectedMemoIndex = null;
      _customer = _customers.first;
      _selectedProduct = _products.first;
      _dateController.text = _today();
      _referenceController.clear();
      _notesController.clear();
      _qtyController.clear();
      deliveryItems = [];
      _deliveryNoController.text = _nextDeliveryNo();
      _applyCustomerMobile(_customer);
    });
    if (focusFirst) {
      _customerFocus.requestFocus();
    }
  }

  void _clearForm() {
    _resetAll();
    _showMessage('Cleared');
  }

  void _addItem() {
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      _showMessage('Quantity must be a valid number');
      return;
    }

    setState(() {
      final existing = deliveryItems.indexWhere(
        (r) => r['product'] == _selectedProduct,
      );
      if (existing != -1) {
        deliveryItems[existing] = {
          ...deliveryItems[existing],
          'qty': (deliveryItems[existing]['qty'] as int) + qty,
        };
      } else {
        deliveryItems.add({'product': _selectedProduct, 'qty': qty});
      }
      _qtyController.clear();
    });
    _productFocus.requestFocus();
  }

  void _removeItemAt(int index) {
    if (index < 0 || index >= deliveryItems.length) {
      return;
    }
    setState(() {
      deliveryItems.removeAt(index);
    });
  }

  void _saveMemo() {
    if (deliveryItems.isEmpty) {
      _showMessage('Add at least one product item');
      return;
    }

    final memo = {
      'id': _editingMemoId ?? _deliveryMemoSeed,
      'deliveryNo': _deliveryNoController.text,
      'customer': _customer,
      'mobile': _mobileController.text.trim(),
      'date': _dateController.text,
      'reference': _referenceController.text.trim(),
      'notes': _notesController.text.trim(),
      'items': deliveryItems.map((e) => Map<String, dynamic>.from(e)).toList(),
      'totalItems': _totalItems,
      'totalQty': _totalQty,
    };

    setState(() {
      if (_editingMemoId != null) {
        final idx = deliveryMemos.indexWhere((m) => m['id'] == _editingMemoId);
        if (idx != -1) {
          deliveryMemos[idx] = memo;
        }
      } else {
        deliveryMemos.add(memo);
        _deliveryMemoSeed++;
      }
    });

    _resetAll();
    _showMessage('Saved Successfully');
  }

  void _editMemo() {
    if (_selectedMemoIndex == null) {
      _showMessage('Select a memo to edit');
      return;
    }
    final memo = deliveryMemos[_selectedMemoIndex!];
    final items = (memo['items'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    setState(() {
      _editingMemoId = memo['id'] as int?;
      _deliveryNoController.text = (memo['deliveryNo'] ?? '').toString();
      _customer = (memo['customer'] ?? _customers.first).toString();
      _mobileController.text = (memo['mobile'] ?? '').toString();
      _dateController.text = (memo['date'] ?? _today()).toString();
      _referenceController.text = (memo['reference'] ?? '').toString();
      _notesController.text = (memo['notes'] ?? '').toString();
      deliveryItems = items;
      _selectedProduct = _products.first;
      _qtyController.clear();
    });
    _customerFocus.requestFocus();
  }

  void _deleteMemo() {
    if (_selectedMemoIndex == null) {
      _showMessage('Select a memo to delete');
      return;
    }
    setState(() {
      deliveryMemos.removeAt(_selectedMemoIndex!);
      _selectedMemoIndex = null;
    });
    _showMessage('Deleted');
  }

  void _previewMemo() {
    if (_selectedMemoIndex == null) {
      _showMessage('Select a memo to preview');
      return;
    }
    final memo = deliveryMemos[_selectedMemoIndex!];
    final items = (memo['items'] as List<dynamic>? ?? []);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 560,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.visibility, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    'Delivery Memo Preview',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _previewLine(
                'Delivery No',
                (memo['deliveryNo'] ?? '').toString(),
              ),
              _previewLine('Customer', (memo['customer'] ?? '').toString()),
              _previewLine('Mobile', (memo['mobile'] ?? '').toString()),
              _previewLine('Date', (memo['date'] ?? '').toString()),
              _previewLine('Reference', (memo['reference'] ?? '').toString()),
              _previewLine('Notes', (memo['notes'] ?? '').toString()),
              _previewLine('Total Items', (memo['totalItems'] ?? 0).toString()),
              _previewLine(
                'Total Quantity',
                (memo['totalQty'] ?? 0).toString(),
              ),
              const SizedBox(height: 8),
              const Text(
                'Products',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '- ${(item['product'] ?? '').toString()}  x ${(item['qty'] ?? '').toString()}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }

  Widget _focusDropdown({
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
  }) {
    return SizedBox(
      height: 32,
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: (_, event) =>
            handleEnterToNext(context, nextFocusNode, event),
        child: DropdownButtonFormField<String>(
          value: values.contains(value) ? value : values.first,
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          style: const TextStyle(fontSize: 12.5, color: Colors.black87),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
          ),
          items: values
              .map(
                (item) =>
                    DropdownMenuItem<String>(value: item, child: Text(item)),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) {
              onChanged(v);
            }
          },
        ),
      ),
    );
  }

  Widget _readonlyField(TextEditingController controller) {
    return SizedBox(
      height: 32,
      child: TextField(
        readOnly: true,
        controller: controller,
        style: const TextStyle(fontSize: 12.5),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          filled: true,
          fillColor: const Color(0xFFF1F3F4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _MasterCrudLayout(
      title: 'Delivery Memo',
      onClose: widget.onClose,
      formWidth: 560,
      formChild: Column(
        children: [
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F9F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Memo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manage product delivery records',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Memo Details',
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _CompactFormRow(
                            label: 'Customer Name',
                            field: _focusDropdown(
                              value: _customer,
                              values: _customers,
                              focusNode: _customerFocus,
                              nextFocusNode: _mobileFocus,
                              onChanged: (v) {
                                setState(() {
                                  _customer = v;
                                  _applyCustomerMobile(v);
                                });
                              },
                            ),
                          ),
                          _CompactFormRow(
                            label: 'Mobile',
                            field: _compactInput(
                              controller: _mobileController,
                              focusNode: _mobileFocus,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) =>
                                  nextFocus(context, _referenceFocus),
                            ),
                          ),
                          _CompactFormRow(
                            label: 'Date',
                            field: _readonlyField(_dateController),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          _CompactFormRow(
                            label: 'Delivery No',
                            field: _readonlyField(_deliveryNoController),
                          ),
                          _CompactFormRow(
                            label: 'Reference No',
                            field: _compactInput(
                              controller: _referenceController,
                              focusNode: _referenceFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) =>
                                  nextFocus(context, _notesFocus),
                            ),
                          ),
                          _CompactFormRow(
                            label: 'Notes',
                            topAligned: true,
                            field: _compactInput(
                              controller: _notesController,
                              focusNode: _notesFocus,
                              maxLines: 2,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) =>
                                  nextFocus(context, _productFocus),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Product Entry',
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _focusDropdown(
                    value: _selectedProduct,
                    values: _products,
                    focusNode: _productFocus,
                    nextFocusNode: _qtyFocus,
                    onChanged: (v) => setState(() => _selectedProduct = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _compactInput(
                    controller: _qtyController,
                    focusNode: _qtyFocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addItem(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Saved Memos',
            child: deliveryMemos.isEmpty
                ? Text(
                    'No delivery memos saved yet',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey.shade500,
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(deliveryMemos.length, (index) {
                      final memo = deliveryMemos[index];
                      final selected = _selectedMemoIndex == index;
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setState(() => _selectedMemoIndex = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFDCEBFF)
                                : const Color(0xFFF2F4F5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? Colors.blue.shade300
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            (memo['deliveryNo'] ?? '').toString(),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.blue.shade800
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
          ),
        ],
      ),
      tableChild: _SectionCard(
        title: 'Items',
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        expandChild: true,
        child: Column(
          children: [
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE9EFEC),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      'Product',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Qty',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      'Remove',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: deliveryItems.isEmpty
                  ? Center(
                      child: Text(
                        'No items added',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.blueGrey.shade500,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: deliveryItems.length,
                      itemBuilder: (context, index) {
                        final item = deliveryItems[index];
                        final hovered = _hoveredItemIndex == index;
                        return MouseRegion(
                          onEnter: (_) =>
                              setState(() => _hoveredItemIndex = index),
                          onExit: (_) =>
                              setState(() => _hoveredItemIndex = null),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            margin: const EdgeInsets.only(bottom: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: hovered
                                  ? const Color(0xFFF5FAF8)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    (item['product'] ?? '').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    (item['qty'] ?? '').toString(),
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                                SizedBox(
                                  width: 64,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: () => _removeItemAt(index),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 6),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: const Color(0xFFF3F6F5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.summarize_outlined,
                      size: 16,
                      color: Color(0xFF3A5A4B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Total Items: $_totalItems',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Total Quantity: $_totalQty',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedMemoIndex != null)
                      TextButton.icon(
                        onPressed: _previewMemo,
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('Preview'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      onEdit: _editMemo,
      onDelete: _deleteMemo,
      onSave: _saveMemo,
      onClear: _clearForm,
    );
  }
}

class CreditDebitNoteScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const CreditDebitNoteScreen({super.key, this.onClose});

  @override
  State<CreditDebitNoteScreen> createState() => _CreditDebitNoteScreenState();
}

class _CreditDebitNoteScreenState extends State<CreditDebitNoteScreen> {
  final _noteNoController = TextEditingController();
  final _dateController = TextEditingController();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _referenceController = TextEditingController();

  final _noteTypeFocus = FocusNode();
  final _accountFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _reasonFocus = FocusNode();
  final _paymentModeFocus = FocusNode();
  final _referenceFocus = FocusNode();

  String _noteType = 'Credit';
  String _account = 'Aarav Pharma';
  String _paymentMode = 'Cash';
  int? _selectedIndex;
  int? _editingId;
  int? _hoveredIndex;

  static const List<String> _accounts = [
    'Aarav Pharma',
    'MediCare Plus',
    'Krishna Clinic',
    'Health First',
    'City Hospital',
  ];

  static const List<String> _paymentModes = ['Cash', 'UPI', 'Bank'];

  @override
  void initState() {
    super.initState();
    _dateController.text = _today();
    _refreshNoteNo();
  }

  @override
  void dispose() {
    _noteNoController.dispose();
    _dateController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    _referenceController.dispose();
    _noteTypeFocus.dispose();
    _accountFocus.dispose();
    _amountFocus.dispose();
    _reasonFocus.dispose();
    _paymentModeFocus.dispose();
    _referenceFocus.dispose();
    super.dispose();
  }

  String _today() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '$dd-$mm-${now.year}';
  }

  String _nextNoteNo(String type) {
    final isCredit = type == 'Credit';
    final prefix = isCredit ? 'CN' : 'DN';
    final seed = isCredit ? _creditNoteNumberSeed : _debitNoteNumberSeed;
    return '$prefix-$seed';
  }

  void _refreshNoteNo() {
    if (_editingId == null) {
      _noteNoController.text = _nextNoteNo(_noteType);
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _resetForm({bool focusFirst = true}) {
    setState(() {
      _editingId = null;
      _selectedIndex = null;
      _noteType = 'Credit';
      _account = _accounts.first;
      _paymentMode = _paymentModes.first;
      _dateController.text = _today();
      _amountController.clear();
      _reasonController.clear();
      _referenceController.clear();
      _refreshNoteNo();
    });
    if (focusFirst) {
      _noteTypeFocus.requestFocus();
    }
  }

  void _clearForm() {
    _resetForm();
    _showMessage('Cleared');
  }

  void _editSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to edit');
      return;
    }
    final row = creditDebitNotes[_selectedIndex!];
    setState(() {
      _editingId = row['id'] as int;
      _noteType = (row['type'] ?? 'Credit').toString();
      _noteNoController.text = (row['noteNo'] ?? '').toString();
      _dateController.text = (row['date'] ?? _today()).toString();
      _account = (row['account'] ?? _accounts.first).toString();
      _amountController.text = (row['amount'] ?? '').toString();
      _reasonController.text = (row['reason'] ?? '').toString();
      _paymentMode = (row['paymentMode'] ?? _paymentModes.first).toString();
      _referenceController.text = (row['reference'] ?? '').toString();
    });
    _noteTypeFocus.requestFocus();
  }

  void _deleteAtIndex(int index, {bool showMessage = true}) {
    if (index < 0 || index >= creditDebitNotes.length) {
      return;
    }
    final deletedId = creditDebitNotes[index]['id'];
    setState(() {
      creditDebitNotes.removeAt(index);
      if (_editingId == deletedId) {
        _editingId = null;
      }
      if (_selectedIndex == index) {
        _selectedIndex = null;
      } else if (_selectedIndex != null && _selectedIndex! > index) {
        _selectedIndex = _selectedIndex! - 1;
      }
    });
    if (showMessage) {
      _showMessage('Deleted');
    }
    if (_editingId == null) {
      _noteTypeFocus.requestFocus();
    }
  }

  void _deleteSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to delete');
      return;
    }
    _deleteAtIndex(_selectedIndex!);
  }

  void _save() {
    final amountText = _amountController.text.trim();
    final reason = _reasonController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      _showMessage('Amount must be a valid number');
      return;
    }
    if (reason.isEmpty) {
      _showMessage('Reason is required');
      return;
    }

    setState(() {
      if (_editingId != null) {
        final idx = creditDebitNotes.indexWhere((r) => r['id'] == _editingId);
        if (idx != -1) {
          creditDebitNotes[idx] = {
            ...creditDebitNotes[idx],
            'type': _noteType,
            'date': _dateController.text,
            'account': _account,
            'amount': amount.toStringAsFixed(2),
            'reason': reason,
            'paymentMode': _paymentMode,
            'reference': _referenceController.text.trim(),
          };
        }
      } else {
        final noteNo = _nextNoteNo(_noteType);
        if (_noteType == 'Credit') {
          _creditNoteNumberSeed++;
        } else {
          _debitNoteNumberSeed++;
        }
        creditDebitNotes.add({
          'id': _creditDebitNoteSeed++,
          'noteNo': noteNo,
          'type': _noteType,
          'date': _dateController.text,
          'account': _account,
          'amount': amount.toStringAsFixed(2),
          'reason': reason,
          'paymentMode': _paymentMode,
          'reference': _referenceController.text.trim(),
        });
      }
    });

    _resetForm();
    _showMessage('Saved Successfully');
  }

  void _previewRow(Map<String, dynamic> row) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'Credit / Debit Note Preview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _previewLine('Note Type', (row['type'] ?? '').toString()),
                _previewLine('Note No', (row['noteNo'] ?? '').toString()),
                _previewLine('Date', (row['date'] ?? '').toString()),
                _previewLine('Account', (row['account'] ?? '').toString()),
                _previewLine(
                  'Amount',
                  'Rs. ${(row['amount'] ?? '').toString()}',
                ),
                _previewLine('Reason', (row['reason'] ?? '').toString()),
                _previewLine(
                  'Payment Mode',
                  (row['paymentMode'] ?? '').toString(),
                ),
                _previewLine('Reference', (row['reference'] ?? '').toString()),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _previewLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }

  Widget _focusDropdown({
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
  }) {
    return SizedBox(
      height: 30,
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: (_, event) =>
            handleEnterToNext(context, nextFocusNode, event),
        child: DropdownButtonFormField<String>(
          value: values.contains(value) ? value : values.first,
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          style: const TextStyle(fontSize: 12.5, color: Colors.black87),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400, width: 0.8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400, width: 0.8),
            ),
          ),
          items: values
              .map(
                (item) =>
                    DropdownMenuItem<String>(value: item, child: Text(item)),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) {
              onChanged(v);
            }
          },
        ),
      ),
    );
  }

  Widget _readonlyInput(TextEditingController controller) {
    return SizedBox(
      height: 30,
      child: TextField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(fontSize: 12.5),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          filled: true,
          fillColor: const Color(0xFFF3F4F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 0.8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 0.8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _MasterCrudLayout(
      title: 'Credit / Debit Note',
      onClose: widget.onClose,
      formWidth: 500,
      formChild: _SectionCard(
        title: 'Note Details',
        child: Column(
          children: [
            _CompactFormRow(
              label: 'Note Type',
              field: _focusDropdown(
                value: _noteType,
                values: const ['Credit', 'Debit'],
                focusNode: _noteTypeFocus,
                nextFocusNode: _accountFocus,
                onChanged: (v) {
                  setState(() {
                    _noteType = v;
                    _refreshNoteNo();
                  });
                },
              ),
            ),
            _CompactFormRow(
              label: 'Note Number',
              field: _readonlyInput(_noteNoController),
            ),
            _CompactFormRow(
              label: 'Date',
              field: _readonlyInput(_dateController),
            ),
            _CompactFormRow(
              label: 'Account',
              field: _focusDropdown(
                value: _account,
                values: _accounts,
                focusNode: _accountFocus,
                nextFocusNode: _amountFocus,
                onChanged: (v) => setState(() => _account = v),
              ),
            ),
            _CompactFormRow(
              label: 'Amount',
              field: _compactInput(
                controller: _amountController,
                focusNode: _amountFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => nextFocus(context, _reasonFocus),
              ),
            ),
            _CompactFormRow(
              label: 'Reason',
              topAligned: true,
              field: _compactInput(
                controller: _reasonController,
                focusNode: _reasonFocus,
                maxLines: 2,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => nextFocus(context, _paymentModeFocus),
              ),
            ),
            _CompactFormRow(
              label: 'Payment Mode',
              field: _focusDropdown(
                value: _paymentMode,
                values: _paymentModes,
                focusNode: _paymentModeFocus,
                nextFocusNode: _referenceFocus,
                onChanged: (v) => setState(() => _paymentMode = v),
              ),
            ),
            _CompactFormRow(
              label: 'Reference No',
              field: _compactInput(
                controller: _referenceController,
                focusNode: _referenceFocus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
            ),
          ],
        ),
      ),
      tableChild: _SectionCard(
        title: 'Records',
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        expandChild: true,
        child: Column(
          children: [
            Container(
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFE8ECEB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: _TableHeaderText('Note No')),
                  Expanded(flex: 3, child: _TableHeaderText('Account Name')),
                  Expanded(flex: 2, child: _TableHeaderText('Type')),
                  Expanded(flex: 2, child: _TableHeaderText('Amount')),
                  Expanded(flex: 2, child: _TableHeaderText('Date')),
                  SizedBox(width: 74, child: _TableHeaderText('Actions')),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                itemCount: creditDebitNotes.length,
                itemBuilder: (context, index) {
                  final row = creditDebitNotes[index];
                  final selected = _selectedIndex == index;
                  final hovered = _hoveredIndex == index;
                  final isCredit = (row['type'] ?? 'Credit') == 'Credit';
                  return MouseRegion(
                    onEnter: (_) => setState(() => _hoveredIndex = index),
                    onExit: (_) => setState(() => _hoveredIndex = null),
                    child: InkWell(
                      onTap: () => setState(() => _selectedIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFDCEBFF)
                              : hovered
                              ? const Color(0xFFF4F7F6)
                              : Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _TableValueText(
                                (row['noteNo'] ?? '').toString(),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: _TableValueText(
                                (row['account'] ?? '').toString(),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCredit
                                        ? const Color(0xFFE4F6E8)
                                        : const Color(0xFFFBE5E5),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    (row['type'] ?? '').toString(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isCredit
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: _TableValueText(
                                'Rs. ${(row['amount'] ?? '').toString()}',
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: _TableValueText(
                                (row['date'] ?? '').toString(),
                              ),
                            ),
                            SizedBox(
                              width: 74,
                              child: Row(
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => _previewRow(row),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.visibility,
                                        size: 18,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => _deleteAtIndex(index),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      onEdit: _editSelected,
      onDelete: _deleteSelected,
      onSave: _save,
      onClear: _clearForm,
    );
  }
}

class OtherInputsRcmScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const OtherInputsRcmScreen({super.key, this.onClose});

  @override
  State<OtherInputsRcmScreen> createState() => _OtherInputsRcmScreenState();
}

class _OtherInputsRcmScreenState extends State<OtherInputsRcmScreen> {
  final _amountController = TextEditingController();
  final _taxController = TextEditingController(text: '0');
  final _entryNoController = TextEditingController();
  final _dateController = TextEditingController();

  final _entryTypeFocus = FocusNode();
  final _accountFocus = FocusNode();
  final _gstTypeFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _taxFocus = FocusNode();

  String _entryType = 'RCM';
  String _accountName = 'Aarav Pharma';
  String _gstType = 'CGST/SGST';

  int? _selectedIndex;
  int? _hoveredIndex;
  int? _editingId;
  double _total = 0;

  static const _entryTypes = ['RCM', 'Adjustment'];
  static const _accounts = [
    'Aarav Pharma',
    'MediCare Plus',
    'Krishna Clinic',
    'Health First',
  ];
  static const _gstTypes = ['CGST/SGST', 'IGST'];

  @override
  void initState() {
    super.initState();
    _entryNoController.text = _nextNo();
    _dateController.text = _today();
    _amountController.addListener(_recalculateTotal);
    _taxController.addListener(_recalculateTotal);
    _recalculateTotal();
  }

  @override
  void dispose() {
    _amountController.removeListener(_recalculateTotal);
    _taxController.removeListener(_recalculateTotal);
    _amountController.dispose();
    _taxController.dispose();
    _entryNoController.dispose();
    _dateController.dispose();
    _entryTypeFocus.dispose();
    _accountFocus.dispose();
    _gstTypeFocus.dispose();
    _amountFocus.dispose();
    _taxFocus.dispose();
    super.dispose();
  }

  String _today() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
  }

  String _nextNo() => 'RCM-$_otherInputsRcmSeed';

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _recalculateTotal() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final tax = double.tryParse(_taxController.text.trim()) ?? 0;
    final taxAmount = (amount * tax) / 100;
    setState(() {
      _total = amount + taxAmount;
    });
  }

  Widget _focusDropdown({
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
  }) {
    return SizedBox(
      height: 32,
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: (_, event) =>
            handleEnterToNext(context, nextFocusNode, event),
        child: DropdownButtonFormField<String>(
          value: values.contains(value) ? value : values.first,
          style: const TextStyle(fontSize: 12.5, color: Colors.black87),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: values
              .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _readonlyField(String value) {
    return SizedBox(
      height: 32,
      child: TextField(
        readOnly: true,
        controller: TextEditingController(text: value),
        style: const TextStyle(fontSize: 12.5),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          filled: true,
          fillColor: const Color(0xFFF1F3F4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  void _reset({bool focusFirst = true}) {
    setState(() {
      _entryType = _entryTypes.first;
      _accountName = _accounts.first;
      _gstType = _gstTypes.first;
      _amountController.clear();
      _taxController.text = '0';
      _total = 0;
      _editingId = null;
      _selectedIndex = null;
      _entryNoController.text = _nextNo();
      _dateController.text = _today();
    });
    if (focusFirst) _entryTypeFocus.requestFocus();
  }

  void _clear() {
    _reset();
    _showMessage('Cleared');
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.trim());
    final tax = double.tryParse(_taxController.text.trim());
    if (amount == null || amount <= 0) {
      _showMessage('Amount must be valid');
      return;
    }
    if (tax == null || tax < 0) {
      _showMessage('Tax % must be valid');
      return;
    }
    final record = {
      'id': _editingId ?? _otherInputsRcmSeed,
      'entryNo': _entryNoController.text,
      'entryType': _entryType,
      'account': _accountName,
      'gstType': _gstType,
      'amount': amount,
      'tax': tax,
      'total': _total,
      'date': _dateController.text,
    };

    setState(() {
      if (_editingId != null) {
        final idx = otherInputsRcmRecords.indexWhere(
          (r) => r['id'] == _editingId,
        );
        if (idx != -1) otherInputsRcmRecords[idx] = record;
      } else {
        otherInputsRcmRecords.add(record);
        _otherInputsRcmSeed++;
      }
    });
    _reset();
    _showMessage('Saved Successfully');
  }

  void _edit() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to edit');
      return;
    }
    final row = otherInputsRcmRecords[_selectedIndex!];
    setState(() {
      _editingId = row['id'] as int?;
      _entryNoController.text = (row['entryNo'] ?? '').toString();
      _dateController.text = (row['date'] ?? _today()).toString();
      _entryType = (row['entryType'] ?? _entryTypes.first).toString();
      _accountName = (row['account'] ?? _accounts.first).toString();
      _gstType = (row['gstType'] ?? _gstTypes.first).toString();
      _amountController.text = ((row['amount'] ?? 0) as num).toString();
      _taxController.text = ((row['tax'] ?? 0) as num).toString();
      _total = ((row['total'] ?? 0) as num).toDouble();
    });
    _entryTypeFocus.requestFocus();
  }

  void _delete() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to delete');
      return;
    }
    setState(() {
      otherInputsRcmRecords.removeAt(_selectedIndex!);
      _selectedIndex = null;
    });
    _showMessage('Deleted');
  }

  void _deleteRow(int index) {
    if (index < 0 || index >= otherInputsRcmRecords.length) return;
    setState(() {
      otherInputsRcmRecords.removeAt(index);
      if (_selectedIndex == index) {
        _selectedIndex = null;
      } else if (_selectedIndex != null && _selectedIndex! > index) {
        _selectedIndex = _selectedIndex! - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _MasterCrudLayout(
      title: 'Other Inputs (RCM)',
      onClose: widget.onClose,
      formWidth: 590,
      formChild: _SectionCard(
        title: 'Entry Form',
        child: Column(
          children: [
            _CompactFormRow(
              label: 'Entry Type',
              field: _focusDropdown(
                value: _entryType,
                values: _entryTypes,
                onChanged: (v) => setState(() => _entryType = v),
                focusNode: _entryTypeFocus,
                nextFocusNode: _accountFocus,
              ),
            ),
            _CompactFormRow(
              label: 'Account Name',
              field: _focusDropdown(
                value: _accountName,
                values: _accounts,
                onChanged: (v) => setState(() => _accountName = v),
                focusNode: _accountFocus,
                nextFocusNode: _gstTypeFocus,
              ),
            ),
            _CompactFormRow(
              label: 'GST Type',
              field: _focusDropdown(
                value: _gstType,
                values: _gstTypes,
                onChanged: (v) => setState(() => _gstType = v),
                focusNode: _gstTypeFocus,
                nextFocusNode: _amountFocus,
              ),
            ),
            _CompactFormRow(
              label: 'Amount',
              field: _compactInput(
                controller: _amountController,
                focusNode: _amountFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => nextFocus(context, _taxFocus),
              ),
            ),
            _CompactFormRow(
              label: 'Tax %',
              field: _compactInput(
                controller: _taxController,
                focusNode: _taxFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
            ),
            _CompactFormRow(
              label: 'Total',
              field: _readonlyField('Rs. ${_total.toStringAsFixed(2)}'),
            ),
            Row(
              children: [
                Expanded(
                  child: _CompactFormRow(
                    label: 'Entry No',
                    field: _readonlyField(_entryNoController.text),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CompactFormRow(
                    label: 'Date',
                    field: _readonlyField(_dateController.text),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      tableChild: _SectionCard(
        title: 'Records',
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        expandChild: true,
        child: Column(
          children: [
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE9EFEC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: _TableHeaderText('Account')),
                  Expanded(flex: 2, child: _TableHeaderText('Type')),
                  Expanded(flex: 2, child: _TableHeaderText('Amount')),
                  Expanded(flex: 2, child: _TableHeaderText('Tax %')),
                  Expanded(flex: 2, child: _TableHeaderText('Total')),
                  Expanded(flex: 2, child: _TableHeaderText('Date')),
                  SizedBox(width: 64, child: _TableHeaderText('Del')),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: otherInputsRcmRecords.isEmpty
                  ? Center(
                      child: Text(
                        'No records found',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.blueGrey.shade500,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: otherInputsRcmRecords.length,
                      itemBuilder: (context, index) {
                        final row = otherInputsRcmRecords[index];
                        final selected = _selectedIndex == index;
                        final hovered = _hoveredIndex == index;
                        return MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = index),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: InkWell(
                            onTap: () => setState(() => _selectedIndex = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              margin: const EdgeInsets.only(bottom: 5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFDCEBFF)
                                    : hovered
                                    ? const Color(0xFFF5FAF8)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _TableValueText(
                                      (row['account'] ?? '').toString(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _TableValueText(
                                      (row['entryType'] ?? '').toString(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _TableValueText(
                                      ((row['amount'] ?? 0) as num)
                                          .toStringAsFixed(2),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _TableValueText(
                                      ((row['tax'] ?? 0) as num)
                                          .toStringAsFixed(2),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _TableValueText(
                                      ((row['total'] ?? 0) as num)
                                          .toStringAsFixed(2),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _TableValueText(
                                      (row['date'] ?? '').toString(),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 64,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () => _deleteRow(index),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      onEdit: _edit,
      onDelete: _delete,
      onSave: _save,
      onClear: _clear,
    );
  }
}

class CashierScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const CashierScreen({super.key, this.onClose});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  final _openingController = TextEditingController(text: '0');
  final _cashInController = TextEditingController(text: '0');
  final _cashOutController = TextEditingController(text: '0');
  final _remarksController = TextEditingController();
  final _voucherController = TextEditingController();
  final _dateController = TextEditingController();

  final _openingFocus = FocusNode();
  final _cashInFocus = FocusNode();
  final _cashOutFocus = FocusNode();
  final _remarksFocus = FocusNode();

  int? _selectedIndex;
  int? _hoveredIndex;
  int? _editingId;
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    _voucherController.text = _nextNo();
    _dateController.text = _today();
    _openingController.addListener(_recalculateBalance);
    _cashInController.addListener(_recalculateBalance);
    _cashOutController.addListener(_recalculateBalance);
    _recalculateBalance();
  }

  @override
  void dispose() {
    _openingController.removeListener(_recalculateBalance);
    _cashInController.removeListener(_recalculateBalance);
    _cashOutController.removeListener(_recalculateBalance);
    _openingController.dispose();
    _cashInController.dispose();
    _cashOutController.dispose();
    _remarksController.dispose();
    _voucherController.dispose();
    _dateController.dispose();
    _openingFocus.dispose();
    _cashInFocus.dispose();
    _cashOutFocus.dispose();
    _remarksFocus.dispose();
    super.dispose();
  }

  String _today() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
  }

  String _nextNo() => 'CS-$_cashierSeed';

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _recalculateBalance() {
    final opening = double.tryParse(_openingController.text.trim()) ?? 0;
    final cashIn = double.tryParse(_cashInController.text.trim()) ?? 0;
    final cashOut = double.tryParse(_cashOutController.text.trim()) ?? 0;
    setState(() {
      _balance = opening + cashIn - cashOut;
    });
  }

  Widget _readonlyField(String value) {
    return SizedBox(
      height: 32,
      child: TextField(
        readOnly: true,
        controller: TextEditingController(text: value),
        style: const TextStyle(fontSize: 12.5),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          filled: true,
          fillColor: const Color(0xFFF1F3F4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  String _resolveType(double cashIn, double cashOut) {
    if (cashIn > 0 && cashOut > 0) return 'In/Out';
    if (cashIn > 0) return 'In';
    if (cashOut > 0) return 'Out';
    return 'In';
  }

  double _resolveAmount(double cashIn, double cashOut) {
    if (cashIn > 0 && cashOut > 0) return cashIn - cashOut;
    if (cashIn > 0) return cashIn;
    if (cashOut > 0) return cashOut;
    return 0;
  }

  void _reset({bool focusFirst = true}) {
    setState(() {
      _openingController.text = '0';
      _cashInController.text = '0';
      _cashOutController.text = '0';
      _remarksController.clear();
      _balance = 0;
      _editingId = null;
      _selectedIndex = null;
      _voucherController.text = _nextNo();
      _dateController.text = _today();
    });
    if (focusFirst) _openingFocus.requestFocus();
  }

  void _clear() {
    _reset();
    _showMessage('Cleared');
  }

  void _save() {
    final opening = double.tryParse(_openingController.text.trim());
    final cashIn = double.tryParse(_cashInController.text.trim());
    final cashOut = double.tryParse(_cashOutController.text.trim());
    if (opening == null || opening < 0) {
      _showMessage('Opening cash is invalid');
      return;
    }
    if (cashIn == null || cashIn < 0 || cashOut == null || cashOut < 0) {
      _showMessage('Cash in/out must be valid');
      return;
    }
    if (cashIn == 0 && cashOut == 0) {
      _showMessage('Enter Cash In or Cash Out');
      return;
    }

    final record = {
      'id': _editingId ?? _cashierSeed,
      'voucherNo': _voucherController.text,
      'date': _dateController.text,
      'opening': opening,
      'cashIn': cashIn,
      'cashOut': cashOut,
      'remarks': _remarksController.text.trim(),
      'type': _resolveType(cashIn, cashOut),
      'amount': _resolveAmount(cashIn, cashOut).abs(),
      'balance': _balance,
    };

    setState(() {
      if (_editingId != null) {
        final idx = cashierRecords.indexWhere((r) => r['id'] == _editingId);
        if (idx != -1) cashierRecords[idx] = record;
      } else {
        cashierRecords.add(record);
        _cashierSeed++;
      }
    });
    _reset();
    _showMessage('Saved Successfully');
  }

  void _edit() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to edit');
      return;
    }
    final row = cashierRecords[_selectedIndex!];
    setState(() {
      _editingId = row['id'] as int?;
      _voucherController.text = (row['voucherNo'] ?? '').toString();
      _dateController.text = (row['date'] ?? _today()).toString();
      _openingController.text = ((row['opening'] ?? 0) as num).toString();
      _cashInController.text = ((row['cashIn'] ?? 0) as num).toString();
      _cashOutController.text = ((row['cashOut'] ?? 0) as num).toString();
      _remarksController.text = (row['remarks'] ?? '').toString();
      _balance = ((row['balance'] ?? 0) as num).toDouble();
    });
    _openingFocus.requestFocus();
  }

  void _delete() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to delete');
      return;
    }
    setState(() {
      cashierRecords.removeAt(_selectedIndex!);
      _selectedIndex = null;
    });
    _showMessage('Deleted');
  }

  void _deleteRow(int index) {
    if (index < 0 || index >= cashierRecords.length) return;
    setState(() {
      cashierRecords.removeAt(index);
      if (_selectedIndex == index) {
        _selectedIndex = null;
      } else if (_selectedIndex != null && _selectedIndex! > index) {
        _selectedIndex = _selectedIndex! - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final balancePositive = _balance >= 0;
    return _MasterCrudLayout(
      title: 'Cashier',
      onClose: widget.onClose,
      formWidth: 590,
      formChild: _SectionCard(
        title: 'Cash Counter',
        child: Column(
          children: [
            _CompactFormRow(
              label: 'Opening Cash',
              field: _compactInput(
                controller: _openingController,
                focusNode: _openingFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => nextFocus(context, _cashInFocus),
              ),
            ),
            _CompactFormRow(
              label: 'Cash In',
              field: _compactInput(
                controller: _cashInController,
                focusNode: _cashInFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => nextFocus(context, _cashOutFocus),
              ),
            ),
            _CompactFormRow(
              label: 'Cash Out',
              field: _compactInput(
                controller: _cashOutController,
                focusNode: _cashOutFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => nextFocus(context, _remarksFocus),
              ),
            ),
            _CompactFormRow(
              label: 'Remarks',
              field: _compactInput(
                controller: _remarksController,
                focusNode: _remarksFocus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _CompactFormRow(
                    label: 'Voucher No',
                    field: _readonlyField(_voucherController.text),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CompactFormRow(
                    label: 'Date',
                    field: _readonlyField(_dateController.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: balancePositive
                    ? const Color(0xFFE6F5EA)
                    : const Color(0xFFFDE9E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: balancePositive
                      ? Colors.green.shade300
                      : Colors.red.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    balancePositive ? Icons.trending_up : Icons.trending_down,
                    size: 18,
                    color: balancePositive
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Running Balance: Rs. ${_balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: balancePositive
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      tableChild: _SectionCard(
        title: 'Cashier Entries',
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        expandChild: true,
        child: Column(
          children: [
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE9EFEC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: _TableHeaderText('Type')),
                  Expanded(flex: 2, child: _TableHeaderText('Amount')),
                  Expanded(flex: 2, child: _TableHeaderText('Balance')),
                  Expanded(flex: 2, child: _TableHeaderText('Date')),
                  Expanded(flex: 3, child: _TableHeaderText('Remarks')),
                  SizedBox(width: 64, child: _TableHeaderText('Del')),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: cashierRecords.isEmpty
                  ? Center(
                      child: Text(
                        'No cashier entries',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.blueGrey.shade500,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: cashierRecords.length,
                      itemBuilder: (context, index) {
                        final row = cashierRecords[index];
                        final selected = _selectedIndex == index;
                        final hovered = _hoveredIndex == index;
                        final balance = ((row['balance'] ?? 0) as num)
                            .toDouble();
                        final balancePositive = balance >= 0;
                        return MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = index),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: InkWell(
                            onTap: () => setState(() => _selectedIndex = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              margin: const EdgeInsets.only(bottom: 5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFDCEBFF)
                                    : hovered
                                    ? const Color(0xFFF5FAF8)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _TableValueText(
                                      (row['type'] ?? '').toString(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _TableValueText(
                                      ((row['amount'] ?? 0) as num)
                                          .toStringAsFixed(2),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      balance.toStringAsFixed(2),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: balancePositive
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _TableValueText(
                                      (row['date'] ?? '').toString(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: _TableValueText(
                                      (row['remarks'] ?? '').toString(),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 64,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () => _deleteRow(index),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      onEdit: _edit,
      onDelete: _delete,
      onSave: _save,
      onClear: _clear,
    );
  }
}

class ShortageNotifierScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const ShortageNotifierScreen({super.key, this.onClose});

  @override
  State<ShortageNotifierScreen> createState() => _ShortageNotifierScreenState();
}

class _ShortageNotifierScreenState extends State<ShortageNotifierScreen> {
  final _stockController = TextEditingController();
  final _minController = TextEditingController();
  final _entryNoController = TextEditingController();

  final _productFocus = FocusNode();
  final _stockFocus = FocusNode();
  final _minFocus = FocusNode();

  String _product = 'Paracetamol 650';
  int? _selectedIndex;
  int? _hoveredIndex;
  int? _editingId;

  static const _products = [
    'Paracetamol 650',
    'Azithromycin 500',
    'ORS Sachet',
    'Vitamin C',
    'Dolo 650',
  ];

  @override
  void initState() {
    super.initState();
    _entryNoController.text = _nextNo();
  }

  @override
  void dispose() {
    _stockController.dispose();
    _minController.dispose();
    _entryNoController.dispose();
    _productFocus.dispose();
    _stockFocus.dispose();
    _minFocus.dispose();
    super.dispose();
  }

  String _nextNo() => 'SN-$_shortageNotifierSeed';

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Widget _focusDropdown({
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
  }) {
    return SizedBox(
      height: 32,
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: (_, event) =>
            handleEnterToNext(context, nextFocusNode, event),
        child: DropdownButtonFormField<String>(
          value: values.contains(value) ? value : values.first,
          style: const TextStyle(fontSize: 12.5, color: Colors.black87),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: values
              .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  String _statusFor(int stock, int min) => stock < min ? 'LOW' : 'OK';

  void _reset({bool focusFirst = true}) {
    setState(() {
      _product = _products.first;
      _stockController.clear();
      _minController.clear();
      _editingId = null;
      _selectedIndex = null;
      _entryNoController.text = _nextNo();
    });
    if (focusFirst) _productFocus.requestFocus();
  }

  void _clear() {
    _reset();
    _showMessage('Cleared');
  }

  void _save() {
    final stock = int.tryParse(_stockController.text.trim());
    final min = int.tryParse(_minController.text.trim());
    if (stock == null || stock < 0 || min == null || min < 0) {
      _showMessage('Stock and Min qty must be valid');
      return;
    }
    final record = {
      'id': _editingId ?? _shortageNotifierSeed,
      'entryNo': _entryNoController.text,
      'product': _product,
      'stock': stock,
      'minQty': min,
      'status': _statusFor(stock, min),
    };

    setState(() {
      if (_editingId != null) {
        final idx = shortageNotifierRecords.indexWhere(
          (r) => r['id'] == _editingId,
        );
        if (idx != -1) shortageNotifierRecords[idx] = record;
      } else {
        shortageNotifierRecords.add(record);
        _shortageNotifierSeed++;
      }
    });
    _reset();
    _showMessage('Saved Successfully');
  }

  void _edit() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to edit');
      return;
    }
    final row = shortageNotifierRecords[_selectedIndex!];
    setState(() {
      _editingId = row['id'] as int?;
      _entryNoController.text = (row['entryNo'] ?? '').toString();
      _product = (row['product'] ?? _products.first).toString();
      _stockController.text = (row['stock'] ?? '').toString();
      _minController.text = (row['minQty'] ?? '').toString();
    });
    _productFocus.requestFocus();
  }

  void _delete() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to delete');
      return;
    }
    setState(() {
      shortageNotifierRecords.removeAt(_selectedIndex!);
      _selectedIndex = null;
    });
    _showMessage('Deleted');
  }

  void _deleteRow(int index) {
    if (index < 0 || index >= shortageNotifierRecords.length) return;
    setState(() {
      shortageNotifierRecords.removeAt(index);
      if (_selectedIndex == index) {
        _selectedIndex = null;
      } else if (_selectedIndex != null && _selectedIndex! > index) {
        _selectedIndex = _selectedIndex! - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _MasterCrudLayout(
      title: 'Shortage Notifier',
      onClose: widget.onClose,
      formWidth: 590,
      formChild: _SectionCard(
        title: 'Stock Threshold',
        child: Column(
          children: [
            _CompactFormRow(
              label: 'Product',
              field: _focusDropdown(
                value: _product,
                values: _products,
                onChanged: (v) => setState(() => _product = v),
                focusNode: _productFocus,
                nextFocusNode: _stockFocus,
              ),
            ),
            _CompactFormRow(
              label: 'Current Stock',
              field: _compactInput(
                controller: _stockController,
                focusNode: _stockFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => nextFocus(context, _minFocus),
              ),
            ),
            _CompactFormRow(
              label: 'Minimum Qty',
              field: _compactInput(
                controller: _minController,
                focusNode: _minFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
            ),
            _CompactFormRow(
              label: 'Entry No',
              field: _readonlyField(_entryNoController.text),
            ),
          ],
        ),
      ),
      tableChild: _SectionCard(
        title: 'Notifier Table',
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        expandChild: true,
        child: Column(
          children: [
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE9EFEC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: _TableHeaderText('Product')),
                  Expanded(flex: 2, child: _TableHeaderText('Stock')),
                  Expanded(flex: 2, child: _TableHeaderText('Min Qty')),
                  Expanded(flex: 2, child: _TableHeaderText('Status')),
                  SizedBox(width: 64, child: _TableHeaderText('Del')),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: shortageNotifierRecords.isEmpty
                  ? Center(
                      child: Text(
                        'No shortage records',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.blueGrey.shade500,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: shortageNotifierRecords.length,
                      itemBuilder: (context, index) {
                        final row = shortageNotifierRecords[index];
                        final selected = _selectedIndex == index;
                        final hovered = _hoveredIndex == index;
                        final status = (row['status'] ?? 'OK').toString();
                        final low = status == 'LOW';
                        return MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = index),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: InkWell(
                            onTap: () => setState(() => _selectedIndex = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              margin: const EdgeInsets.only(bottom: 5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFDCEBFF)
                                    : hovered
                                    ? const Color(0xFFF5FAF8)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _TableValueText(
                                      (row['product'] ?? '').toString(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _TableValueText(
                                      (row['stock'] ?? '').toString(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _TableValueText(
                                      (row['minQty'] ?? '').toString(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: low
                                              ? const Color(0xFFFBE5E5)
                                              : const Color(0xFFE4F6E8),
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: low
                                                ? Colors.red.shade700
                                                : Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 64,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () => _deleteRow(index),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      onEdit: _edit,
      onDelete: _delete,
      onSave: _save,
      onClear: _clear,
    );
  }

  Widget _readonlyField(String value) {
    return SizedBox(
      height: 32,
      child: TextField(
        readOnly: true,
        controller: TextEditingController(text: value),
        style: const TextStyle(fontSize: 12.5),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          filled: true,
          fillColor: const Color(0xFFF1F3F4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _TableHeaderText extends StatelessWidget {
  final String text;
  const _TableHeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TableValueText extends StatelessWidget {
  final String text;
  const _TableValueText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final EdgeInsets contentPadding;
  final bool expandChild;

  const _SectionCard({
    required this.title,
    required this.child,
    this.contentPadding = const EdgeInsets.fromLTRB(12, 10, 12, 12),
    this.expandChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.8,
      shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.10),
      color: const Color(0xFFFEFEFF),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: contentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            if (expandChild) Flexible(child: child) else child,
          ],
        ),
      ),
    );
  }
}

class _MasterCrudLayout extends StatelessWidget {
  final String title;
  final VoidCallback? onClose;
  final Widget formChild;
  final Widget tableChild;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final double formWidth;

  const _MasterCrudLayout({
    required this.title,
    this.onClose,
    required this.formChild,
    required this.tableChild,
    required this.onEdit,
    required this.onDelete,
    required this.onSave,
    required this.onClear,
    this.formWidth = 420,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            height: 32,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF0EA5E9)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3730A3).withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30 / 2.2,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (onClose != null)
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(3),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Icon(Icons.close, color: Colors.white70, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const rightWidth = 150.0;
                final left = formWidth.clamp(
                  360.0,
                  constraints.maxWidth - rightWidth - 16,
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: left,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
                              child: formChild,
                            ),
                          ),
                          Container(
                            height: 170,
                            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                            child: tableChild,
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: const _MasterCenterPlaceholder()),
                    SizedBox(
                      width: rightWidth,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 12, 16, 10),
                        child: _SectionCard(
                          title: 'Actions',
                          contentPadding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              MasterActionButton(
                                label: 'Edit',
                                icon: Icons.edit,
                                accentColor: Colors.grey.shade700,
                                onPressed: onEdit,
                              ),
                              const SizedBox(height: 8),
                              MasterActionButton(
                                label: 'Delete',
                                icon: Icons.delete_outline,
                                accentColor: Colors.red.shade600,
                                onPressed: onDelete,
                              ),
                              const SizedBox(height: 8),
                              MasterActionButton(
                                label: 'Save',
                                icon: Icons.save,
                                accentColor: Colors.green.shade700,
                                onPressed: onSave,
                              ),
                              const SizedBox(height: 8),
                              MasterActionButton(
                                label: 'Clear',
                                icon: Icons.cleaning_services,
                                accentColor: Colors.blueGrey.shade600,
                                onPressed: onClear,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MasterCenterPlaceholder extends StatelessWidget {
  const _MasterCenterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      alignment: Alignment.center,
      child: Opacity(
        opacity: 0.09,
        child: Icon(
          Icons.medication_rounded,
          size: 320,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _CompactFormRow extends StatelessWidget {
  final String label;
  final Widget field;
  final bool topAligned;

  const _CompactFormRow({
    required this.label,
    required this.field,
    this.topAligned = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: topAligned
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 118,
            child: Padding(
              padding: EdgeInsets.only(top: topAligned ? 6 : 0),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: field),
        ],
      ),
    );
  }
}

Widget _compactInput({
  required TextEditingController controller,
  String? hintText,
  int maxLines = 1,
  bool obscureText = false,
  TextInputType keyboardType = TextInputType.text,
  FocusNode? focusNode,
  TextInputAction? textInputAction,
  ValueChanged<String>? onSubmitted,
}) {
  final multiline = maxLines > 1;
  return SizedBox(
    height: multiline ? 58 : 34,
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.6),
        ),
      ),
    ),
  );
}

Widget _compactDropdown({
  required String value,
  required List<String> values,
  required ValueChanged<String> onChanged,
}) {
  final selected = values.contains(value)
      ? value
      : (values.isEmpty ? '' : values.first);
  return SizedBox(
    height: 34,
    child: DropdownButtonFormField<String>(
      value: selected.isEmpty ? null : selected,
      icon: const Icon(Icons.arrow_drop_down, size: 18),
      style: const TextStyle(fontSize: 12.5, color: Colors.black87),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Color(0xFF6366F1), width: 1.6),
        ),
      ),
      items: values
          .map(
            (item) => DropdownMenuItem<String>(value: item, child: Text(item)),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) {
          onChanged(v);
        }
      },
    ),
  );
}

class _SimpleTable extends StatefulWidget {
  final List<String> headers;
  final List<List<String>> rows;
  final int? selectedIndex;
  final ValueChanged<int> onRowTap;

  const _SimpleTable({
    required this.headers,
    required this.rows,
    required this.selectedIndex,
    required this.onRowTap,
  });

  @override
  State<_SimpleTable> createState() => _SimpleTableState();
}

class _SimpleTableState extends State<_SimpleTable> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';
  int? _hoveredIndex;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isStatusCell(String text) {
    final v = text.toLowerCase();
    return v == 'success' ||
        v == 'paid' ||
        v == 'danger' ||
        v == 'failed' ||
        v == 'pending' ||
        v == 'partial';
  }

  bool _statusMatches(List<String> row) {
    if (_statusFilter == 'All') return true;
    final statusCells = row
        .where(_isStatusCell)
        .map((e) => e.toLowerCase())
        .toList();
    if (statusCells.isEmpty) return true;
    if (_statusFilter == 'Success') {
      return statusCells.any((x) => x == 'success' || x == 'paid');
    }
    if (_statusFilter == 'Danger') {
      return statusCells.any((x) => x == 'danger' || x == 'failed');
    }
    return statusCells.any((x) => x == 'pending' || x == 'partial');
  }

  List<int> _filteredRowIndexes() {
    final query = _searchController.text.trim().toLowerCase();
    final indexes = <int>[];
    for (int i = 0; i < widget.rows.length; i++) {
      final row = widget.rows[i];
      final textMatch =
          query.isEmpty ||
          row.any((cell) => cell.toLowerCase().contains(query));
      if (textMatch && _statusMatches(row)) {
        indexes.add(i);
      }
    }
    return indexes;
  }

  @override
  Widget build(BuildContext context) {
    final filteredIndexes = _filteredRowIndexes();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFF),
        border: Border.all(color: const Color(0xFFD7DEEA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const controlsHeight = 36.0;
          const headerHeight = 32.0;
          final listHeight = constraints.maxHeight.isFinite
              ? (constraints.maxHeight - controlsHeight - headerHeight).clamp(
                  0.0,
                  double.infinity,
                )
              : 230.0;
          return Column(
            children: [
              Container(
                height: controlsHeight,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6FB),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.blueGrey.shade100),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 26,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, size: 16),
                            hintText: 'Search records',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.blueGrey.shade100,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.blueGrey.shade100,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 120,
                      height: 26,
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        isDense: true,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.blueGrey.shade100,
                            ),
                          ),
                        ),
                        items: const ['All', 'Success', 'Pending', 'Danger']
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _statusFilter = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: headerHeight,
                color: const Color(0xFFE8EDF7),
                child: Row(
                  children: widget.headers
                      .map((h) => _SimpleTableHeaderCell(text: h, flex: 1))
                      .toList(),
                ),
              ),
              SizedBox(
                height: listHeight,
                child: ListView.builder(
                  itemCount: filteredIndexes.length,
                  itemBuilder: (context, index) {
                    final actualIndex = filteredIndexes[index];
                    final row = widget.rows[actualIndex];
                    final selected = widget.selectedIndex == actualIndex;
                    final hovered = _hoveredIndex == actualIndex;
                    final baseColor = index.isEven
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFFF8FAFC);
                    return MouseRegion(
                      onEnter: (_) =>
                          setState(() => _hoveredIndex = actualIndex),
                      onExit: (_) => setState(() => _hoveredIndex = null),
                      child: InkWell(
                        onTap: () => widget.onRowTap(actualIndex),
                        child: Container(
                          height: 28,
                          color: selected
                              ? const Color(0xFFDDE8FF)
                              : hovered
                              ? const Color(0xFFEFF6FF)
                              : baseColor,
                          child: Row(
                            children: row
                                .map(
                                  (v) =>
                                      _SimpleTableValueCell(text: v, flex: 1),
                                )
                                .toList(),
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
}

class _SimpleTableHeaderCell extends StatelessWidget {
  final String text;
  final int flex;

  const _SimpleTableHeaderCell({required this.text, required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.blueGrey.shade200)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}

class PatientMasterScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const PatientMasterScreen({super.key, this.onClose});

  @override
  State<PatientMasterScreen> createState() => _PatientMasterScreenState();
}

class _PatientMasterScreenState extends State<PatientMasterScreen> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();

  final _nameFocus = FocusNode();
  final _mobileFocus = FocusNode();
  final _addressFocus = FocusNode();

  int? _selectedIndex;
  int? _editingId;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _nameFocus.dispose();
    _mobileFocus.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _resetForm({bool focusFirst = true}) {
    setState(() {
      _nameController.clear();
      _mobileController.clear();
      _addressController.clear();
      _selectedIndex = null;
      _editingId = null;
    });
    if (focusFirst) {
      _nameFocus.requestFocus();
    }
  }

  void _clearForm() {
    _resetForm();
    _showMessage('Cleared');
  }

  void _editSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to edit');
      return;
    }
    final row = patients[_selectedIndex!];
    setState(() {
      _editingId = row['id'] as int;
      _nameController.text = (row['name'] ?? '').toString();
      _mobileController.text = (row['mobile'] ?? '').toString();
      _addressController.text = (row['address'] ?? '').toString();
    });
    _nameFocus.requestFocus();
  }

  void _deleteSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to delete');
      return;
    }
    final id = patients[_selectedIndex!]['id'];
    setState(() {
      patients.removeWhere((row) => row['id'] == id);
      _selectedIndex = null;
      _editingId = null;
    });
    _nameController.clear();
    _mobileController.clear();
    _addressController.clear();
    _nameFocus.requestFocus();
    _showMessage('Deleted');
  }

  void _save() {
    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      _showMessage('Patient Name is required');
      return;
    }
    if (mobile.isNotEmpty && double.tryParse(mobile) == null) {
      _showMessage('Mobile must be numeric');
      return;
    }

    setState(() {
      if (_editingId != null) {
        final index = patients.indexWhere((row) => row['id'] == _editingId);
        if (index != -1) {
          patients[index] = {
            ...patients[index],
            'name': name,
            'mobile': mobile,
            'address': address,
          };
        }
      } else {
        patients.add({
          'id': _patientSeed++,
          'name': name,
          'mobile': mobile,
          'address': address,
        });
      }
    });

    _resetForm();
    _showMessage('Saved Successfully');
  }

  @override
  Widget build(BuildContext context) {
    return _MasterCrudLayout(
      title: 'Patient Master',
      onClose: widget.onClose,
      formWidth: 470,
      formChild: _SectionCard(
        title: 'Patient Details',
        child: Column(
          children: [
            _CompactFormRow(
              label: 'Patient Name',
              field: _compactInput(
                controller: _nameController,
                focusNode: _nameFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => nextFocus(context, _mobileFocus),
              ),
            ),
            _CompactFormRow(
              label: 'Mobile',
              field: _compactInput(
                controller: _mobileController,
                focusNode: _mobileFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => nextFocus(context, _addressFocus),
              ),
            ),
            _CompactFormRow(
              label: 'Address',
              field: _compactInput(
                controller: _addressController,
                focusNode: _addressFocus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
            ),
          ],
        ),
      ),
      tableChild: _SectionCard(
        title: 'Records',
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        expandChild: true,
        child: _SimpleTable(
          headers: const ['Name', 'Mobile', 'Address'],
          selectedIndex: _selectedIndex,
          rows: patients
              .map(
                (row) => [
                  (row['name'] ?? '').toString(),
                  (row['mobile'] ?? '').toString(),
                  (row['address'] ?? '').toString(),
                ],
              )
              .toList(),
          onRowTap: (index) => setState(() => _selectedIndex = index),
        ),
      ),
      onEdit: _editSelected,
      onDelete: _deleteSelected,
      onSave: _save,
      onClear: _clearForm,
    );
  }
}

class StockPointScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const StockPointScreen({super.key, this.onClose});

  @override
  State<StockPointScreen> createState() => _StockPointScreenState();
}

class _StockPointScreenState extends State<StockPointScreen> {
  final _stockNameController = TextEditingController();
  final _locationController = TextEditingController();

  final _stockNameFocus = FocusNode();
  final _locationFocus = FocusNode();

  int? _selectedIndex;
  int? _editingId;

  @override
  void dispose() {
    _stockNameController.dispose();
    _locationController.dispose();
    _stockNameFocus.dispose();
    _locationFocus.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _resetForm({bool focusFirst = true}) {
    setState(() {
      _stockNameController.clear();
      _locationController.clear();
      _selectedIndex = null;
      _editingId = null;
    });
    if (focusFirst) {
      _stockNameFocus.requestFocus();
    }
  }

  void _clearForm() {
    _resetForm();
    _showMessage('Cleared');
  }

  void _editSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to edit');
      return;
    }
    final row = stockPoints[_selectedIndex!];
    setState(() {
      _editingId = row['id'] as int;
      _stockNameController.text = (row['stockName'] ?? '').toString();
      _locationController.text = (row['location'] ?? '').toString();
    });
    _stockNameFocus.requestFocus();
  }

  void _deleteSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to delete');
      return;
    }
    final id = stockPoints[_selectedIndex!]['id'];
    setState(() {
      stockPoints.removeWhere((row) => row['id'] == id);
      _selectedIndex = null;
      _editingId = null;
    });
    _stockNameController.clear();
    _locationController.clear();
    _stockNameFocus.requestFocus();
    _showMessage('Deleted');
  }

  void _save() {
    final stockName = _stockNameController.text.trim();
    final location = _locationController.text.trim();

    if (stockName.isEmpty) {
      _showMessage('Stock Name is required');
      return;
    }

    setState(() {
      if (_editingId != null) {
        final index = stockPoints.indexWhere((row) => row['id'] == _editingId);
        if (index != -1) {
          stockPoints[index] = {
            ...stockPoints[index],
            'stockName': stockName,
            'location': location,
          };
        }
      } else {
        stockPoints.add({
          'id': _stockPointSeed++,
          'stockName': stockName,
          'location': location,
        });
      }
    });

    _resetForm();
    _showMessage('Saved Successfully');
  }

  @override
  Widget build(BuildContext context) {
    return _MasterCrudLayout(
      title: 'Stock Point',
      onClose: widget.onClose,
      formWidth: 470,
      formChild: _SectionCard(
        title: 'Stock Point Details',
        child: Column(
          children: [
            _CompactFormRow(
              label: 'Stock Name',
              field: _compactInput(
                controller: _stockNameController,
                focusNode: _stockNameFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => nextFocus(context, _locationFocus),
              ),
            ),
            _CompactFormRow(
              label: 'Location',
              field: _compactInput(
                controller: _locationController,
                focusNode: _locationFocus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
            ),
          ],
        ),
      ),
      tableChild: _SectionCard(
        title: 'Records',
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        expandChild: true,
        child: _SimpleTable(
          headers: const ['Stock Name', 'Location'],
          selectedIndex: _selectedIndex,
          rows: stockPoints
              .map(
                (row) => [
                  (row['stockName'] ?? '').toString(),
                  (row['location'] ?? '').toString(),
                ],
              )
              .toList(),
          onRowTap: (index) => setState(() => _selectedIndex = index),
        ),
      ),
      onEdit: _editSelected,
      onDelete: _deleteSelected,
      onSave: _save,
      onClear: _clearForm,
    );
  }
}

class PreFormatesScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const PreFormatesScreen({super.key, this.onClose});

  @override
  State<PreFormatesScreen> createState() => _PreFormatesScreenState();
}

class _PreFormatesScreenState extends State<PreFormatesScreen> {
  final _formatNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _formatNameFocus = FocusNode();
  final _descriptionFocus = FocusNode();

  int? _selectedIndex;
  int? _editingId;

  @override
  void dispose() {
    _formatNameController.dispose();
    _descriptionController.dispose();
    _formatNameFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _resetForm({bool focusFirst = true}) {
    setState(() {
      _formatNameController.clear();
      _descriptionController.clear();
      _selectedIndex = null;
      _editingId = null;
    });
    if (focusFirst) {
      _formatNameFocus.requestFocus();
    }
  }

  void _clearForm() {
    _resetForm();
    _showMessage('Cleared');
  }

  void _editSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to edit');
      return;
    }
    final row = preFormates[_selectedIndex!];
    setState(() {
      _editingId = row['id'] as int;
      _formatNameController.text = (row['formatName'] ?? '').toString();
      _descriptionController.text = (row['description'] ?? '').toString();
    });
    _formatNameFocus.requestFocus();
  }

  void _deleteSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to delete');
      return;
    }
    final id = preFormates[_selectedIndex!]['id'];
    setState(() {
      preFormates.removeWhere((row) => row['id'] == id);
      _selectedIndex = null;
      _editingId = null;
    });
    _formatNameController.clear();
    _descriptionController.clear();
    _formatNameFocus.requestFocus();
    _showMessage('Deleted');
  }

  void _save() {
    final formatName = _formatNameController.text.trim();
    final description = _descriptionController.text.trim();

    if (formatName.isEmpty) {
      _showMessage('Format Name is required');
      return;
    }

    setState(() {
      if (_editingId != null) {
        final index = preFormates.indexWhere((row) => row['id'] == _editingId);
        if (index != -1) {
          preFormates[index] = {
            ...preFormates[index],
            'formatName': formatName,
            'description': description,
          };
        }
      } else {
        preFormates.add({
          'id': _preFormateSeed++,
          'formatName': formatName,
          'description': description,
        });
      }
    });

    _resetForm();
    _showMessage('Saved Successfully');
  }

  @override
  Widget build(BuildContext context) {
    return _MasterCrudLayout(
      title: 'Pre-formates',
      onClose: widget.onClose,
      formWidth: 470,
      formChild: _SectionCard(
        title: 'Pre-formate Details',
        child: Column(
          children: [
            _CompactFormRow(
              label: 'Format Name',
              field: _compactInput(
                controller: _formatNameController,
                focusNode: _formatNameFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => nextFocus(context, _descriptionFocus),
              ),
            ),
            _CompactFormRow(
              label: 'Description',
              field: _compactInput(
                controller: _descriptionController,
                focusNode: _descriptionFocus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
            ),
          ],
        ),
      ),
      tableChild: _SectionCard(
        title: 'Records',
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        expandChild: true,
        child: _SimpleTable(
          headers: const ['Format Name', 'Description'],
          selectedIndex: _selectedIndex,
          rows: preFormates
              .map(
                (row) => [
                  (row['formatName'] ?? '').toString(),
                  (row['description'] ?? '').toString(),
                ],
              )
              .toList(),
          onRowTap: (index) => setState(() => _selectedIndex = index),
        ),
      ),
      onEdit: _editSelected,
      onDelete: _deleteSelected,
      onSave: _save,
      onClear: _clearForm,
    );
  }
}

class HappyHoursScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const HappyHoursScreen({super.key, this.onClose});

  @override
  State<HappyHoursScreen> createState() => _HappyHoursScreenState();
}

class _HappyHoursScreenState extends State<HappyHoursScreen> {
  final _offerNameController = TextEditingController();
  final _discountController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();

  final _offerNameFocus = FocusNode();
  final _discountFocus = FocusNode();
  final _startTimeFocus = FocusNode();
  final _endTimeFocus = FocusNode();

  int? _selectedIndex;
  int? _editingId;

  @override
  void dispose() {
    _offerNameController.dispose();
    _discountController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _offerNameFocus.dispose();
    _discountFocus.dispose();
    _startTimeFocus.dispose();
    _endTimeFocus.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _resetForm({bool focusFirst = true}) {
    setState(() {
      _offerNameController.clear();
      _discountController.clear();
      _startTimeController.clear();
      _endTimeController.clear();
      _selectedIndex = null;
      _editingId = null;
    });
    if (focusFirst) {
      _offerNameFocus.requestFocus();
    }
  }

  void _clearForm() {
    _resetForm();
    _showMessage('Cleared');
  }

  void _editSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to edit');
      return;
    }
    final row = happyHours[_selectedIndex!];
    setState(() {
      _editingId = row['id'] as int;
      _offerNameController.text = (row['offer'] ?? '').toString();
      _discountController.text = (row['discount'] ?? '').toString();
      _startTimeController.text = (row['start'] ?? '').toString();
      _endTimeController.text = (row['end'] ?? '').toString();
    });
    _offerNameFocus.requestFocus();
  }

  void _deleteSelected() {
    if (_selectedIndex == null) {
      _showMessage('Select a row to delete');
      return;
    }
    final id = happyHours[_selectedIndex!]['id'];
    setState(() {
      happyHours.removeWhere((row) => row['id'] == id);
      _selectedIndex = null;
      _editingId = null;
    });
    _offerNameController.clear();
    _discountController.clear();
    _startTimeController.clear();
    _endTimeController.clear();
    _offerNameFocus.requestFocus();
    _showMessage('Deleted');
  }

  void _save() {
    final offer = _offerNameController.text.trim();
    final discountText = _discountController.text.trim();
    final start = _startTimeController.text.trim();
    final end = _endTimeController.text.trim();

    if (offer.isEmpty) {
      _showMessage('Offer Name is required');
      return;
    }
    final discount = double.tryParse(discountText);
    if (discount == null) {
      _showMessage('Discount % must be numeric');
      return;
    }
    if (start.isEmpty || end.isEmpty) {
      _showMessage('Start and End Time are required');
      return;
    }

    setState(() {
      if (_editingId != null) {
        final index = happyHours.indexWhere((row) => row['id'] == _editingId);
        if (index != -1) {
          happyHours[index] = {
            ...happyHours[index],
            'offer': offer,
            'discount': discount.toStringAsFixed(2),
            'start': start,
            'end': end,
          };
        }
      } else {
        happyHours.add({
          'id': _happyHourSeed++,
          'offer': offer,
          'discount': discount.toStringAsFixed(2),
          'start': start,
          'end': end,
        });
      }
    });

    _resetForm();
    _showMessage('Saved Successfully');
  }

  @override
  Widget build(BuildContext context) {
    return _MasterCrudLayout(
      title: 'Happy Hours',
      onClose: widget.onClose,
      formWidth: 470,
      formChild: _SectionCard(
        title: 'Happy Hours Details',
        child: Column(
          children: [
            _CompactFormRow(
              label: 'Offer Name',
              field: _compactInput(
                controller: _offerNameController,
                focusNode: _offerNameFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => nextFocus(context, _discountFocus),
              ),
            ),
            _CompactFormRow(
              label: 'Discount %',
              field: _compactInput(
                controller: _discountController,
                focusNode: _discountFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => nextFocus(context, _startTimeFocus),
              ),
            ),
            _CompactFormRow(
              label: 'Start Time',
              field: _compactInput(
                controller: _startTimeController,
                focusNode: _startTimeFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => nextFocus(context, _endTimeFocus),
              ),
            ),
            _CompactFormRow(
              label: 'End Time',
              field: _compactInput(
                controller: _endTimeController,
                focusNode: _endTimeFocus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
            ),
          ],
        ),
      ),
      tableChild: _SectionCard(
        title: 'Records',
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        expandChild: true,
        child: _SimpleTable(
          headers: const ['Offer', 'Discount', 'Time Range'],
          selectedIndex: _selectedIndex,
          rows: happyHours
              .map(
                (row) => [
                  (row['offer'] ?? '').toString(),
                  (row['discount'] ?? '').toString(),
                  '${(row['start'] ?? '').toString()} - ${(row['end'] ?? '').toString()}',
                ],
              )
              .toList(),
          onRowTap: (index) => setState(() => _selectedIndex = index),
        ),
      ),
      onEdit: _editSelected,
      onDelete: _deleteSelected,
      onSave: _save,
      onClear: _clearForm,
    );
  }
}

class _SimpleTableValueCell extends StatelessWidget {
  final String text;
  final int flex;

  const _SimpleTableValueCell({required this.text, required this.flex});

  @override
  Widget build(BuildContext context) {
    final value = text.toLowerCase();
    final bool isSuccess = value == 'success' || value == 'paid';
    final bool isDanger = value == 'danger' || value == 'failed';
    final bool isPending = value == 'pending' || value == 'partial';

    Widget childWidget;
    if (isSuccess || isDanger || isPending) {
      Color bg;
      Color fg;
      if (isSuccess) {
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
      } else if (isDanger) {
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
      } else {
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFF9A3412);
      }
      childWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      );
    } else {
      childWidget = Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      );
    }

    return Expanded(
      flex: flex,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.blueGrey.shade100),
            top: BorderSide(color: Colors.blueGrey.shade50),
          ),
        ),
        child: childWidget,
      ),
    );
  }
}

class InvoicePrintScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const InvoicePrintScreen({super.key, this.onClose});

  @override
  State<InvoicePrintScreen> createState() => _InvoicePrintScreenState();
}

class _InvoicePrintScreenState extends State<InvoicePrintScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  final List<Map<String, dynamic>> _allInvoices = [
    {
      'invoiceNo': 'INV-1001',
      'customer': 'Aarav Pharma',
      'date': DateTime(2026, 4, 2),
      'amount': 1850.75,
      'status': 'Paid',
    },
    {
      'invoiceNo': 'INV-1002',
      'customer': 'MediCare Plus',
      'date': DateTime(2026, 4, 4),
      'amount': 920.20,
      'status': 'Pending',
    },
    {
      'invoiceNo': 'INV-1003',
      'customer': 'Krishna Clinic',
      'date': DateTime(2026, 4, 8),
      'amount': 3140.00,
      'status': 'Paid',
    },
    {
      'invoiceNo': 'INV-1004',
      'customer': 'Health First',
      'date': DateTime(2026, 4, 10),
      'amount': 1265.50,
      'status': 'Partial',
    },
  ];

  List<Map<String, dynamic>> _filteredInvoices = [];
  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedCustomer = 'All';
  int? _selectedIndex;
  int? _hoveredIndex;
  bool _isLoading = false;

  List<String> get _customers => [
    'All',
    ..._allInvoices.map((e) => e['customer'].toString()).toSet(),
  ];

  @override
  void initState() {
    super.initState();
    _applyFilters(instant: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$dd-$mm-${dt.year}';
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? _fromDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
          _toDate = _fromDate;
        }
      } else {
        _toDate = picked;
      }
    });
  }

  Future<void> _applyFilters({bool instant = false}) async {
    setState(() => _isLoading = true);
    if (!instant) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }

    final query = _searchController.text.trim().toLowerCase();
    final rows = _allInvoices.where((row) {
      final invoiceNo = row['invoiceNo'].toString().toLowerCase();
      final customer = row['customer'].toString().toLowerCase();
      final date = row['date'] as DateTime;
      final matchQuery =
          query.isEmpty ||
          invoiceNo.contains(query) ||
          customer.contains(query);
      final matchCustomer =
          _selectedCustomer == 'All' || row['customer'] == _selectedCustomer;
      final matchFrom =
          _fromDate == null ||
          !date.isBefore(
            DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day),
          );
      final matchTo =
          _toDate == null ||
          !date.isAfter(
            DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59),
          );
      return matchQuery && matchCustomer && matchFrom && matchTo;
    }).toList();

    if (!mounted) return;
    setState(() {
      _filteredInvoices = rows;
      _isLoading = false;
      _selectedIndex = null;
    });
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedCustomer = 'All';
      _fromDate = null;
      _toDate = null;
    });
    _applyFilters();
    _searchFocus.requestFocus();
  }

  void _previewInvoice(Map<String, dynamic> row) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Container(
            width: 560,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFEFD),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'Invoice Preview',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _previewLine('Invoice No', row['invoiceNo'].toString()),
                _previewLine('Customer', row['customer'].toString()),
                _previewLine('Date', _fmtDate(row['date'] as DateTime)),
                _previewLine(
                  'Total Amount',
                  'Rs. ${(row['amount'] as double).toStringAsFixed(2)}',
                ),
                _previewLine('Status', row['status'].toString()),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _previewLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }

  void _printInvoice(Map<String, dynamic> row) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Printing Invoice ${row['invoiceNo']}...'),
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F6F4),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.print_rounded, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Invoice Print Center',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (widget.onClose != null)
                        IconButton(
                          onPressed: widget.onClose,
                          tooltip: 'Close',
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _applyFilters(),
                          decoration: InputDecoration(
                            hintText: 'Search by invoice no / customer',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _selectedCustomer,
                          decoration: InputDecoration(
                            labelText: 'Customer',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _customers
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(c),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedCustomer = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _DateChipButton(
                        label: _fromDate == null
                            ? 'From Date'
                            : 'From: ${_fmtDate(_fromDate!)}',
                        icon: Icons.event,
                        onTap: () => _pickDate(isFrom: true),
                      ),
                      const SizedBox(width: 8),
                      _DateChipButton(
                        label: _toDate == null
                            ? 'To Date'
                            : 'To: ${_fmtDate(_toDate!)}',
                        icon: Icons.event_available,
                        onTap: () => _pickDate(isFrom: false),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _applyFilters,
                        icon: const Icon(Icons.search),
                        label: const Text('Search'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.refresh),
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.blueGrey.shade700,
                        ),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              elevation: 2.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F1EC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Invoice No',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Customer Name',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Date',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Total Amount',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Status',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          SizedBox(
                            width: 190,
                            child: Text(
                              'Actions',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _filteredInvoices.isEmpty
                            ? const _NoDataPanel(
                                message:
                                    'No invoices found for selected filters',
                              )
                            : ListView.separated(
                                key: const ValueKey('invoice-list'),
                                itemCount: _filteredInvoices.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final row = _filteredInvoices[index];
                                  final selected = _selectedIndex == index;
                                  final hovered = _hoveredIndex == index;
                                  return MouseRegion(
                                    onEnter: (_) =>
                                        setState(() => _hoveredIndex = index),
                                    onExit: (_) =>
                                        setState(() => _hoveredIndex = null),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () => setState(
                                        () => _selectedIndex = index,
                                      ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? const Color(0xFFD9F0E0)
                                              : hovered
                                              ? const Color(0xFFF5FAF7)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                row['invoiceNo'].toString(),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                row['customer'].toString(),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _fmtDate(
                                                  row['date'] as DateTime,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'Rs. ${(row['amount'] as double).toStringAsFixed(2)}',
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                row['status'].toString(),
                                                style: TextStyle(
                                                  color: row['status'] == 'Paid'
                                                      ? Colors.green.shade700
                                                      : Colors.orange.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 190,
                                              child: Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  FilledButton.tonalIcon(
                                                    onPressed: () =>
                                                        _previewInvoice(row),
                                                    icon: const Icon(
                                                      Icons.visibility,
                                                    ),
                                                    style:
                                                        FilledButton.styleFrom(
                                                          foregroundColor:
                                                              Colors
                                                                  .blue
                                                                  .shade700,
                                                        ),
                                                    label: const Text(
                                                      'Preview',
                                                    ),
                                                  ),
                                                  FilledButton.icon(
                                                    onPressed: () =>
                                                        _printInvoice(row),
                                                    style:
                                                        FilledButton.styleFrom(
                                                          backgroundColor:
                                                              Colors
                                                                  .green
                                                                  .shade600,
                                                        ),
                                                    icon: const Icon(
                                                      Icons.print,
                                                    ),
                                                    label: const Text('Print'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CreditDebitNotePrintScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const CreditDebitNotePrintScreen({super.key, this.onClose});

  @override
  State<CreditDebitNotePrintScreen> createState() =>
      _CreditDebitNotePrintScreenState();
}

class _CreditDebitNotePrintScreenState
    extends State<CreditDebitNotePrintScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  final List<Map<String, dynamic>> _allNotes = [
    {
      'noteNo': 'CDN-301',
      'account': 'Aarav Pharma',
      'type': 'Credit',
      'amount': 540.00,
      'date': DateTime(2026, 4, 1),
    },
    {
      'noteNo': 'CDN-302',
      'account': 'MediCare Plus',
      'type': 'Debit',
      'amount': 220.50,
      'date': DateTime(2026, 4, 6),
    },
    {
      'noteNo': 'CDN-303',
      'account': 'Krishna Clinic',
      'type': 'Credit',
      'amount': 985.00,
      'date': DateTime(2026, 4, 9),
    },
  ];

  List<Map<String, dynamic>> _filteredNotes = [];
  String _selectedType = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;
  int? _selectedIndex;
  int? _hoveredIndex;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _applyFilters(instant: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$dd-$mm-${dt.year}';
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? _fromDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
          _toDate = _fromDate;
        }
      } else {
        _toDate = picked;
      }
    });
  }

  Future<void> _applyFilters({bool instant = false}) async {
    setState(() => _isLoading = true);
    if (!instant) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }

    final query = _searchController.text.trim().toLowerCase();
    final rows = _allNotes.where((row) {
      final account = row['account'].toString().toLowerCase();
      final noteNo = row['noteNo'].toString().toLowerCase();
      final date = row['date'] as DateTime;
      final matchQuery =
          query.isEmpty || account.contains(query) || noteNo.contains(query);
      final matchType = _selectedType == 'All' || row['type'] == _selectedType;
      final matchFrom =
          _fromDate == null ||
          !date.isBefore(
            DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day),
          );
      final matchTo =
          _toDate == null ||
          !date.isAfter(
            DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59),
          );
      return matchQuery && matchType && matchFrom && matchTo;
    }).toList();

    if (!mounted) return;
    setState(() {
      _filteredNotes = rows;
      _isLoading = false;
      _selectedIndex = null;
    });
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedType = 'All';
      _fromDate = null;
      _toDate = null;
    });
    _applyFilters();
    _searchFocus.requestFocus();
  }

  void _previewNote(Map<String, dynamic> row) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 540,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFEFD),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.description_rounded, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    'Credit/Debit Note Preview',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _previewLine('Note No', row['noteNo'].toString()),
              _previewLine('Account', row['account'].toString()),
              _previewLine('Type', row['type'].toString()),
              _previewLine(
                'Amount',
                'Rs. ${(row['amount'] as double).toStringAsFixed(2)}',
              ),
              _previewLine('Date', _fmtDate(row['date'] as DateTime)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }

  void _printNote(Map<String, dynamic> row) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Printing ${row['type']} Note ${row['noteNo']}...'),
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F6F4),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt, color: Colors.blueGrey.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Credit / Debit Note Print Center',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (widget.onClose != null)
                        IconButton(
                          onPressed: widget.onClose,
                          tooltip: 'Close',
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _applyFilters(),
                          decoration: InputDecoration(
                            hintText: 'Search by note no / account',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All')),
                            DropdownMenuItem(
                              value: 'Credit',
                              child: Text('Credit'),
                            ),
                            DropdownMenuItem(
                              value: 'Debit',
                              child: Text('Debit'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedType = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _DateChipButton(
                        label: _fromDate == null
                            ? 'From Date'
                            : 'From: ${_fmtDate(_fromDate!)}',
                        icon: Icons.event,
                        onTap: () => _pickDate(isFrom: true),
                      ),
                      const SizedBox(width: 8),
                      _DateChipButton(
                        label: _toDate == null
                            ? 'To Date'
                            : 'To: ${_fmtDate(_toDate!)}',
                        icon: Icons.event_available,
                        onTap: () => _pickDate(isFrom: false),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _applyFilters,
                        icon: const Icon(Icons.search),
                        label: const Text('Search'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.refresh),
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.blueGrey.shade700,
                        ),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              elevation: 2.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F1EC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Note No',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Account Name',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Type',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Amount',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Date',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          SizedBox(
                            width: 190,
                            child: Text(
                              'Actions',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _filteredNotes.isEmpty
                            ? const _NoDataPanel(
                                message: 'No notes found for selected filters',
                              )
                            : ListView.separated(
                                key: const ValueKey('note-list'),
                                itemCount: _filteredNotes.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final row = _filteredNotes[index];
                                  final selected = _selectedIndex == index;
                                  final hovered = _hoveredIndex == index;
                                  return MouseRegion(
                                    onEnter: (_) =>
                                        setState(() => _hoveredIndex = index),
                                    onExit: (_) =>
                                        setState(() => _hoveredIndex = null),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () => setState(
                                        () => _selectedIndex = index,
                                      ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? const Color(0xFFD9F0E0)
                                              : hovered
                                              ? const Color(0xFFF5FAF7)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                row['noteNo'].toString(),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                row['account'].toString(),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                row['type'].toString(),
                                                style: TextStyle(
                                                  color: row['type'] == 'Credit'
                                                      ? Colors.green.shade700
                                                      : Colors.red.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'Rs. ${(row['amount'] as double).toStringAsFixed(2)}',
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _fmtDate(
                                                  row['date'] as DateTime,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 190,
                                              child: Row(
                                                children: [
                                                  FilledButton.tonalIcon(
                                                    onPressed: () =>
                                                        _previewNote(row),
                                                    icon: const Icon(
                                                      Icons.visibility,
                                                    ),
                                                    style:
                                                        FilledButton.styleFrom(
                                                          foregroundColor:
                                                              Colors
                                                                  .blue
                                                                  .shade700,
                                                        ),
                                                    label: const Text(
                                                      'Preview',
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  FilledButton.icon(
                                                    onPressed: () =>
                                                        _printNote(row),
                                                    style:
                                                        FilledButton.styleFrom(
                                                          backgroundColor:
                                                              Colors
                                                                  .green
                                                                  .shade600,
                                                        ),
                                                    icon: const Icon(
                                                      Icons.print,
                                                    ),
                                                    label: const Text('Print'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DateChipButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF6FAF8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.blueGrey.shade700),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _NoDataPanel extends StatelessWidget {
  final String message;
  const _NoDataPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 46, color: Colors.blueGrey.shade300),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: Colors.blueGrey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AccountMasterScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const AccountMasterScreen({super.key, this.onClose});

  @override
  State<AccountMasterScreen> createState() => _AccountMasterScreenState();
}

class _AccountMasterScreenState extends State<AccountMasterScreen> {
  final Map<String, TextEditingController> _controllers = {
    'name': TextEditingController(),
    'shortName': TextEditingController(),
    'address1': TextEditingController(),
    'address2': TextEditingController(),
    'city': TextEditingController(),
    'pin': TextEditingController(),
    'keyPerson': TextEditingController(),
    'phone': TextEditingController(),
    'mobile': TextEditingController(),
    'email': TextEditingController(),
    'tinLst': TextEditingController(),
    'cstReg': TextEditingController(),
    'drugLic1': TextEditingController(),
    'drugLic2': TextEditingController(),
    'discount': TextEditingController(),
    'phone2': TextEditingController(),
    'fax': TextEditingController(),
    'pisCode': TextEditingController(),
    'date1': TextEditingController(),
    'date2': TextEditingController(),
    'drugLic3': TextEditingController(),
    'drugLic4': TextEditingController(),
    'gstin': TextEditingController(),
    'openingBalance': TextEditingController(text: '0'),
  };

  final List<Map<String, dynamic>> accountList = [];
  int? _selectedIndex;
  final TextEditingController _accountSearchController = TextEditingController();
  String _accountLedgerType = 'Customer';

  final Map<String, FocusNode> _focusNodes = {
    'name': FocusNode(),
    'shortName': FocusNode(),
    'subGroup': FocusNode(),
    'address1': FocusNode(),
    'address2': FocusNode(),
    'city': FocusNode(),
    'pin': FocusNode(),
    'keyPerson': FocusNode(),
    'phone': FocusNode(),
    'mobile': FocusNode(),
    'email': FocusNode(),
    'tinLst': FocusNode(),
    'cstReg': FocusNode(),
    'drugLic1': FocusNode(),
    'drugLic2': FocusNode(),
    'groupType': FocusNode(),
    'nature': FocusNode(),
    'discount': FocusNode(),
    'phone2': FocusNode(),
    'fax': FocusNode(),
    'pisCode': FocusNode(),
    'date1': FocusNode(),
    'date2': FocusNode(),
    'drugLic3': FocusNode(),
    'drugLic4': FocusNode(),
    'gstin': FocusNode(),
    'openingBalance': FocusNode(),
    'ieFormat': FocusNode(),
    'billingType': FocusNode(),
    'remarks': FocusNode(),
    'saveBtn': FocusNode(),
  };

  TextEditingController c(String key) => _controllers[key]!;
  FocusNode f(String key) => _focusNodes[key]!;

  List<Map<String, dynamic>> _sortAccounts(
    List<Map<String, dynamic>> rows,
    String activeSortingType,
  ) {
    final sorted = List<Map<String, dynamic>>.from(rows);

    switch (activeSortingType) {
      case 'NameWise':
        sorted.sort(
          (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
            (b['name'] ?? '').toString().toLowerCase(),
          ),
        );
        break;
      case 'CityWise':
        sorted.sort((a, b) {
          final cityCompare = (a['city'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo((b['city'] ?? '').toString().toLowerCase());
          if (cityCompare != 0) {
            return cityCompare;
          }
          return (a['name'] ?? '').toString().toLowerCase().compareTo(
            (b['name'] ?? '').toString().toLowerCase(),
          );
        });
        break;
      case 'AccountWise':
      default:
        sorted.sort(
          (a, b) => ((a['id'] as int?) ?? 0).compareTo((b['id'] as int?) ?? 0),
        );
        break;
    }

    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        f('name').requestFocus();
      }
    });
  }

  Future<void> _loadAccounts() async {
    setState(() {
      accountList
        ..clear()
        ..addAll(_sortAccounts(accounts, sortingType));
      _selectedIndex = null;
    });

    return Future<void>.value();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _accountSearchController.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _clearForm() {
    for (final controller in _controllers.values) {
      controller.clear();
    }
    c('openingBalance').text = '0';
    setState(() {
      _selectedIndex = null;
      _accountLedgerType = 'Customer';
    });
    f('name').requestFocus();
  }

  Future<void> _saveAccount() async {
    if (c('name').text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name required'),
          duration: Duration(milliseconds: 900),
        ),
      );
      return;
    }

    final Map<String, dynamic> record = {
      'id': _accountSeed++,
      'name': c('name').text.trim(),
      'shortName': c('shortName').text.trim(),
      'mobile': c('mobile').text.trim(),
      'city': c('city').text.trim(),
      'gst': c('gstin').text.trim(),
      'address1': c('address1').text.trim(),
      'address2': c('address2').text.trim(),
      'pin': c('pin').text.trim(),
      'keyPerson': c('keyPerson').text.trim(),
      'phone': c('phone').text.trim(),
      'email': c('email').text.trim(),
      'tinLst': c('tinLst').text.trim(),
      'cstReg': c('cstReg').text.trim(),
      'drugLic1': c('drugLic1').text.trim(),
      'drugLic2': c('drugLic2').text.trim(),
      'discount': c('discount').text.trim(),
      'phone2': c('phone2').text.trim(),
      'fax': c('fax').text.trim(),
      'pisCode': c('pisCode').text.trim(),
      'date1': c('date1').text.trim(),
      'date2': c('date2').text.trim(),
      'drugLic3': c('drugLic3').text.trim(),
      'drugLic4': c('drugLic4').text.trim(),
      'openingBalance': double.tryParse(c('openingBalance').text.trim()) ?? 0,
      'accountType': _accountLedgerType,
    };

    accounts.add(record);
    try {
      await persistAccountRow(record);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved locally; database error: $e'),
            duration: const Duration(milliseconds: 1400),
          ),
        );
      }
    }

    await _loadAccounts();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved Successfully'),
        duration: Duration(milliseconds: 900),
      ),
    );
    _clearForm();
  }

  Future<void> _editAccount() async {
    if (_selectedIndex == null) {
      return;
    }
    final selected = accountList[_selectedIndex!];
    final int? id = selected['id'] as int?;
    if (id == null) {
      return;
    }

    final int index = accounts.indexWhere((row) => row['id'] == id);
    if (index == -1) {
      return;
    }

    accounts[index] = {
      ...accounts[index],
      'name': c('name').text.trim(),
      'shortName': c('shortName').text.trim(),
      'mobile': c('mobile').text.trim(),
      'city': c('city').text.trim(),
      'gst': c('gstin').text.trim(),
      'address1': c('address1').text.trim(),
      'address2': c('address2').text.trim(),
      'pin': c('pin').text.trim(),
      'keyPerson': c('keyPerson').text.trim(),
      'phone': c('phone').text.trim(),
      'email': c('email').text.trim(),
      'tinLst': c('tinLst').text.trim(),
      'cstReg': c('cstReg').text.trim(),
      'drugLic1': c('drugLic1').text.trim(),
      'drugLic2': c('drugLic2').text.trim(),
      'discount': c('discount').text.trim(),
      'phone2': c('phone2').text.trim(),
      'fax': c('fax').text.trim(),
      'pisCode': c('pisCode').text.trim(),
      'date1': c('date1').text.trim(),
      'date2': c('date2').text.trim(),
      'drugLic3': c('drugLic3').text.trim(),
      'drugLic4': c('drugLic4').text.trim(),
      'openingBalance': double.tryParse(c('openingBalance').text.trim()) ?? 0,
      'accountType': _accountLedgerType,
    };

    try {
      await persistAccountRow(accounts[index]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved locally; database error: $e'),
            duration: const Duration(milliseconds: 1400),
          ),
        );
      }
    }

    await _loadAccounts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved Successfully'),
        duration: Duration(milliseconds: 900),
      ),
    );
    _clearForm();
  }

  Future<void> _deleteAccount() async {
    if (_selectedIndex == null) {
      return;
    }

    final int? id = accountList[_selectedIndex!]['id'] as int?;
    if (id != null) {
      accounts.removeWhere((row) => row['id'] == id);
      try {
        await deleteAccountRow(id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed locally; database delete failed: $e'),
              duration: const Duration(milliseconds: 1400),
            ),
          );
        }
      }
      await _loadAccounts();
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deleted'),
        duration: Duration(milliseconds: 900),
      ),
    );
    _clearForm();
  }

  void _selectAccount(int index) {
    final account = accountList[index];
    setState(() {
      _selectedIndex = index;
      c('name').text = account['name'] ?? '';
      c('mobile').text = account['mobile'] ?? '';
      c('city').text = account['city'] ?? '';
      c('gstin').text = account['gst'] ?? '';
      c('address1').text = account['address1'] ?? '';
      final ob = account['openingBalance'];
      c('openingBalance').text = ob is num ? ob.toString() : (ob?.toString() ?? '0');
      _accountLedgerType = (account['accountType'] ?? 'Customer').toString();
    });
  }

  List<Map<String, dynamic>> _filteredAccountsForTable() {
    final q = _accountSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return accountList;
    return accountList.where((a) {
      return (a['name'] ?? '').toString().toLowerCase().contains(q) ||
          (a['mobile'] ?? '').toString().contains(q) ||
          (a['gst'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  int? _selectedIndexInFilteredTable() {
    final filtered = _filteredAccountsForTable();
    if (_selectedIndex == null || _selectedIndex! >= accountList.length) return null;
    final id = accountList[_selectedIndex!]['id'];
    final i = filtered.indexWhere((a) => a['id'] == id);
    return i >= 0 ? i : null;
  }

  void _selectAccountFromFilteredRow(int filteredIndex) {
    final filtered = _filteredAccountsForTable();
    if (filteredIndex < 0 || filteredIndex >= filtered.length) return;
    final id = filtered[filteredIndex]['id'];
    final ix = accountList.indexWhere((a) => a['id'] == id);
    if (ix >= 0) _selectAccount(ix);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F1F1),
      child: Column(
        children: [
          AccountMasterHeaderBar(onBack: widget.onClose),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double panelWidth = 120;
                final double leftWidth = (constraints.maxWidth * 0.75)
                    .clamp(0.0, constraints.maxWidth - panelWidth - 8)
                    .toDouble();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: leftWidth,
                      child: Column(
                        children: [
                          Expanded(
                            child: AccountMasterFormPane(
                              controllers: _controllers,
                              focusNodes: _focusNodes,
                              accountLedgerType: _accountLedgerType,
                              onLedgerTypeChanged: (v) => setState(() => _accountLedgerType = v),
                              onFinalSubmit: _saveAccount,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                            child: TextField(
                              controller: _accountSearchController,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(fontSize: 12.5),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Search name, mobile, GST…',
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: const Icon(Icons.search, size: 18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                ),
                              ),
                            ),
                          ),
                          AccountTableSection(
                            accountList: _filteredAccountsForTable(),
                            selectedIndex: _selectedIndexInFilteredTable(),
                            onRowTap: _selectAccountFromFilteredRow,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: panelWidth,
                      child: AccountMasterActionPanel(
                        onSave: _saveAccount,
                        onEdit: _editAccount,
                        onDelete: _deleteAccount,
                        onClear: _clearForm,
                        saveFocusNode: f('saveBtn'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AccountMasterHeaderBar extends StatelessWidget {
  final VoidCallback? onBack;
  const AccountMasterHeaderBar({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB0302D), Color(0xFF8B2FA1), Color(0xFF4A4FB5)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Account Master',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30 / 2.2,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
          if (onBack != null)
            InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(3),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Icon(Icons.close, color: Colors.white70, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

class AccountMasterFormPane extends StatelessWidget {
  final Map<String, TextEditingController> controllers;
  final Map<String, FocusNode> focusNodes;
  final String accountLedgerType;
  final ValueChanged<String> onLedgerTypeChanged;
  final VoidCallback onFinalSubmit;

  const AccountMasterFormPane({
    super.key,
    required this.controllers,
    required this.focusNodes,
    required this.accountLedgerType,
    required this.onLedgerTypeChanged,
    required this.onFinalSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Customer / supplier master',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 10),
            FormRow(
              label: 'Name *',
              field: _textInput(
                context: context,
                controller: controllers['name'],
                focusNode: focusNodes['name'],
                nextFocusNode: focusNodes['mobile'],
                autofocus: true,
              ),
            ),
            FormRow(
              label: 'Mobile',
              field: _textInput(
                context: context,
                controller: controllers['mobile'],
                focusNode: focusNodes['mobile'],
                nextFocusNode: focusNodes['address1'],
              ),
            ),
            FormRow(
              label: 'Address',
              topAligned: true,
              field: SizedBox(
                height: 52,
                child: TextField(
                  controller: controllers['address1'],
                  focusNode: focusNodes['address1'],
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => nextFocus(context, focusNodes['gstin']),
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Full address',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(3),
                      borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(3),
                      borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(3),
                      borderSide: BorderSide(color: Colors.blueGrey.shade400, width: 1),
                    ),
                  ),
                ),
              ),
            ),
            FormRow(
              label: 'GST No',
              field: _textInput(
                context: context,
                controller: controllers['gstin'],
                focusNode: focusNodes['gstin'],
                nextFocusNode: focusNodes['openingBalance'],
              ),
            ),
            FormRow(
              label: 'Opening bal.',
              field: _textInput(
                context: context,
                controller: controllers['openingBalance'],
                focusNode: focusNodes['openingBalance'],
                nextFocusNode: focusNodes['saveBtn'],
                keyboardType: TextInputType.number,
              ),
            ),
            FormRow(
              label: 'Account type',
              field: SizedBox(
                height: 28,
                child: DropdownButtonFormField<String>(
                  value: accountLedgerType,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(3),
                      borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Customer', child: Text('Customer')),
                    DropdownMenuItem(value: 'Supplier', child: Text('Supplier')),
                  ],
                  onChanged: (v) {
                    if (v != null) onLedgerTypeChanged(v);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _textInput({
    required BuildContext context,
    TextEditingController? controller,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    bool autofocus = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return SizedBox(
      height: 28,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => nextFocus(context, nextFocusNode),
        style: const TextStyle(fontSize: 12.5),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(color: Colors.blueGrey.shade400, width: 1),
          ),
        ),
      ),
    );
  }
}

class AccountTableSection extends StatelessWidget {
  final List<Map<String, dynamic>> accountList;
  final int? selectedIndex;
  final ValueChanged<int> onRowTap;

  const AccountTableSection({
    super.key,
    required this.accountList,
    required this.selectedIndex,
    required this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        children: [
          Container(
            height: 28,
            color: const Color(0xFFE8E8E8),
            child: const Row(
              children: [
                _TableHeaderCell(text: 'Name', flex: 3),
                _TableHeaderCell(text: 'Mobile', flex: 2),
                _TableHeaderCell(text: 'Type', flex: 2),
                _TableHeaderCell(text: 'GST', flex: 2),
                _TableHeaderCell(text: 'Op.Bal', flex: 2),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: accountList.length,
              itemBuilder: (context, index) {
                final account = accountList[index];
                final bool isSelected = selectedIndex == index;
                final ob = account['openingBalance'];
                final obStr = ob is num ? ob.toStringAsFixed(2) : (double.tryParse(ob?.toString() ?? '0') ?? 0).toStringAsFixed(2);
                return InkWell(
                  onTap: () => onRowTap(index),
                  child: Container(
                    height: 26,
                    color: isSelected ? const Color(0xFFDDE8FF) : Colors.white,
                    child: Row(
                      children: [
                        _TableValueCell(
                          text: (account['name'] ?? '').toString(),
                          flex: 3,
                        ),
                        _TableValueCell(
                          text: (account['mobile'] ?? '').toString(),
                          flex: 2,
                        ),
                        _TableValueCell(
                          text: (account['accountType'] ?? 'Customer').toString(),
                          flex: 2,
                        ),
                        _TableValueCell(
                          text: (account['gst'] ?? '').toString(),
                          flex: 2,
                        ),
                        _TableValueCell(
                          text: obStr,
                          flex: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String text;
  final int flex;

  const _TableHeaderCell({required this.text, required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey.shade400)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _TableValueCell extends StatelessWidget {
  final String text;
  final int flex;

  const _TableValueCell({required this.text, required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey.shade300),
            top: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class FormRow extends StatelessWidget {
  final String label;
  final Widget field;
  final bool topAligned;

  const FormRow({
    super.key,
    required this.label,
    required this.field,
    this.topAligned = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: topAligned
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Padding(
              padding: EdgeInsets.only(top: topAligned ? 6 : 0),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          Expanded(child: field),
        ],
      ),
    );
  }
}

class AccountMasterFadedPane extends StatelessWidget {
  const AccountMasterFadedPane({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3F3),
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: Icon(
                Icons.medication_rounded,
                size: 380,
                color: Colors.blueGrey.shade600,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFAF7F7), Color(0xFFF1F3F8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountMasterActionPanel extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final FocusNode? saveFocusNode;

  const AccountMasterActionPanel({
    super.key,
    required this.onSave,
    required this.onEdit,
    required this.onDelete,
    required this.onClear,
    this.saveFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F1F1),
      padding: const EdgeInsets.fromLTRB(8, 10, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          MasterActionButton(
            label: 'Edit',
            icon: Icons.edit,
            accentColor: Colors.grey.shade700,
            onPressed: onEdit,
          ),
          const SizedBox(height: 10),
          MasterActionButton(
            label: 'Delete',
            icon: Icons.delete_outline,
            accentColor: Colors.red.shade600,
            onPressed: onDelete,
          ),
          const SizedBox(height: 10),
          MasterActionButton(
            label: 'Save',
            icon: Icons.save,
            accentColor: Colors.green.shade700,
            onPressed: onSave,
            focusNode: saveFocusNode,
          ),
          const SizedBox(height: 10),
          MasterActionButton(
            label: 'Clear',
            icon: Icons.cleaning_services,
            accentColor: Colors.blueGrey.shade600,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class ProductMasterScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const ProductMasterScreen({super.key, this.onClose});

  @override
  State<ProductMasterScreen> createState() => _ProductMasterScreenState();
}

class _ProductMasterScreenState extends State<ProductMasterScreen> {
  final Map<String, TextEditingController> _controllers = {
    'name': TextEditingController(),
    'description': TextEditingController(),
    'company': TextEditingController(),
    'purPack': TextEditingController(),
    'salesPack': TextEditingController(),
    'minStock': TextEditingController(),
    'maxStock': TextEditingController(),
    'mrp': TextEditingController(),
    'favourite': TextEditingController(),
    'generic': TextEditingController(),
    'remarks': TextEditingController(),
    'hsn': TextEditingController(),
    'ratio': TextEditingController(),
    'reorderQty': TextEditingController(),
    'addVat': TextEditingController(),
    'barcode': TextEditingController(),
  };

  final List<Map<String, dynamic>> productList = [];
  int? _selectedIndex;

  final Map<String, FocusNode> _focusNodes = {
    'name': FocusNode(),
    'description': FocusNode(),
    'company': FocusNode(),
    'purPack': FocusNode(),
    'salesPack': FocusNode(),
    'minStock': FocusNode(),
    'maxStock': FocusNode(),
    'mrp': FocusNode(),
    'vatOn': FocusNode(),
    'favourite': FocusNode(),
    'generic': FocusNode(),
    'remarks': FocusNode(),
    'discount': FocusNode(),
    'hsn': FocusNode(),
    'purGst': FocusNode(),
    'salesGst': FocusNode(),
    'ratio': FocusNode(),
    'reorderQty': FocusNode(),
    'expiry': FocusNode(),
    'addVat': FocusNode(),
    'taxOnRate': FocusNode(),
    'barcode': FocusNode(),
    'category': FocusNode(),
    'schedule': FocusNode(),
    'saveBtn': FocusNode(),
  };

  String _discount = 'Yes';
  String _purGst = 'GST 12% (P)';
  String _salesGst = 'GST 12% (S)';
  String _expiry = 'Yes';
  String _taxOnRate = 'Inclusive';
  String _category = 'TABLET';
  String _schedule = '(none)';
  String _vatOn = 'W/Rate';

  TextEditingController c(String key) => _controllers[key]!;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes['name']!.requestFocus();
      }
    });
  }

  Future<void> _loadProducts() async {
    setState(() {
      productList
        ..clear()
        ..addAll(products);
      _selectedIndex = null;
    });

    return Future<void>.value();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  String _num(String value) {
    final n = double.tryParse(value.trim()) ?? 0;
    return n.toStringAsFixed(2);
  }

  String _calcSaleRate() {
    final mrp = double.tryParse(c('mrp').text.trim()) ?? 0;
    final discountPercent = _discount == 'Yes' ? 10.0 : 0.0;
    final saleRate = mrp - (mrp * discountPercent / 100);
    return saleRate.toStringAsFixed(2);
  }

  void _clearForm() {
    for (final controller in _controllers.values) {
      controller.clear();
    }
    setState(() {
      _selectedIndex = null;
      _discount = 'Yes';
      _purGst = 'GST 12% (P)';
      _salesGst = 'GST 12% (S)';
      _expiry = 'Yes';
      _taxOnRate = 'Inclusive';
      _category = 'TABLET';
      _schedule = '(none)';
      _vatOn = 'W/Rate';
    });
    _focusNodes['name']!.requestFocus();
  }

  void _unmapFields() {
    setState(() {
      c('company').clear();
      c('generic').clear();
      c('barcode').clear();
      _category = 'TABLET';
      _schedule = '(none)';
    });
  }

  Future<void> _saveProduct() async {
    if (c('name').text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name required'),
          duration: Duration(milliseconds: 900),
        ),
      );
      return;
    }

    final saleRate = _calcSaleRate();

    final double saleRateValue = double.tryParse(saleRate) ?? 0;
    final double costRate = saleRateValue * 0.85;
    final double marginRs = saleRateValue - costRate;
    final double margin = saleRateValue == 0
        ? 0
        : (marginRs / saleRateValue) * 100;

    products.add({
      'id': _productSeed++,
      'name': c('name').text.trim(),
      'description': c('description').text.trim(),
      'company': c('company').text.trim(),
      'purPack': c('purPack').text.trim(),
      'salesPack': c('salesPack').text.trim(),
      'minStock': c('minStock').text.trim(),
      'maxStock': c('maxStock').text.trim(),
      'mrp': _num(c('mrp').text),
      'vatOn': _vatOn,
      'favourite': c('favourite').text.trim(),
      'generic': c('generic').text.trim(),
      'remarks': c('remarks').text.trim(),
      'discount': _discount,
      'hsn': c('hsn').text.trim(),
      'purGst': _purGst,
      'salesGst': _salesGst,
      'ratio': c('ratio').text.trim(),
      'reorderQty': c('reorderQty').text.trim(),
      'expiry': _expiry,
      'addVat': c('addVat').text.trim(),
      'taxOnRate': _taxOnRate,
      'barcode': c('barcode').text.trim(),
      'category': _category,
      'schedule': _schedule,
      'wRate': saleRate,
      'excise': '0.00',
      'suffered': '0.00',
      'cst': '0.00',
      'lst': '0.00',
      'lstRs': '0.00',
      'octroi': '0.00',
      'disc': '0.00',
      'saleRate': saleRate,
      'costRate': costRate.toStringAsFixed(2),
      'margin': margin.toStringAsFixed(2),
      'marginRs': marginRs.toStringAsFixed(2),
      'stock': '0',
    });
    try {
      await persistProductRow(products.last);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved locally; database error: $e'),
            duration: const Duration(milliseconds: 1400),
          ),
        );
      }
    }

    await _loadProducts();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved Successfully'),
        duration: Duration(milliseconds: 900),
      ),
    );
    _clearForm();
  }

  void _selectProduct(int index) {
    final p = productList[index];
    setState(() {
      _selectedIndex = index;
      c('name').text = p['name'] ?? '';
      c('description').text = p['description'] ?? '';
      c('company').text = p['company'] ?? '';
      c('purPack').text = p['purPack'] ?? '';
      c('salesPack').text = p['salesPack'] ?? '';
      c('minStock').text = p['minStock'] ?? '';
      c('maxStock').text = p['maxStock'] ?? '';
      c('mrp').text = p['mrp'] ?? '';
      c('favourite').text = p['favourite'] ?? '';
      c('generic').text = p['generic'] ?? '';
      c('remarks').text = p['remarks'] ?? '';
      c('hsn').text = p['hsn'] ?? '';
      c('ratio').text = p['ratio'] ?? '';
      c('reorderQty').text = p['reorderQty'] ?? '';
      c('addVat').text = p['addVat'] ?? '';
      c('barcode').text = p['barcode'] ?? '';
      _discount = p['discount'] ?? 'Yes';
      _purGst = p['purGst'] ?? 'GST 12% (P)';
      _salesGst = p['salesGst'] ?? 'GST 12% (S)';
      _expiry = p['expiry'] ?? 'Yes';
      _taxOnRate = p['taxOnRate'] ?? 'Inclusive';
      _category = p['category'] ?? 'TABLET';
      _schedule = p['schedule'] ?? '(none)';
      _vatOn = p['vatOn'] ?? 'W/Rate';
    });
  }

  Future<void> _editSelected() async {
    if (_selectedIndex == null) {
      return;
    }
    final int? id = productList[_selectedIndex!]['id'] as int?;
    if (id == null) {
      return;
    }

    final int index = products.indexWhere((row) => row['id'] == id);
    if (index == -1) {
      return;
    }

    final String saleRate = _calcSaleRate();
    final double saleRateValue = double.tryParse(saleRate) ?? 0;
    final double costRate = saleRateValue * 0.85;
    final double marginRs = saleRateValue - costRate;
    final double margin = saleRateValue == 0
        ? 0
        : (marginRs / saleRateValue) * 100;

    products[index] = {
      ...products[index],
      'name': c('name').text.trim(),
      'description': c('description').text.trim(),
      'company': c('company').text.trim(),
      'purPack': c('purPack').text.trim(),
      'salesPack': c('salesPack').text.trim(),
      'minStock': c('minStock').text.trim(),
      'maxStock': c('maxStock').text.trim(),
      'mrp': _num(c('mrp').text),
      'vatOn': _vatOn,
      'favourite': c('favourite').text.trim(),
      'generic': c('generic').text.trim(),
      'remarks': c('remarks').text.trim(),
      'discount': _discount,
      'hsn': c('hsn').text.trim(),
      'purGst': _purGst,
      'salesGst': _salesGst,
      'ratio': c('ratio').text.trim(),
      'reorderQty': c('reorderQty').text.trim(),
      'expiry': _expiry,
      'addVat': c('addVat').text.trim(),
      'taxOnRate': _taxOnRate,
      'barcode': c('barcode').text.trim(),
      'category': _category,
      'schedule': _schedule,
      'wRate': saleRate,
      'saleRate': saleRate,
      'costRate': costRate.toStringAsFixed(2),
      'margin': margin.toStringAsFixed(2),
      'marginRs': marginRs.toStringAsFixed(2),
    };

    try {
      await persistProductRow(products[index]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved locally; database error: $e'),
            duration: const Duration(milliseconds: 1400),
          ),
        );
      }
    }

    await _loadProducts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved Successfully'),
        duration: Duration(milliseconds: 900),
      ),
    );
    _clearForm();
  }

  Future<void> _deleteSelected() async {
    if (_selectedIndex == null) {
      return;
    }
    final int? id = productList[_selectedIndex!]['id'] as int?;
    if (id != null) {
      products.removeWhere((row) => row['id'] == id);
      try {
        await deleteProductRow(id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed locally; database delete failed: $e'),
              duration: const Duration(milliseconds: 1400),
            ),
          );
        }
      }
      await _loadProducts();
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deleted'),
        duration: Duration(milliseconds: 900),
      ),
    );
    _clearForm();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F1F1),
      child: Column(
        children: [
          ProductMasterHeaderBar(onBack: widget.onClose),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double panelWidth = 120;
                final double leftWidth = (constraints.maxWidth * 0.75)
                    .clamp(0.0, constraints.maxWidth - panelWidth - 8)
                    .toDouble();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: leftWidth,
                      child: Column(
                        children: [
                          Expanded(
                            child: ProductMasterFormPane(
                              controllers: _controllers,
                              focusNodes: _focusNodes,
                              onFinalSubmit: _saveProduct,
                              discount: _discount,
                              purGst: _purGst,
                              salesGst: _salesGst,
                              expiry: _expiry,
                              taxOnRate: _taxOnRate,
                              category: _category,
                              schedule: _schedule,
                              vatOn: _vatOn,
                              onDiscountChanged: (v) =>
                                  setState(() => _discount = v),
                              onPurGstChanged: (v) =>
                                  setState(() => _purGst = v),
                              onSalesGstChanged: (v) =>
                                  setState(() => _salesGst = v),
                              onExpiryChanged: (v) =>
                                  setState(() => _expiry = v),
                              onTaxOnRateChanged: (v) =>
                                  setState(() => _taxOnRate = v),
                              onCategoryChanged: (v) =>
                                  setState(() => _category = v),
                              onScheduleChanged: (v) =>
                                  setState(() => _schedule = v),
                              onVatOnChanged: (v) => setState(() => _vatOn = v),
                            ),
                          ),
                          ProductRateTableSection(
                            productList: productList,
                            selectedIndex: _selectedIndex,
                            onRowTap: _selectProduct,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: panelWidth,
                      child: ProductMasterActionPanel(
                        onEdit: _editSelected,
                        onDelete: _deleteSelected,
                        onSave: _saveProduct,
                        onClear: _clearForm,
                        onUnmap: _unmapFields,
                        saveFocusNode: _focusNodes['saveBtn'],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProductMasterHeaderBar extends StatelessWidget {
  final VoidCallback? onBack;
  const ProductMasterHeaderBar({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB0302D), Color(0xFF8B2FA1), Color(0xFF4A4FB5)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Product Master',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30 / 2.2,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
          if (onBack != null)
            InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(3),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Icon(Icons.close, color: Colors.white70, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

class ProductMasterFormPane extends StatelessWidget {
  final Map<String, TextEditingController> controllers;
  final Map<String, FocusNode> focusNodes;
  final VoidCallback onFinalSubmit;
  final String discount;
  final String purGst;
  final String salesGst;
  final String expiry;
  final String taxOnRate;
  final String category;
  final String schedule;
  final String vatOn;
  final ValueChanged<String> onDiscountChanged;
  final ValueChanged<String> onPurGstChanged;
  final ValueChanged<String> onSalesGstChanged;
  final ValueChanged<String> onExpiryChanged;
  final ValueChanged<String> onTaxOnRateChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onScheduleChanged;
  final ValueChanged<String> onVatOnChanged;

  const ProductMasterFormPane({
    super.key,
    required this.controllers,
    required this.focusNodes,
    required this.onFinalSubmit,
    required this.discount,
    required this.purGst,
    required this.salesGst,
    required this.expiry,
    required this.taxOnRate,
    required this.category,
    required this.schedule,
    required this.vatOn,
    required this.onDiscountChanged,
    required this.onPurGstChanged,
    required this.onSalesGstChanged,
    required this.onExpiryChanged,
    required this.onTaxOnRateChanged,
    required this.onCategoryChanged,
    required this.onScheduleChanged,
    required this.onVatOnChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                _ProductFormRow(
                  label: 'Name',
                  field: _textInput(
                    context: context,
                    controller: controllers['name'],
                    focusNode: focusNodes['name'],
                    nextFocusNode: focusNodes['description'],
                    autofocus: true,
                  ),
                ),
                _ProductFormRow(
                  label: 'Description',
                  field: _textInput(
                    context: context,
                    controller: controllers['description'],
                    focusNode: focusNodes['description'],
                    nextFocusNode: focusNodes['company'],
                  ),
                ),
                _ProductFormRow(
                  label: 'Company',
                  field: _textInput(
                    context: context,
                    controller: controllers['company'],
                    focusNode: focusNodes['company'],
                    nextFocusNode: focusNodes['purPack'],
                  ),
                ),
                _ProductFormRow(
                  label: 'Pur Pack',
                  field: Row(
                    children: [
                      Expanded(
                        child: _textInput(
                          context: context,
                          controller: controllers['purPack'],
                          focusNode: focusNodes['purPack'],
                          nextFocusNode: focusNodes['salesPack'],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _textInput(
                          context: context,
                          controller: controllers['salesPack'],
                          focusNode: focusNodes['salesPack'],
                          nextFocusNode: focusNodes['minStock'],
                        ),
                      ),
                    ],
                  ),
                ),
                _ProductFormRow(
                  label: 'Min.Stock',
                  field: Row(
                    children: [
                      Expanded(
                        child: _textInput(
                          context: context,
                          controller: controllers['minStock'],
                          focusNode: focusNodes['minStock'],
                          nextFocusNode: focusNodes['maxStock'],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _textInput(
                          context: context,
                          controller: controllers['maxStock'],
                          focusNode: focusNodes['maxStock'],
                          nextFocusNode: focusNodes['mrp'],
                        ),
                      ),
                    ],
                  ),
                ),
                _ProductFormRow(
                  label: 'MRP',
                  field: _textInput(
                    context: context,
                    controller: controllers['mrp'],
                    focusNode: focusNodes['mrp'],
                    nextFocusNode: focusNodes['vatOn'],
                  ),
                ),
                _ProductFormRow(
                  label: 'VAT On',
                  field: _dropdown(
                    context: context,
                    value: vatOn,
                    values: const ['W/Rate', 'MRP'],
                    onChanged: onVatOnChanged,
                    focusNode: focusNodes['vatOn'],
                    nextFocusNode: focusNodes['favourite'],
                  ),
                ),
                _ProductFormRow(
                  label: 'Favourite',
                  field: _textInput(
                    context: context,
                    controller: controllers['favourite'],
                    focusNode: focusNodes['favourite'],
                    nextFocusNode: focusNodes['generic'],
                  ),
                ),
                _ProductFormRow(
                  label: 'Generic',
                  field: _textInput(
                    context: context,
                    controller: controllers['generic'],
                    focusNode: focusNodes['generic'],
                    nextFocusNode: focusNodes['remarks'],
                  ),
                ),
                _ProductFormRow(
                  label: 'Remarks',
                  field: _textInput(
                    context: context,
                    controller: controllers['remarks'],
                    focusNode: focusNodes['remarks'],
                    nextFocusNode: focusNodes['discount'],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                _ProductFormRow(
                  label: 'Discount',
                  field: _dropdown(
                    context: context,
                    value: discount,
                    values: const ['Yes', 'No'],
                    onChanged: onDiscountChanged,
                    focusNode: focusNodes['discount'],
                    nextFocusNode: focusNodes['hsn'],
                  ),
                ),
                _ProductFormRow(
                  label: 'HSN',
                  field: _textInput(
                    context: context,
                    controller: controllers['hsn'],
                    focusNode: focusNodes['hsn'],
                    nextFocusNode: focusNodes['purGst'],
                  ),
                ),
                _ProductFormRow(
                  label: 'Pur.GST',
                  field: _dropdown(
                    context: context,
                    value: purGst,
                    values: const ['GST 5% (P)', 'GST 12% (P)', 'GST 18% (P)'],
                    onChanged: onPurGstChanged,
                    focusNode: focusNodes['purGst'],
                    nextFocusNode: focusNodes['salesGst'],
                  ),
                ),
                _ProductFormRow(
                  label: 'SalesGST',
                  field: _dropdown(
                    context: context,
                    value: salesGst,
                    values: const ['GST 5% (S)', 'GST 12% (S)', 'GST 18% (S)'],
                    onChanged: onSalesGstChanged,
                    focusNode: focusNodes['salesGst'],
                    nextFocusNode: focusNodes['ratio'],
                  ),
                ),
                _ProductFormRow(
                  label: 'Ratio',
                  field: _textInput(
                    context: context,
                    controller: controllers['ratio'],
                    focusNode: focusNodes['ratio'],
                    nextFocusNode: focusNodes['reorderQty'],
                  ),
                ),
                _ProductFormRow(
                  label: 'Reorder Qty.',
                  field: _textInput(
                    context: context,
                    controller: controllers['reorderQty'],
                    focusNode: focusNodes['reorderQty'],
                    nextFocusNode: focusNodes['expiry'],
                  ),
                ),
                _ProductFormRow(
                  label: 'Expiry',
                  field: _dropdown(
                    context: context,
                    value: expiry,
                    values: const ['Yes', 'No'],
                    onChanged: onExpiryChanged,
                    focusNode: focusNodes['expiry'],
                    nextFocusNode: focusNodes['addVat'],
                  ),
                ),
                _ProductFormRow(
                  label: 'Add VAT %',
                  field: _textInput(
                    context: context,
                    controller: controllers['addVat'],
                    focusNode: focusNodes['addVat'],
                    nextFocusNode: focusNodes['taxOnRate'],
                  ),
                ),
                _ProductFormRow(
                  label: 'TaxOnRate',
                  field: _dropdown(
                    context: context,
                    value: taxOnRate,
                    values: const ['Inclusive', 'Exclusive'],
                    onChanged: onTaxOnRateChanged,
                    focusNode: focusNodes['taxOnRate'],
                    nextFocusNode: focusNodes['barcode'],
                  ),
                ),
                _ProductFormRow(
                  label: 'Barcode',
                  field: _textInput(
                    context: context,
                    controller: controllers['barcode'],
                    focusNode: focusNodes['barcode'],
                    nextFocusNode: focusNodes['category'],
                  ),
                ),
                _ProductFormRow(
                  label: 'Category',
                  field: _dropdown(
                    context: context,
                    value: category,
                    values: const ['TABLET', 'CAPSULE', 'SYRUP', 'INJECTION'],
                    onChanged: onCategoryChanged,
                    focusNode: focusNodes['category'],
                    nextFocusNode: focusNodes['schedule'],
                  ),
                ),
                _ProductFormRow(
                  label: 'Schedule',
                  field: _dropdown(
                    context: context,
                    value: schedule,
                    values: const ['(none)', 'H', 'H1', 'X'],
                    onChanged: onScheduleChanged,
                    focusNode: focusNodes['schedule'],
                    onEnterAction: onFinalSubmit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _textInput({
    required BuildContext context,
    TextEditingController? controller,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    bool autofocus = false,
  }) {
    return SizedBox(
      height: 28,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => nextFocus(context, nextFocusNode),
        style: const TextStyle(fontSize: 12.5),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(color: Colors.blueGrey.shade400, width: 1),
          ),
        ),
      ),
    );
  }

  static Widget _dropdown({
    required BuildContext context,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    VoidCallback? onEnterAction,
  }) {
    return SizedBox(
      height: 28,
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: (_, event) {
          if (onEnterAction != null) {
            return handleEnterAction(event, onEnterAction);
          }
          return handleEnterToNext(context, nextFocusNode, event);
        },
        child: DropdownButtonFormField<String>(
          value: values.contains(value) ? value : values.first,
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          style: const TextStyle(fontSize: 12.5, color: Colors.black87),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(color: Colors.blueGrey.shade400, width: 1),
            ),
          ),
          items: values
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: const TextStyle(fontSize: 12.5)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}

class _ProductFormRow extends StatelessWidget {
  final String label;
  final Widget field;

  const _ProductFormRow({required this.label, required this.field});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(child: field),
        ],
      ),
    );
  }
}

class ProductMasterActionPanel extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final VoidCallback onUnmap;
  final FocusNode? saveFocusNode;

  const ProductMasterActionPanel({
    super.key,
    required this.onEdit,
    required this.onDelete,
    required this.onSave,
    required this.onClear,
    required this.onUnmap,
    this.saveFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F1F1),
      padding: const EdgeInsets.fromLTRB(8, 10, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          MasterActionButton(
            label: 'Edit',
            icon: Icons.edit,
            accentColor: Colors.grey.shade700,
            onPressed: onEdit,
          ),
          const SizedBox(height: 10),
          MasterActionButton(
            label: 'Delete',
            icon: Icons.delete_outline,
            accentColor: Colors.red.shade600,
            onPressed: onDelete,
          ),
          const SizedBox(height: 10),
          MasterActionButton(
            label: 'Save',
            icon: Icons.save,
            accentColor: Colors.green.shade700,
            onPressed: onSave,
            focusNode: saveFocusNode,
          ),
          const SizedBox(height: 10),
          MasterActionButton(
            label: 'Clear',
            icon: Icons.cleaning_services,
            accentColor: Colors.blueGrey.shade600,
            onPressed: onClear,
          ),
          const SizedBox(height: 10),
          MasterActionButton(
            label: 'UnMap',
            icon: Icons.link_off,
            accentColor: Colors.orange.shade700,
            onPressed: onUnmap,
          ),
        ],
      ),
    );
  }
}

class ProductRateTableSection extends StatelessWidget {
  final List<Map<String, dynamic>> productList;
  final int? selectedIndex;
  final ValueChanged<int> onRowTap;

  const ProductRateTableSection({
    super.key,
    required this.productList,
    required this.selectedIndex,
    required this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    final columns = const [
      'MRP',
      'W/Rate',
      'Excise',
      'Suffered',
      'CST%',
      'LST%',
      'LST Rs.',
      'Octroi%',
      'Disc%',
      'SaleRate',
      'CostRate',
      'Margin%',
      'MarginRs',
    ];

    return Container(
      height: 165,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1040,
          child: Column(
            children: [
              Container(
                height: 28,
                color: const Color(0xFFE8E8E8),
                child: Row(
                  children: columns
                      .map((c) => _ProductRateHeaderCell(text: c))
                      .toList(),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: productList.length,
                  itemBuilder: (context, index) {
                    final p = productList[index];
                    final isSelected = selectedIndex == index;
                    final values = [
                      (p['mrp'] ?? '').toString(),
                      (p['wRate'] ?? '').toString(),
                      (p['excise'] ?? '').toString(),
                      (p['suffered'] ?? '').toString(),
                      (p['cst'] ?? '').toString(),
                      (p['lst'] ?? '').toString(),
                      (p['lstRs'] ?? '').toString(),
                      (p['octroi'] ?? '').toString(),
                      (p['disc'] ?? '').toString(),
                      (p['saleRate'] ?? '').toString(),
                      (p['costRate'] ?? '').toString(),
                      (p['margin'] ?? '').toString(),
                      (p['marginRs'] ?? '').toString(),
                    ];

                    return InkWell(
                      onTap: () => onRowTap(index),
                      child: Container(
                        height: 26,
                        color: isSelected
                            ? const Color(0xFFDDE8FF)
                            : Colors.white,
                        child: Row(
                          children: values
                              .map((v) => _ProductRateValueCell(text: v))
                              .toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductRateHeaderCell extends StatelessWidget {
  final String text;
  const _ProductRateHeaderCell({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade400)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ProductRateValueCell extends StatelessWidget {
  final String text;
  const _ProductRateValueCell({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class DoctorMasterScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const DoctorMasterScreen({super.key, this.onClose});

  @override
  State<DoctorMasterScreen> createState() => _DoctorMasterScreenState();
}

class _DoctorMasterScreenState extends State<DoctorMasterScreen> {
  final Map<String, TextEditingController> _controllers = {
    'name': TextEditingController(),
    'shortName': TextEditingController(),
    'addressC': TextEditingController(),
    'city': TextEditingController(),
    'addressR': TextEditingController(),
    'phoneC': TextEditingController(),
    'phoneR': TextEditingController(),
    'mobile': TextEditingController(),
    'email': TextEditingController(),
    'birthDate': TextEditingController(),
    'discount': TextEditingController(),
    'remarks': TextEditingController(),
  };

  final Map<String, FocusNode> _focusNodes = {
    'name': FocusNode(),
    'shortName': FocusNode(),
    'speciality': FocusNode(),
    'addressC': FocusNode(),
    'city': FocusNode(),
    'addressR': FocusNode(),
    'phoneC': FocusNode(),
    'phoneR': FocusNode(),
    'mobile': FocusNode(),
    'email': FocusNode(),
    'birthDate': FocusNode(),
    'discount': FocusNode(),
    'remarks': FocusNode(),
    'saveBtn': FocusNode(),
  };

  final List<Map<String, dynamic>> doctorList = [];
  int? _selectedIndex;
  String _speciality = '(none)';

  TextEditingController c(String key) => _controllers[key]!;
  FocusNode f(String key) => _focusNodes[key]!;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        f('name').requestFocus();
      }
    });
  }

  Future<void> _loadDoctors() async {
    setState(() {
      doctorList
        ..clear()
        ..addAll(doctors);
      _selectedIndex = null;
    });

    return Future<void>.value();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final DateTime now = DateTime.now();
    final DateTime initial =
        DateTime.tryParse(c('birthDate').text) ?? DateTime(now.year - 30, 1, 1);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      final String mm = picked.month.toString().padLeft(2, '0');
      final String dd = picked.day.toString().padLeft(2, '0');
      c('birthDate').text = '${picked.year}-$mm-$dd';
    }
  }

  void _clearForm() {
    for (final controller in _controllers.values) {
      controller.clear();
    }
    setState(() {
      _selectedIndex = null;
      _speciality = '(none)';
    });
    f('name').requestFocus();
  }

  Future<void> _saveDoctor() async {
    if (c('name').text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name required'),
          duration: Duration(milliseconds: 900),
        ),
      );
      return;
    }

    doctors.add({
      'id': _doctorSeed++,
      'name': c('name').text.trim(),
      'shortName': c('shortName').text.trim(),
      'addressC': c('addressC').text.trim(),
      'addressR': c('addressR').text.trim(),
      'phoneC': c('phoneC').text.trim(),
      'phoneR': c('phoneR').text.trim(),
      'mobile': c('mobile').text.trim(),
      'city': c('city').text.trim(),
      'speciality': _speciality,
      'email': c('email').text.trim(),
      'birthDate': c('birthDate').text.trim(),
      'discount': c('discount').text.trim(),
      'remarks': c('remarks').text.trim(),
    });
    try {
      await persistDoctorRow(doctors.last);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved locally; database error: $e'),
            duration: const Duration(milliseconds: 1400),
          ),
        );
      }
    }

    await _loadDoctors();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved Successfully'),
        duration: Duration(milliseconds: 900),
      ),
    );
    _clearForm();
  }

  void _selectDoctor(int index) {
    final d = doctorList[index];
    setState(() {
      _selectedIndex = index;
      c('name').text = d['name'] ?? '';
      c('shortName').text = d['shortName'] ?? '';
      c('addressC').text = d['addressC'] ?? '';
      c('city').text = d['city'] ?? '';
      c('addressR').text = d['addressR'] ?? '';
      c('phoneC').text = d['phoneC'] ?? '';
      c('phoneR').text = d['phoneR'] ?? '';
      c('mobile').text = d['mobile'] ?? '';
      c('email').text = d['email'] ?? '';
      c('birthDate').text = d['birthDate'] ?? '';
      c('discount').text = d['discount'] ?? '';
      c('remarks').text = d['remarks'] ?? '';
      _speciality = d['speciality'] ?? '(none)';
    });
  }

  Future<void> _editDoctor() async {
    if (_selectedIndex == null) {
      return;
    }
    final int? id = doctorList[_selectedIndex!]['id'] as int?;
    if (id == null) {
      return;
    }

    final int index = doctors.indexWhere((row) => row['id'] == id);
    if (index == -1) {
      return;
    }

    doctors[index] = {
      ...doctors[index],
      'name': c('name').text.trim(),
      'shortName': c('shortName').text.trim(),
      'addressC': c('addressC').text.trim(),
      'addressR': c('addressR').text.trim(),
      'phoneC': c('phoneC').text.trim(),
      'phoneR': c('phoneR').text.trim(),
      'mobile': c('mobile').text.trim(),
      'city': c('city').text.trim(),
      'speciality': _speciality,
      'email': c('email').text.trim(),
      'birthDate': c('birthDate').text.trim(),
      'discount': c('discount').text.trim(),
      'remarks': c('remarks').text.trim(),
    };

    try {
      await persistDoctorRow(doctors[index]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved locally; database error: $e'),
            duration: const Duration(milliseconds: 1400),
          ),
        );
      }
    }

    await _loadDoctors();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved Successfully'),
        duration: Duration(milliseconds: 900),
      ),
    );
    _clearForm();
  }

  Future<void> _deleteDoctor() async {
    if (_selectedIndex == null) {
      return;
    }
    final int? id = doctorList[_selectedIndex!]['id'] as int?;
    if (id != null) {
      doctors.removeWhere((row) => row['id'] == id);
      try {
        await deleteDoctorRow(id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed locally; database delete failed: $e'),
              duration: const Duration(milliseconds: 1400),
            ),
          );
        }
      }
      await _loadDoctors();
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deleted'),
        duration: Duration(milliseconds: 900),
      ),
    );
    _clearForm();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F1F1),
      child: Column(
        children: [
          DoctorMasterHeaderBar(onBack: widget.onClose),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double panelWidth = 120;
                final double leftWidth = (constraints.maxWidth * 0.75)
                    .clamp(0.0, constraints.maxWidth - panelWidth - 8)
                    .toDouble();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: leftWidth,
                      child: Column(
                        children: [
                          Expanded(
                            child: DoctorMasterFormPane(
                              controllers: _controllers,
                              focusNodes: _focusNodes,
                              speciality: _speciality,
                              onSpecialityChanged: (value) =>
                                  setState(() => _speciality = value),
                              onPickBirthDate: _pickBirthDate,
                              onFinalSubmit: _saveDoctor,
                            ),
                          ),
                          DoctorMasterTableSection(
                            doctorList: doctorList,
                            selectedIndex: _selectedIndex,
                            onRowTap: _selectDoctor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: panelWidth,
                      child: DoctorMasterActionPanel(
                        onEdit: _editDoctor,
                        onDelete: _deleteDoctor,
                        onSave: _saveDoctor,
                        onClear: _clearForm,
                        saveFocusNode: f('saveBtn'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DoctorMasterHeaderBar extends StatelessWidget {
  final VoidCallback? onBack;
  const DoctorMasterHeaderBar({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB0302D), Color(0xFF8B2FA1), Color(0xFF4A4FB5)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Doctor Master',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30 / 2.2,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
          if (onBack != null)
            InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(3),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Icon(Icons.close, color: Colors.white70, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

class DoctorMasterFormPane extends StatelessWidget {
  final Map<String, TextEditingController> controllers;
  final Map<String, FocusNode> focusNodes;
  final String speciality;
  final ValueChanged<String> onSpecialityChanged;
  final VoidCallback onPickBirthDate;
  final VoidCallback onFinalSubmit;

  const DoctorMasterFormPane({
    super.key,
    required this.controllers,
    required this.focusNodes,
    required this.speciality,
    required this.onSpecialityChanged,
    required this.onPickBirthDate,
    required this.onFinalSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Column(
        children: [
          _DoctorFormRow(
            label: 'Name',
            field: _textInput(
              context: context,
              controller: controllers['name'],
              focusNode: focusNodes['name'],
              nextFocusNode: focusNodes['shortName'],
              autofocus: true,
            ),
          ),
          _DoctorFormRow(
            label: 'Short Name',
            field: _textInput(
              context: context,
              controller: controllers['shortName'],
              focusNode: focusNodes['shortName'],
              nextFocusNode: focusNodes['speciality'],
            ),
          ),
          _DoctorFormRow(
            label: 'Speciality',
            field: _dropdown(
              context: context,
              value: speciality,
              values: const [
                '(none)',
                'Cardiology',
                'ENT',
                'General',
                'Orthopedic',
                'Pediatric',
              ],
              onChanged: onSpecialityChanged,
              focusNode: focusNodes['speciality'],
              nextFocusNode: focusNodes['addressC'],
            ),
          ),
          _DoctorFormRow(
            label: 'Address (C)',
            topAligned: true,
            field: _textInput(
              context: context,
              controller: controllers['addressC'],
              focusNode: focusNodes['addressC'],
              nextFocusNode: focusNodes['city'],
              maxLines: 2,
            ),
          ),
          _DoctorFormRow(
            label: 'City',
            field: _textInput(
              context: context,
              controller: controllers['city'],
              focusNode: focusNodes['city'],
              nextFocusNode: focusNodes['addressR'],
            ),
          ),
          _DoctorFormRow(
            label: 'Address (R)',
            topAligned: true,
            field: _textInput(
              context: context,
              controller: controllers['addressR'],
              focusNode: focusNodes['addressR'],
              nextFocusNode: focusNodes['phoneC'],
              maxLines: 2,
            ),
          ),
          _DoctorFormRow(
            label: 'Phone (C)',
            field: _textInput(
              context: context,
              controller: controllers['phoneC'],
              focusNode: focusNodes['phoneC'],
              nextFocusNode: focusNodes['phoneR'],
            ),
          ),
          _DoctorFormRow(
            label: 'Phone (R)',
            field: _textInput(
              context: context,
              controller: controllers['phoneR'],
              focusNode: focusNodes['phoneR'],
              nextFocusNode: focusNodes['mobile'],
            ),
          ),
          _DoctorFormRow(
            label: 'Mobile',
            field: _textInput(
              context: context,
              controller: controllers['mobile'],
              focusNode: focusNodes['mobile'],
              nextFocusNode: focusNodes['email'],
            ),
          ),
          _DoctorFormRow(
            label: 'E-Mail',
            field: _textInput(
              context: context,
              controller: controllers['email'],
              focusNode: focusNodes['email'],
              nextFocusNode: focusNodes['birthDate'],
            ),
          ),
          _DoctorFormRow(
            label: 'Birth Date',
            field: _dateInput(
              context: context,
              controller: controllers['birthDate'],
              focusNode: focusNodes['birthDate'],
              nextFocusNode: focusNodes['discount'],
              onPickBirthDate: onPickBirthDate,
            ),
          ),
          _DoctorFormRow(
            label: 'Discount',
            field: _textInput(
              context: context,
              controller: controllers['discount'],
              focusNode: focusNodes['discount'],
              nextFocusNode: focusNodes['remarks'],
              suffix: const Text('%', style: TextStyle(fontSize: 12)),
            ),
          ),
          _DoctorFormRow(
            label: 'Remarks',
            topAligned: true,
            field: _textInput(
              context: context,
              controller: controllers['remarks'],
              focusNode: focusNodes['remarks'],
              maxLines: 2,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onFinalSubmit(),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _textInput({
    required BuildContext context,
    TextEditingController? controller,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    bool autofocus = false,
    int maxLines = 1,
    Widget? suffix,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    final bool multiline = maxLines > 1;
    return SizedBox(
      height: multiline ? 54 : 28,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        maxLines: maxLines,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted ?? (_) => nextFocus(context, nextFocusNode),
        style: const TextStyle(fontSize: 12.5),
        decoration: InputDecoration(
          isDense: true,
          suffixIcon: suffix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: suffix,
                ),
          suffixIconConstraints: const BoxConstraints(
            minHeight: 18,
            minWidth: 18,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: multiline ? 7 : 6,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(color: Colors.blueGrey.shade400, width: 1),
          ),
        ),
      ),
    );
  }

  static Widget _dateInput({
    required BuildContext context,
    required TextEditingController? controller,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    required VoidCallback onPickBirthDate,
  }) {
    return SizedBox(
      height: 30,
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter) {
            onPickBirthDate();
            nextFocus(context, nextFocusNode);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: controller,
          readOnly: true,
          textInputAction: TextInputAction.next,
          onTap: onPickBirthDate,
          onSubmitted: (_) => nextFocus(context, nextFocusNode),
          style: const TextStyle(fontSize: 12.5),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today_outlined, size: 15),
              padding: EdgeInsets.zero,
              onPressed: onPickBirthDate,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(color: Colors.blueGrey.shade400, width: 1),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _dropdown({
    required BuildContext context,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
  }) {
    return SizedBox(
      height: 28,
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: (_, event) =>
            handleEnterToNext(context, nextFocusNode, event),
        child: DropdownButtonFormField<String>(
          value: values.contains(value) ? value : values.first,
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          style: const TextStyle(fontSize: 12.5, color: Colors.black87),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(color: Colors.grey.shade500, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(color: Colors.blueGrey.shade400, width: 1),
            ),
          ),
          items: values
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: const TextStyle(fontSize: 12.5)),
                ),
              )
              .toList(),
          onChanged: (selected) {
            if (selected != null) {
              onChanged(selected);
            }
          },
        ),
      ),
    );
  }
}

class _DoctorFormRow extends StatelessWidget {
  final String label;
  final Widget field;
  final bool topAligned;

  const _DoctorFormRow({
    required this.label,
    required this.field,
    this.topAligned = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: topAligned
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 82,
            child: Padding(
              padding: topAligned
                  ? const EdgeInsets.only(top: 4)
                  : EdgeInsets.zero,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          Expanded(child: field),
        ],
      ),
    );
  }
}

class DoctorMasterActionPanel extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final FocusNode? saveFocusNode;

  const DoctorMasterActionPanel({
    super.key,
    required this.onEdit,
    required this.onDelete,
    required this.onSave,
    required this.onClear,
    this.saveFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F1F1),
      padding: const EdgeInsets.fromLTRB(8, 10, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          MasterActionButton(
            label: 'Edit',
            icon: Icons.edit,
            accentColor: Colors.grey.shade700,
            onPressed: onEdit,
          ),
          const SizedBox(height: 10),
          MasterActionButton(
            label: 'Delete',
            icon: Icons.delete_outline,
            accentColor: Colors.red.shade600,
            onPressed: onDelete,
          ),
          const SizedBox(height: 10),
          MasterActionButton(
            label: 'Save',
            icon: Icons.save,
            accentColor: Colors.green.shade700,
            onPressed: onSave,
            focusNode: saveFocusNode,
          ),
          const SizedBox(height: 10),
          MasterActionButton(
            label: 'Clear',
            icon: Icons.cleaning_services,
            accentColor: Colors.blueGrey.shade600,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class DoctorMasterTableSection extends StatelessWidget {
  final List<Map<String, dynamic>> doctorList;
  final int? selectedIndex;
  final ValueChanged<int> onRowTap;

  const DoctorMasterTableSection({
    super.key,
    required this.doctorList,
    required this.selectedIndex,
    required this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        children: [
          Container(
            height: 28,
            color: const Color(0xFFE8E8E8),
            child: const Row(
              children: [
                _TableHeaderCell(text: 'Name', flex: 3),
                _TableHeaderCell(text: 'Mobile', flex: 2),
                _TableHeaderCell(text: 'City', flex: 2),
                _TableHeaderCell(text: 'Speciality', flex: 2),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: doctorList.length,
              itemBuilder: (context, index) {
                final doctor = doctorList[index];
                final bool isSelected = selectedIndex == index;
                return InkWell(
                  onTap: () => onRowTap(index),
                  child: Container(
                    height: 26,
                    color: isSelected ? const Color(0xFFDDE8FF) : Colors.white,
                    child: Row(
                      children: [
                        _TableValueCell(
                          text: (doctor['name'] ?? '').toString(),
                          flex: 3,
                        ),
                        _TableValueCell(
                          text: (doctor['mobile'] ?? '').toString(),
                          flex: 2,
                        ),
                        _TableValueCell(
                          text: (doctor['city'] ?? '').toString(),
                          flex: 2,
                        ),
                        _TableValueCell(
                          text: (doctor['speciality'] ?? '').toString(),
                          flex: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AccountModuleScreen extends StatefulWidget {
  final String title;
  final VoidCallback? onClose;

  const AccountModuleScreen({super.key, required this.title, this.onClose});

  @override
  State<AccountModuleScreen> createState() => _AccountModuleScreenState();
}

class _AccountModuleScreenState extends State<AccountModuleScreen> {
  // Receipt / Payment shared form
  final _voucherNo = TextEditingController();
  final _date = TextEditingController();
  final _account = TextEditingController();
  final _paymentMode = TextEditingController(text: 'Cash');
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _remarks = TextEditingController();
  final _voucherNoFocus = FocusNode();
  final _dateFocus = FocusNode();
  final _accountFocus = FocusNode();
  final _paymentModeFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _referenceFocus = FocusNode();
  final _remarksFocus = FocusNode();
  int? _selectedReceiptPaymentIndex;
  int? _editingReceiptPaymentId;

  // Journal Voucher
  final _jvNo = TextEditingController();
  final _jvDate = TextEditingController();
  final _jvNarration = TextEditingController();
  final _jvAccount = TextEditingController();
  final _jvDebit = TextEditingController();
  final _jvCredit = TextEditingController();
  final List<Map<String, dynamic>> _journalLines = [];
  int? _selectedJvLine;
  int? _selectedJvIndex;

  // Filters
  final _fromDate = TextEditingController();
  final _toDate = TextEditingController();
  final _filterAccount = TextEditingController();
  final _interestRate = TextEditingController(text: '12');
  final _expenseType = TextEditingController();
  final _interestParty = TextEditingController();
  final _interestDuration = TextEditingController(text: '30');
  final _physicalCashCount = TextEditingController();
  final _forexRate = TextEditingController(text: '83.0');

  String _moduleType = '';
  String _gstOutputFilter = 'All'; // All | GST Local | IGST | GST Exempt
  String _rpKindFilter = 'All'; // All | Receipt | Payment
  String _rpModeFilter = 'All'; // All | Cash | UPI | Bank
  Map<String, dynamic>? _selectedAvpRow;

  @override
  void initState() {
    super.initState();
    _moduleType = widget.title;
    _date.text = _today();
    _jvDate.text = _today();
    _fromDate.text = _today();
    _toDate.text = _today();
    _voucherNo.text = _nextNo(_moduleType);
    _jvNo.text = _nextNo('Journal Voucher');
  }

  @override
  void dispose() {
    _voucherNo.dispose();
    _date.dispose();
    _account.dispose();
    _paymentMode.dispose();
    _amount.dispose();
    _reference.dispose();
    _remarks.dispose();
    _voucherNoFocus.dispose();
    _dateFocus.dispose();
    _accountFocus.dispose();
    _paymentModeFocus.dispose();
    _amountFocus.dispose();
    _referenceFocus.dispose();
    _remarksFocus.dispose();
    _jvNo.dispose();
    _jvDate.dispose();
    _jvNarration.dispose();
    _jvAccount.dispose();
    _jvDebit.dispose();
    _jvCredit.dispose();
    _fromDate.dispose();
    _toDate.dispose();
    _filterAccount.dispose();
    _interestRate.dispose();
    _expenseType.dispose();
    _interestParty.dispose();
    _interestDuration.dispose();
    _physicalCashCount.dispose();
    _forexRate.dispose();
    super.dispose();
  }

  String _today() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  int _nextId(String key) {
    final current = accountModuleSeed[key] ?? 1;
    accountModuleSeed[key] = current + 1;
    return current;
  }

  String _nextNo(String key) {
    final value = _nextId(key);
    return '${key.split(' ').first.substring(0, 1).toUpperCase()}-$value';
  }

  double _openingBalanceForAccountName(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return 0;
    for (final a in accounts) {
      if ((a['name'] ?? '').toString().trim().toLowerCase() == n) {
        final ob = a['openingBalance'];
        if (ob is num) return ob.toDouble();
        return double.tryParse(ob?.toString() ?? '0') ?? 0;
      }
    }
    return 0;
  }

  double _postedMovementForAccountName(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return 0;
    double debit = 0;
    double credit = 0;
    for (final r in _records('Receipt')) {
      if ((r['account'] ?? '').toString().trim().toLowerCase() == n) {
        debit += (r['amount'] as num?)?.toDouble() ?? 0;
      }
    }
    for (final r in _records('Payment')) {
      if ((r['account'] ?? '').toString().trim().toLowerCase() == n) {
        credit += (r['amount'] as num?)?.toDouble() ?? 0;
      }
    }
    return debit - credit;
  }

  /// Same convention as Account Balance: opening + receipts − payments.
  double _salesInvoiceTotalForParty(String party) {
    final n = party.trim().toLowerCase();
    if (n.isEmpty) return 0;
    var t = 0.0;
    for (final inv in salesInvoiceRecords) {
      if ((inv['party'] ?? '').toString().trim().toLowerCase() == n) {
        t += (inv['grandTotal'] as num?)?.toDouble() ??
            double.tryParse('${inv['grandTotal']}') ??
            0;
      }
    }
    return t;
  }

  double _purchaseBillTotalForParty(String party) {
    final n = party.trim().toLowerCase();
    if (n.isEmpty) return 0;
    var t = 0.0;
    for (final inv in purchaseBillRecords) {
      if ((inv['party'] ?? '').toString().trim().toLowerCase() == n) {
        t += (inv['grandTotal'] as num?)?.toDouble() ??
            double.tryParse('${inv['grandTotal']}') ??
            0;
      }
    }
    return t;
  }

  /// Opening + receipts/payments + sales exposure − purchase exposure.
  double _closingBookForParty(String party) {
    return _openingBalanceForAccountName(party) +
        _postedMovementForAccountName(party) +
        _salesInvoiceTotalForParty(party) -
        _purchaseBillTotalForParty(party);
  }

  bool _dateInRange(String? dateStr, String from, String to) {
    if (dateStr == null || dateStr.toString().isEmpty) return false;
    final d = dateStr.toString();
    return d.compareTo(from) >= 0 && d.compareTo(to) <= 0;
  }

  List<Map<String, dynamic>> _records(String key) {
    return accountModuleRecords.putIfAbsent(key, () => <Map<String, dynamic>>[]);
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(milliseconds: 900)),
    );
  }

  Future<void> _pickDate(TextEditingController controller) async {
    DateTime initial = DateTime.now();
    final parsed = DateTime.tryParse(controller.text.trim());
    if (parsed != null) {
      initial = parsed;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');
    controller.text = '${picked.year}-$mm-$dd';
    setState(() {});
  }

  Widget _dateInput(
    TextEditingController controller, {
    FocusNode? focusNode,
    VoidCallback? onSubmitted,
  }) {
    return SizedBox(
      height: 34,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: true,
        onTap: () => _pickDate(controller),
        onSubmitted: (_) => onSubmitted?.call(),
        decoration: InputDecoration(
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_month, size: 16),
            onPressed: () => _pickDate(controller),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFFCBD5E1), width: 1),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFFCBD5E1), width: 1),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFF6366F1), width: 1.6),
          ),
        ),
      ),
    );
  }

  Widget _moduleShell({required String title, required Widget child}) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF0EA5E9)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3730A3).withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                  ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4F46E5), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _clearReceiptPaymentForm() {
    _account.clear();
    _amount.clear();
    _reference.clear();
    _remarks.clear();
    _expenseType.clear();
    _date.text = _today();
    _paymentMode.text = 'Cash';
    _editingReceiptPaymentId = null;
    _selectedReceiptPaymentIndex = null;
    _voucherNo.text = _nextNo(_moduleType);
  }

  void _saveReceiptPayment() {
    if (_account.text.trim().isEmpty) {
      _showMessage('Account is required');
      _accountFocus.requestFocus();
      return;
    }
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) {
      _showMessage('Amount must be greater than 0');
      _amountFocus.requestFocus();
      return;
    }
    final records = _records(_moduleType);
    final row = <String, dynamic>{
      'id': _editingReceiptPaymentId ?? _nextId(_moduleType),
      'voucherNo': _voucherNo.text.trim(),
      'date': _date.text.trim(),
      'account': _account.text.trim(),
      'mode': _paymentMode.text.trim(),
      'amount': amount,
      'reference': _reference.text.trim(),
      'remarks': _remarks.text.trim(),
      'status': 'Success',
      if (_moduleType == 'Payment') 'expenseType': _expenseType.text.trim(),
    };
    setState(() {
      if (_editingReceiptPaymentId != null) {
        final i = records.indexWhere((x) => x['id'] == _editingReceiptPaymentId);
        if (i != -1) records[i] = row;
      } else {
        records.insert(0, row);
      }
      _clearReceiptPaymentForm();
    });
    unawaited(persistAccountModuleSnapshot());
    _showMessage('Saved');
  }

  void _editReceiptPayment() {
    final records = _records(_moduleType);
    if (_selectedReceiptPaymentIndex == null ||
        _selectedReceiptPaymentIndex! >= records.length) {
      _showMessage('Select a row to edit');
      return;
    }
    final row = records[_selectedReceiptPaymentIndex!];
    setState(() {
      _editingReceiptPaymentId = row['id'] as int?;
      _voucherNo.text = (row['voucherNo'] ?? '').toString();
      _date.text = (row['date'] ?? '').toString();
      _account.text = (row['account'] ?? '').toString();
      _paymentMode.text = (row['mode'] ?? '').toString();
      _amount.text = (row['amount'] ?? '').toString();
      _reference.text = (row['reference'] ?? '').toString();
      _remarks.text = (row['remarks'] ?? '').toString();
      _expenseType.text = (row['expenseType'] ?? '').toString();
    });
  }

  void _deleteReceiptPayment() {
    final records = _records(_moduleType);
    if (_selectedReceiptPaymentIndex == null ||
        _selectedReceiptPaymentIndex! >= records.length) {
      _showMessage('Select a row to delete');
      return;
    }
    setState(() {
      records.removeAt(_selectedReceiptPaymentIndex!);
      _clearReceiptPaymentForm();
    });
    unawaited(persistAccountModuleSnapshot());
    _showMessage('Deleted');
  }

  void _addJournalLine() {
    if (_jvAccount.text.trim().isEmpty) {
      _showMessage('Account is required in journal line');
      return;
    }
    final d = double.tryParse(_jvDebit.text.trim()) ?? 0;
    final c = double.tryParse(_jvCredit.text.trim()) ?? 0;
    if (d <= 0 && c <= 0) {
      _showMessage('Enter debit or credit amount');
      return;
    }
    setState(() {
      _journalLines.add({
        'account': _jvAccount.text.trim(),
        'debit': d,
        'credit': c,
      });
      _jvAccount.clear();
      _jvDebit.clear();
      _jvCredit.clear();
    });
  }

  void _removeJournalLine() {
    if (_selectedJvLine == null || _selectedJvLine! < 0 || _selectedJvLine! >= _journalLines.length) {
      _showMessage('Select a line in the grid, then remove');
      return;
    }
    setState(() {
      _journalLines.removeAt(_selectedJvLine!);
      _selectedJvLine = null;
    });
  }

  double _jvLineDr(Map<String, dynamic> row) {
    final v = row['debit'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  double _jvLineCr(Map<String, dynamic> row) {
    final v = row['credit'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  void _saveJournalVoucher() {
    if (_journalLines.isEmpty) {
      _showMessage('Add journal lines first');
      return;
    }
    final debit = _journalLines.fold<double>(0, (sum, row) => sum + _jvLineDr(row));
    final credit = _journalLines.fold<double>(0, (sum, row) => sum + _jvLineCr(row));
    if ((debit - credit).abs() > 0.001) {
      _showMessage('Debit and Credit must be equal');
      return;
    }
    final records = _records('Journal Voucher');
    setState(() {
      records.insert(0, {
        'id': _nextId('Journal Voucher'),
        'voucherNo': _jvNo.text.trim(),
        'date': _jvDate.text.trim(),
        'narration': _jvNarration.text.trim(),
        'debit': debit,
        'credit': credit,
        'status': 'Success',
        'lines': _journalLines.map((e) => Map<String, dynamic>.from(e)).toList(),
      });
      _journalLines.clear();
      _jvNo.text = _nextNo('Journal Voucher');
      _jvDate.text = _today();
      _jvNarration.clear();
      _selectedJvIndex = null;
      _selectedJvLine = null;
    });
    unawaited(persistAccountModuleSnapshot());
    _showMessage('Journal Voucher saved');
  }

  List<Map<String, dynamic>> _salesRegisterRows() {
    return salesInvoiceRecords
        .map(
          (e) => {
            'invoiceNo': e['billNo'] ?? '',
            'date': e['date'] ?? '',
            'customer': e['party'] ?? '',
            'amount': (e['grandTotal'] ?? 0).toString(),
            'status': 'Success',
          },
        )
        .toList();
  }

  List<Map<String, dynamic>> _purchaseRegisterRows() {
    return purchaseBillRecords
        .map(
          (e) => {
            'billNo': e['billNo'] ?? '',
            'date': e['date'] ?? '',
            'supplier': e['party'] ?? '',
            'amount': (e['grandTotal'] ?? 0).toString(),
          },
        )
        .toList();
  }

  Widget _receiptScreen() {
    final rows = _records('Receipt');
    final party = _account.text.trim();
    final currentAmt = double.tryParse(_amount.text.trim()) ?? 0;
    final book = _closingBookForParty(party);
    final after = book + currentAmt;
    return Container(
      color: const Color(0xFFF0FDF4),
      child: Column(
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF166534),
            ),
            child: Row(
              children: [
                const Icon(Icons.call_received, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Receipt (Cash / Bank / UPI)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionCard(
                          title: 'Receipt voucher',
                          child: Column(
                            children: [
                              _CompactFormRow(
                                label: 'Voucher No',
                                field: _compactInput(
                                  controller: _voucherNo,
                                  focusNode: _voucherNoFocus,
                                  onSubmitted: (_) => nextFocus(context, _dateFocus),
                                ),
                              ),
                              _CompactFormRow(
                                label: 'Date',
                                field: _dateInput(
                                  _date,
                                  focusNode: _dateFocus,
                                  onSubmitted: () => nextFocus(context, _accountFocus),
                                ),
                              ),
                              _CompactFormRow(
                                label: 'Party',
                                field: _compactInput(
                                  controller: _account,
                                  focusNode: _accountFocus,
                                  hintText: 'Customer / supplier name',
                                  onSubmitted: (_) => setState(() {}),
                                ),
                              ),
                              _CompactFormRow(
                                label: 'Mode',
                                field: _compactDropdown(
                                  value: _paymentMode.text.isEmpty ? 'Cash' : _paymentMode.text,
                                  values: const ['Cash', 'UPI', 'Bank'],
                                  onChanged: (v) => setState(() => _paymentMode.text = v),
                                ),
                              ),
                              _CompactFormRow(
                                label: 'Amount',
                                field: _compactInput(
                                  controller: _amount,
                                  focusNode: _amountFocus,
                                  keyboardType: TextInputType.number,
                                  onSubmitted: (_) => setState(() {}),
                                ),
                              ),
                              _CompactFormRow(
                                label: 'Reference',
                                field: _compactInput(
                                  controller: _reference,
                                  focusNode: _referenceFocus,
                                  onSubmitted: (_) => nextFocus(context, _remarksFocus),
                                ),
                              ),
                              _CompactFormRow(
                                label: 'Remarks',
                                topAligned: true,
                                field: _compactInput(
                                  controller: _remarks,
                                  focusNode: _remarksFocus,
                                  maxLines: 2,
                                  onSubmitted: (_) => _saveReceiptPayment(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _SectionCard(
                          title: 'Running balance (party)',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Book balance: ${book.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'After this receipt: ${after.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF166534),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (party.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Enter party name to compute balance from Account Master opening + posted vouchers.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _saveReceiptPayment,
                              icon: const Icon(Icons.save, size: 16),
                              label: const Text('Save'),
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF166534)),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => setState(_clearReceiptPaymentForm),
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Clear'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _editReceiptPayment,
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit row'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _deleteReceiptPayment,
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                    child: _SectionCard(
                      title: 'Receipt register',
                      expandChild: true,
                      contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: _SimpleTable(
                        headers: const ['Voucher', 'Date', 'Party', 'Mode', 'Amount', 'Status'],
                        selectedIndex: _selectedReceiptPaymentIndex,
                        rows: rows
                            .map(
                              (r) => [
                                (r['voucherNo'] ?? '').toString(),
                                (r['date'] ?? '').toString(),
                                (r['account'] ?? '').toString(),
                                (r['mode'] ?? '').toString(),
                                (r['amount'] ?? '').toString(),
                                (r['status'] ?? 'Pending').toString(),
                              ],
                            )
                            .toList(),
                        onRowTap: (index) => setState(() => _selectedReceiptPaymentIndex = index),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentScreen() {
    final rows = _records('Payment');
    return Container(
      color: const Color(0xFFFFF7ED),
      child: Column(
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF9A3412), Color(0xFFEA580C)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.outbound, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Payment (outflow)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _SectionCard(
                          title: 'Payment details',
                          child: Column(
                            children: [
                              _CompactFormRow(
                                label: 'Voucher No',
                                field: _compactInput(controller: _voucherNo, focusNode: _voucherNoFocus),
                              ),
                              _CompactFormRow(
                                label: 'Date',
                                field: _dateInput(_date, focusNode: _dateFocus),
                              ),
                              _CompactFormRow(
                                label: 'Paid to',
                                field: _compactInput(
                                  controller: _account,
                                  focusNode: _accountFocus,
                                  hintText: 'Party or expense payee',
                                ),
                              ),
                              _CompactFormRow(
                                label: 'Expense type',
                                field: _compactDropdown(
                                  value: _expenseType.text.isEmpty ? 'General' : _expenseType.text,
                                  values: const ['General', 'Salary', 'Rent', 'Utilities', 'Purchase', 'Other'],
                                  onChanged: (v) => setState(() => _expenseType.text = v),
                                ),
                              ),
                              _CompactFormRow(
                                label: 'Mode',
                                field: _compactDropdown(
                                  value: _paymentMode.text.isEmpty ? 'Cash' : _paymentMode.text,
                                  values: const ['Cash', 'UPI', 'Bank'],
                                  onChanged: (v) => setState(() => _paymentMode.text = v),
                                ),
                              ),
                              _CompactFormRow(
                                label: 'Amount',
                                field: _compactInput(
                                  controller: _amount,
                                  focusNode: _amountFocus,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              _CompactFormRow(
                                label: 'Reference',
                                field: _compactInput(controller: _reference, focusNode: _referenceFocus),
                              ),
                              _CompactFormRow(
                                label: 'Remarks',
                                topAligned: true,
                                field: _compactInput(controller: _remarks, focusNode: _remarksFocus, maxLines: 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SectionCard(
                          title: 'Summary',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total payments (saved): ${rows.fold<double>(0, (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0)).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Payments reduce the party balance in the same ledger used for receipts.',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _saveReceiptPayment,
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text('Save payment'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => setState(_clearReceiptPaymentForm),
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _editReceiptPayment,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _deleteReceiptPayment,
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _SectionCard(
                      title: 'Payment register',
                      expandChild: true,
                      contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: _SimpleTable(
                        headers: const ['Voucher', 'Date', 'Paid to', 'Mode', 'Expense', 'Amount'],
                        selectedIndex: _selectedReceiptPaymentIndex,
                        rows: rows
                            .map(
                              (r) => [
                                (r['voucherNo'] ?? '').toString(),
                                (r['date'] ?? '').toString(),
                                (r['account'] ?? '').toString(),
                                (r['mode'] ?? '').toString(),
                                (r['expenseType'] ?? '').toString(),
                                (r['amount'] ?? '').toString(),
                              ],
                            )
                            .toList(),
                        onRowTap: (index) => setState(() => _selectedReceiptPaymentIndex = index),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _journalVoucherScreen() {
    final saved = _records('Journal Voucher');
    final debit = _journalLines.fold<double>(0, (sum, row) => sum + _jvLineDr(row));
    final credit = _journalLines.fold<double>(0, (sum, row) => sum + _jvLineCr(row));
    final diff = debit - credit;
    final balanced = diff.abs() < 0.001;

    Widget sideMetric(String label, String value, {Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: valueColor ?? const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFFF4F4F5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF27272A),
              boxShadow: [
                BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance, color: Color(0xFFE4E4E7), size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Journal voucher',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Color(0xFFA1A1AA), size: 18),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Material(
                          elevation: 1,
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Voucher header',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155)),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _CompactFormRow(
                                        label: 'Voucher no',
                                        field: _compactInput(controller: _jvNo),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 200,
                                      child: _CompactFormRow(
                                        label: 'Date',
                                        field: _dateInput(_jvDate),
                                      ),
                                    ),
                                  ],
                                ),
                                _CompactFormRow(
                                  label: 'Narration',
                                  topAligned: true,
                                  field: _compactInput(controller: _jvNarration, maxLines: 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          flex: 3,
                          child: Material(
                            elevation: 1,
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Journal lines',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155)),
                                      ),
                                      const Spacer(),
                                      FilledButton.icon(
                                        onPressed: _addJournalLine,
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text('Add line'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFF27272A),
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: _removeJournalLine,
                                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                                        label: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: _compactInput(controller: _jvAccount, hintText: 'Ledger account'),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _compactInput(
                                          controller: _jvDebit,
                                          hintText: 'Debit',
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _compactInput(
                                          controller: _jvCredit,
                                          hintText: 'Credit',
                                          keyboardType: TextInputType.number,
                                          onSubmitted: (_) => _addJournalLine(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(height: 1),
                                  Expanded(
                                    child: _SimpleTable(
                                      headers: const ['Account', 'Debit', 'Credit'],
                                      selectedIndex: _selectedJvLine,
                                      rows: _journalLines
                                          .map(
                                            (r) => [
                                              (r['account'] ?? '').toString(),
                                              _jvLineDr(r).toStringAsFixed(2),
                                              _jvLineCr(r).toStringAsFixed(2),
                                            ],
                                          )
                                          .toList(),
                                      onRowTap: (index) => setState(() => _selectedJvLine = index),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Working totals — Debit: ${debit.toStringAsFixed(2)}  Credit: ${credit.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          flex: 2,
                          child: Material(
                            elevation: 1,
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFFFAFAFA),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Posted vouchers',
                                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155)),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () {
                                          if (_selectedJvIndex == null || _selectedJvIndex! >= saved.length) {
                                            _showMessage('Select a posted voucher to delete');
                                            return;
                                          }
                                          setState(() => saved.removeAt(_selectedJvIndex!));
                                        },
                                        icon: const Icon(Icons.delete_outline, size: 18),
                                        label: const Text('Delete selected'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: _SimpleTable(
                                      headers: const ['Voucher', 'Date', 'Narration', 'Debit', 'Credit', 'Status'],
                                      selectedIndex: _selectedJvIndex,
                                      rows: saved
                                          .map(
                                            (r) => [
                                              (r['voucherNo'] ?? '').toString(),
                                              (r['date'] ?? '').toString(),
                                              (r['narration'] ?? '').toString(),
                                              (r['debit'] ?? '').toString(),
                                              (r['credit'] ?? '').toString(),
                                              (r['status'] ?? '').toString(),
                                            ],
                                          )
                                          .toList(),
                                      onRowTap: (index) => setState(() => _selectedJvIndex = index),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 232,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Material(
                          elevation: 2,
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFF18181B),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Trial balance',
                                  style: TextStyle(color: Color(0xFFE4E4E7), fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                                const Divider(color: Color(0xFF3F3F46)),
                                sideMetric('Total debit', debit.toStringAsFixed(2), valueColor: const Color(0xFFFCA5A5)),
                                sideMetric('Total credit', credit.toStringAsFixed(2), valueColor: const Color(0xFF93C5FD)),
                                const Divider(color: Color(0xFF3F3F46)),
                                sideMetric(
                                  'Difference (Dr − Cr)',
                                  diff.abs() < 0.001 ? '0.00' : diff.toStringAsFixed(2),
                                  valueColor: balanced ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      balanced ? Icons.check_circle : Icons.error_outline,
                                      color: balanced ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        balanced ? 'Balanced — you may post.' : 'Debit must equal credit before post.',
                                        style: const TextStyle(color: Color(0xFFD4D4D8), fontSize: 11.5, height: 1.25),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: balanced ? _saveJournalVoucher : () => _showMessage('Balance debit and credit first'),
                          icon: const Icon(Icons.save_as, size: 18),
                          label: const Text('Post voucher'),
                          style: FilledButton.styleFrom(
                            backgroundColor: balanced ? const Color(0xFF15803D) : const Color(0xFF52525B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _journalLines.clear();
                              _jvNo.text = _nextNo('Journal Voucher');
                              _jvDate.text = _today();
                              _jvNarration.clear();
                              _jvAccount.clear();
                              _jvDebit.clear();
                              _jvCredit.clear();
                              _selectedJvLine = null;
                            });
                          },
                          icon: const Icon(Icons.restart_alt, size: 18),
                          label: const Text('Clear working lines'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _rpCombinedRows() {
    final out = <Map<String, dynamic>>[];
    for (final r in _records('Receipt')) {
      out.add({
        'date': r['date'],
        'party': r['account'],
        'mode': r['mode'],
        'amount': r['amount'],
        'kind': 'Receipt',
      });
    }
    for (final r in _records('Payment')) {
      out.add({
        'date': r['date'],
        'party': r['account'],
        'mode': r['mode'],
        'amount': r['amount'],
        'kind': 'Payment',
      });
    }
    out.sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
    return out;
  }

  Widget _receiptPaymentRegisterScreen() {
    final partyQ = _filterAccount.text.trim().toLowerCase();
    final filtered = _rpCombinedRows().where((e) {
      if (!_dateInRange((e['date'] ?? '').toString(), _fromDate.text, _toDate.text)) {
        return false;
      }
      if (_rpKindFilter != 'All' && (e['kind'] ?? '').toString() != _rpKindFilter) {
        return false;
      }
      if (_rpModeFilter != 'All' && (e['mode'] ?? '').toString() != _rpModeFilter) {
        return false;
      }
      if (partyQ.isNotEmpty && !(e['party'] ?? '').toString().toLowerCase().contains(partyQ)) {
        return false;
      }
      return true;
    }).toList();
    final totReceipt = filtered
        .where((e) => e['kind'] == 'Receipt')
        .fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
    final totPayment = filtered
        .where((e) => e['kind'] == 'Payment')
        .fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));

    return Container(
      color: const Color(0xFFF1F5F9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 6, color: const Color(0xFF0369A1)),
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: const Color(0xFF0C4A6E),
                  child: Row(
                    children: [
                      const Text(
                        'Receipt / payment register',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const Spacer(),
                      if (widget.onClose != null)
                        IconButton(
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Material(
                          borderRadius: BorderRadius.circular(12),
                          elevation: 1,
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Filters',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: _dateInput(_fromDate)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _dateInput(_toDate)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _compactDropdown(
                                        value: _rpKindFilter,
                                        values: const ['All', 'Receipt', 'Payment'],
                                        onChanged: (v) => setState(() => _rpKindFilter = v),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _compactDropdown(
                                        value: _rpModeFilter,
                                        values: const ['All', 'Cash', 'UPI', 'Bank'],
                                        onChanged: (v) => setState(() => _rpModeFilter = v),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _compactInput(
                                  controller: _filterAccount,
                                  hintText: 'Party contains…',
                                  onSubmitted: (_) => setState(() {}),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton(
                                    onPressed: () => setState(() {}),
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0369A1)),
                                    child: const Text('Apply filters'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Material(
                            borderRadius: BorderRadius.circular(12),
                            elevation: 1,
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Register lines',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: _SimpleTable(
                                      headers: const ['Date', 'Party', 'Mode', 'Amount'],
                                      selectedIndex: null,
                                      rows: filtered
                                          .map((e) {
                                            final raw = (e['amount'] as num?)?.toDouble() ?? 0;
                                            final signed = e['kind'] == 'Payment' ? -raw : raw;
                                            return [
                                              (e['date'] ?? '').toString(),
                                              (e['party'] ?? '').toString(),
                                              (e['mode'] ?? '').toString(),
                                              signed.toStringAsFixed(2),
                                            ];
                                          })
                                          .toList(),
                                      onRowTap: (_) {},
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 220,
                    child: Column(
                      children: [
                        Material(
                          borderRadius: BorderRadius.circular(12),
                          elevation: 2,
                          color: const Color(0xFF0F172A),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Summary',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                ),
                                const Divider(color: Color(0xFF334155)),
                                Text(
                                  'Total receipts',
                                  style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 11),
                                ),
                                Text(
                                  totReceipt.toStringAsFixed(2),
                                  style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 20, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Total payments',
                                  style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 11),
                                ),
                                Text(
                                  totPayment.toStringAsFixed(2),
                                  style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 20, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Net (R − P)',
                                  style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 11),
                                ),
                                Text(
                                  (totReceipt - totPayment).toStringAsFixed(2),
                                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _syncActualVsFromReceipts() {
    final list = _records('Actual v/s Posting');
    setState(() {
      list.clear();
      for (final r in _records('Receipt')) {
        final posted = (r['amount'] as num?)?.toDouble() ?? 0.0;
        list.add({
          'id': _nextId('Actual v/s Posting'),
          'date': (r['date'] ?? '').toString(),
          'posted': posted,
          'actual': posted,
          'difference': 0.0,
        });
      }
    });
    _showMessage('Loaded ${list.length} row(s) from receipt vouchers');
  }

  Future<void> _editSelectedActualVsPosting() async {
    final row = _selectedAvpRow;
    if (row == null) {
      _showMessage('Select a row, then edit actual');
      return;
    }
    final posted = (row['posted'] is num) ? (row['posted'] as num).toDouble() : (double.tryParse('${row['posted']}') ?? 0);
    final ctrl = TextEditingController(text: '${row['actual']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Actual amount'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Physical / counted actual', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && mounted) {
      final a = double.tryParse(ctrl.text.trim()) ?? posted;
      setState(() {
        row['actual'] = a;
        row['difference'] = a - posted;
      });
      _showMessage('Updated');
    }
    ctrl.dispose();
  }

  Widget _actualVsPostingScreen() {
    final list = _records('Actual v/s Posting');
    final rows = list.where((e) => _dateInRange((e['date'] ?? '').toString(), _fromDate.text, _toDate.text)).toList();
    int? avpSelectedRowIndex;
    if (_selectedAvpRow != null) {
      final ix = rows.indexWhere((e) => identical(e, _selectedAvpRow));
      if (ix >= 0) {
        avpSelectedRowIndex = ix;
      }
    }

    return Container(
      color: const Color(0xFFFFF7ED),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF9A3412), Color(0xFFC2410C)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.fact_check, color: Colors.white70),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Actual vs posting',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Material(
                    borderRadius: BorderRadius.circular(12),
                    elevation: 1,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Compare physical/counted figures with posted vouchers.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _dateInput(_fromDate)),
                              const SizedBox(width: 8),
                              Expanded(child: _dateInput(_toDate)),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _syncActualVsFromReceipts,
                                icon: const Icon(Icons.download, size: 18),
                                label: const Text('Load from receipts'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: _editSelectedActualVsPosting,
                                icon: const Icon(Icons.edit_note, size: 18),
                                label: const Text('Edit actual'),
                                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC2410C)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Material(
                      borderRadius: BorderRadius.circular(12),
                      elevation: 1,
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                        child: _SimpleTable(
                          headers: const ['Date', 'Actual', 'Posted', 'Difference'],
                          selectedIndex: avpSelectedRowIndex,
                          rows: rows
                              .map((e) {
                                final a = (e['actual'] is num) ? (e['actual'] as num).toDouble() : (double.tryParse('${e['actual']}') ?? 0);
                                final p = (e['posted'] is num) ? (e['posted'] as num).toDouble() : (double.tryParse('${e['posted']}') ?? 0);
                                final d = (e['difference'] is num) ? (e['difference'] as num).toDouble() : (a - p);
                                return [
                                  (e['date'] ?? '').toString(),
                                  a.toStringAsFixed(2),
                                  p.toStringAsFixed(2),
                                  d.toStringAsFixed(2),
                                ];
                              })
                              .toList(),
                          onRowTap: (i) => setState(() => _selectedAvpRow = rows[i]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _vatReportLines() {
    final rows = <Map<String, dynamic>>[];
    for (final e in salesInvoiceRecords) {
      final d = (e['date'] ?? '').toString();
      if (!_dateInRange(d, _fromDate.text, _toDate.text)) continue;
      final vat =
          ((e['cgst'] as num?)?.toDouble() ?? 0) +
          ((e['sgst'] as num?)?.toDouble() ?? 0) +
          ((e['igst'] as num?)?.toDouble() ?? 0);
      rows.add({'date': d, 'doc': e['billNo'] ?? '', 'party': e['party'] ?? '', 'vat': vat, 'kind': 'Sales'});
    }
    for (final e in purchaseBillRecords) {
      final d = (e['date'] ?? '').toString();
      if (!_dateInRange(d, _fromDate.text, _toDate.text)) continue;
      final vat =
          ((e['cgst'] as num?)?.toDouble() ?? 0) +
          ((e['sgst'] as num?)?.toDouble() ?? 0) +
          ((e['igst'] as num?)?.toDouble() ?? 0);
      rows.add({'date': d, 'doc': e['billNo'] ?? '', 'party': e['party'] ?? '', 'vat': vat, 'kind': 'Purchase'});
    }
    rows.sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
    return rows;
  }

  Widget _vatReportsScreen() {
    final lines = _vatReportLines();
    final totalVat = lines.fold<double>(0, (s, e) => s + ((e['vat'] as num?)?.toDouble() ?? 0));

    return Container(
      color: const Color(0xFFFEF3C7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFFB45309),
            child: Row(
              children: [
                const Text(
                  'VAT reports',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const Spacer(),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Material(
                    borderRadius: BorderRadius.circular(12),
                    elevation: 1,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(child: _dateInput(_fromDate)),
                          const SizedBox(width: 8),
                          Expanded(child: _dateInput(_toDate)),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('VAT in period (CGST+SGST+IGST)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              Text(
                                totalVat.toStringAsFixed(2),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                              ),
                            ],
                          ),
                          FilledButton(
                            onPressed: () => setState(() {}),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB45309)),
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Material(
                      borderRadius: BorderRadius.circular(12),
                      elevation: 1,
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                        child: _SimpleTable(
                          headers: const ['Date', 'Document', 'Party', 'Kind', 'VAT amount'],
                          selectedIndex: null,
                          rows: lines
                              .map(
                                (e) => [
                                  (e['date'] ?? '').toString(),
                                  (e['doc'] ?? '').toString(),
                                  (e['party'] ?? '').toString(),
                                  (e['kind'] ?? '').toString(),
                                  ((e['vat'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
                                ],
                              )
                              .toList(),
                          onRowTap: (_) {},
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eInvoicingScreen() {
    final rows = salesInvoiceRecords.map((e) {
      final no = (e['billNo'] ?? '').toString();
      return {
        'no': no,
        'date': (e['date'] ?? '').toString(),
        'party': (e['party'] ?? '').toString(),
        'status': einvoiceStatusByBillNo[no] ?? 'Pending',
      };
    }).toList();

    return Container(
      color: const Color(0xFFEEF2FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF4338CA),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_upload_outlined, color: Colors.white70),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'e-Invoicing',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    setState(() {
                      for (final e in salesInvoiceRecords) {
                        final no = (e['billNo'] ?? '').toString();
                        if (no.isEmpty) continue;
                        if ((einvoiceStatusByBillNo[no] ?? 'Pending') == 'Pending') {
                          einvoiceStatusByBillNo[no] = 'Generated';
                        }
                      }
                    });
                    _showMessage('Generated for all pending invoices');
                  },
                  style: FilledButton.styleFrom(foregroundColor: const Color(0xFF312E81)),
                  child: const Text('Generate all pending'),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                borderRadius: BorderRadius.circular(12),
                elevation: 1,
                color: Colors.white,
                child: ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final no = (r['no'] ?? '').toString();
                    final st = (r['status'] ?? 'Pending').toString();
                    final pending = st == 'Pending';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(no, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text((r['date'] ?? '').toString(), style: const TextStyle(fontSize: 12.5)),
                          ),
                          Expanded(
                            child: Text((r['party'] ?? '').toString(), style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: pending ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: pending ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                            ),
                            child: Text(
                              st,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: pending ? const Color(0xFFB45309) : const Color(0xFF047857),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (pending)
                            FilledButton(
                              onPressed: () {
                                setState(() {
                                  einvoiceStatusByBillNo[no] = 'Generated';
                                });
                                _showMessage('e-Invoice marked generated for $no');
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: const Text('Generate'),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.check_circle, color: Color(0xFF059669), size: 22),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unknownAccountModuleScreen() {
    return Container(
      color: const Color(0xFFFFFBEB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: const Color(0xFFB45309),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Account module routing',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'The screen "${widget.title}" is not mapped in AccountModuleScreen.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, height: 1.35, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close),
                          label: const Text('Close'),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _journalRegisterScreen() {
    final rows = _records('Journal Voucher');
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.view_list, color: Color(0xFF475569), size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Journal register',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.black45, size: 18),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final r = rows[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFE0E7FF),
                          child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF4338CA))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (r['voucherNo'] ?? '').toString(),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${r['date'] ?? ''}  ·  ${r['narration'] ?? ''}',
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Dr ${r['debit'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF991B1B))),
                            Text('Cr ${r['credit'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                            const SizedBox(height: 4),
                            Text((r['status'] ?? '').toString(), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _salesRegisterScreen() {
    final all = _salesRegisterRows();
    final q = _filterAccount.text.trim().toLowerCase();
    final rows = all.where((r) {
      if (!_dateInRange((r['date'] ?? '').toString(), _fromDate.text, _toDate.text)) {
        return false;
      }
      if (q.isEmpty) return true;
      return (r['customer'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
    final total = rows.fold<double>(
      0,
      (s, r) => s + (double.tryParse((r['amount'] ?? '0').toString()) ?? 0),
    );
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F766E),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sales Register',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _SectionCard(
                          title: 'Filters',
                          child: Row(
                            children: [
                              Expanded(child: _dateInput(_fromDate)),
                              const SizedBox(width: 8),
                              Expanded(child: _dateInput(_toDate)),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: _compactInput(
                                  controller: _filterAccount,
                                  hintText: 'Customer contains…',
                                  onSubmitted: (_) => setState(() {}),
                                ),
                              ),
                              FilledButton(
                                onPressed: () => setState(() {}),
                                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                                child: const Text('Apply'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _SectionCard(
                            title: 'Invoices',
                            expandChild: true,
                            contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                            child: _SimpleTable(
                              headers: const ['Invoice', 'Date', 'Customer', 'Amount', 'Status'],
                              selectedIndex: null,
                              rows: rows
                                  .map(
                                    (r) => [
                                      (r['invoiceNo'] ?? '').toString(),
                                      (r['date'] ?? '').toString(),
                                      (r['customer'] ?? '').toString(),
                                      (r['amount'] ?? '').toString(),
                                      (r['status'] ?? '').toString(),
                                    ],
                                  )
                                  .toList(),
                              onRowTap: (_) {},
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 200,
                    child: Column(
                      children: [
                        _SectionCard(
                          title: 'Total sales',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                total.toStringAsFixed(2),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F766E)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${rows.length} invoice(s) in range',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _purchaseRegisterScreen() {
    final all = _purchaseRegisterRows();
    final q = _filterAccount.text.trim().toLowerCase();
    final rows = all.where((r) {
      if (!_dateInRange((r['date'] ?? '').toString(), _fromDate.text, _toDate.text)) {
        return false;
      }
      if (q.isEmpty) return true;
      return (r['supplier'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
    final total = rows.fold<double>(
      0,
      (s, r) => s + (double.tryParse((r['amount'] ?? '0').toString()) ?? 0),
    );
    return Container(
      color: const Color(0xFFFFFBEB),
      child: Column(
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFB45309),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Purchase Register',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  _SectionCard(
                    title: 'Filters',
                    child: Row(
                      children: [
                        Expanded(child: _dateInput(_fromDate)),
                        const SizedBox(width: 8),
                        Expanded(child: _dateInput(_toDate)),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _compactInput(
                            controller: _filterAccount,
                            hintText: 'Supplier contains…',
                            onSubmitted: (_) => setState(() {}),
                          ),
                        ),
                        FilledButton(
                          onPressed: () => setState(() {}),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB45309)),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Total purchase ', style: TextStyle(color: Color(0xFF64748B))),
                          Text(
                            total.toStringAsFixed(2),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _SectionCard(
                      title: 'Bills',
                      expandChild: true,
                      contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: _SimpleTable(
                        headers: const ['Bill', 'Date', 'Supplier', 'Amount'],
                        selectedIndex: null,
                        rows: rows
                            .map(
                              (r) => [
                                (r['billNo'] ?? '').toString(),
                                (r['date'] ?? '').toString(),
                                (r['supplier'] ?? '').toString(),
                                (r['amount'] ?? '').toString(),
                              ],
                            )
                            .toList(),
                        onRowTap: (_) {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _gstInvoiceRowsFiltered() {
    final rows = <Map<String, dynamic>>[];
    for (final e in salesInvoiceRecords) {
      final d = (e['date'] ?? '').toString();
      if (!_dateInRange(d, _fromDate.text, _toDate.text)) continue;
      final t = (e['gstType'] ?? 'GST Local').toString();
      final gstOk =
          _gstOutputFilter == 'All' ||
          t == _gstOutputFilter ||
          (_gstOutputFilter == 'GST Exempt' && (t == 'GST Exempt' || t == 'Exempt'));
      if (!gstOk) continue;
      rows.add({
        'kind': 'Sales',
        'no': e['billNo'],
        'date': d,
        'party': e['party'],
        'taxable': (e['subTotal'] as num?)?.toDouble() ?? 0,
        'cgst': (e['cgst'] as num?)?.toDouble() ?? 0,
        'sgst': (e['sgst'] as num?)?.toDouble() ?? 0,
        'igst': (e['igst'] as num?)?.toDouble() ?? 0,
      });
    }
    for (final e in purchaseBillRecords) {
      final d = (e['date'] ?? '').toString();
      if (!_dateInRange(d, _fromDate.text, _toDate.text)) continue;
      final t = (e['gstType'] ?? 'GST Local').toString();
      final gstOk =
          _gstOutputFilter == 'All' ||
          t == _gstOutputFilter ||
          (_gstOutputFilter == 'GST Exempt' && (t == 'GST Exempt' || t == 'Exempt'));
      if (!gstOk) continue;
      rows.add({
        'kind': 'Purchase',
        'no': e['billNo'],
        'date': d,
        'party': e['party'],
        'taxable': (e['subTotal'] as num?)?.toDouble() ?? 0,
        'cgst': (e['cgst'] as num?)?.toDouble() ?? 0,
        'sgst': (e['sgst'] as num?)?.toDouble() ?? 0,
        'igst': (e['igst'] as num?)?.toDouble() ?? 0,
      });
    }
    rows.sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
    return rows;
  }

  Widget _gstReportScreen() {
    final inv = _gstInvoiceRowsFiltered();
    final cgst = inv.fold<double>(0, (s, e) => s + (e['cgst'] as double));
    final sgst = inv.fold<double>(0, (s, e) => s + (e['sgst'] as double));
    final igst = inv.fold<double>(0, (s, e) => s + (e['igst'] as double));
    final totalGst = cgst + sgst + igst;
    return Container(
      color: const Color(0xFFF5F3FF),
      child: Column(
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'GST Reports',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: 'Period & GST type',
                    child: Row(
                      children: [
                        Expanded(child: _dateInput(_fromDate)),
                        const SizedBox(width: 8),
                        Expanded(child: _dateInput(_toDate)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _compactDropdown(
                            value: _gstOutputFilter,
                            values: const ['All', 'GST Local', 'IGST', 'GST Exempt'],
                            onChanged: (v) => setState(() => _gstOutputFilter = v),
                          ),
                        ),
                        FilledButton(
                          onPressed: () => setState(() {}),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _statCard('CGST', cgst.toStringAsFixed(2), Icons.looks_one)),
                      const SizedBox(width: 8),
                      Expanded(child: _statCard('SGST', sgst.toStringAsFixed(2), Icons.looks_two)),
                      const SizedBox(width: 8),
                      Expanded(child: _statCard('IGST', igst.toStringAsFixed(2), Icons.looks_3)),
                      const SizedBox(width: 8),
                      Expanded(child: _statCard('Total GST', totalGst.toStringAsFixed(2), Icons.receipt_long)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _SectionCard(
                      title: 'Invoice-wise tax',
                      expandChild: true,
                      contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: _SimpleTable(
                        headers: const ['Type', 'No', 'Date', 'Party', 'Taxable', 'CGST', 'SGST', 'IGST'],
                        selectedIndex: null,
                        rows: inv
                            .map(
                              (r) => [
                                (r['kind'] ?? '').toString(),
                                (r['no'] ?? '').toString(),
                                (r['date'] ?? '').toString(),
                                (r['party'] ?? '').toString(),
                                (r['taxable'] as double).toStringAsFixed(2),
                                (r['cgst'] as double).toStringAsFixed(2),
                                (r['sgst'] as double).toStringAsFixed(2),
                                (r['igst'] as double).toStringAsFixed(2),
                              ],
                            )
                            .toList(),
                        onRowTap: (_) {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _firstAccountNameContaining(String q) {
    final ql = q.trim().toLowerCase();
    if (ql.isEmpty) return null;
    for (final a in accounts) {
      final n = (a['name'] ?? '').toString();
      if (n.toLowerCase().contains(ql)) return n;
    }
    return null;
  }

  Widget _generalLedgerScreen() {
    final receiptRows = _records('Receipt');
    final paymentRows = _records('Payment');
    final selectedAccount = _filterAccount.text.trim();
    final ledgerEntries = <Map<String, dynamic>>[
      ...receiptRows.map((e) => {'date': e['date'], 'voucher': e['voucherNo'], 'account': e['account'], 'debit': e['amount'], 'credit': 0, 'type': 'Receipt'}),
      ...paymentRows.map((e) => {'date': e['date'], 'voucher': e['voucherNo'], 'account': e['account'], 'debit': 0, 'credit': e['amount'], 'type': 'Payment'}),
    ].where((e) {
      if (!_dateInRange((e['date'] ?? '').toString(), _fromDate.text, _toDate.text)) {
        return false;
      }
      if (selectedAccount.isEmpty) return true;
      return (e['account'] ?? '').toString().toLowerCase().contains(selectedAccount.toLowerCase());
    }).toList()
      ..sort((a, b) => (a['date'] ?? '').toString().compareTo((b['date'] ?? '').toString()));

    final matchedName = _firstAccountNameContaining(selectedAccount);
    final opening = matchedName == null ? 0.0 : _openingBalanceForAccountName(matchedName);
    double running = opening;
    final tableRows = <List<String>>[];
    for (final e in ledgerEntries) {
      final dr = (e['debit'] as num?)?.toDouble() ?? 0;
      final cr = (e['credit'] as num?)?.toDouble() ?? 0;
      running += dr - cr;
      tableRows.add([
        (e['date'] ?? '').toString(),
        (e['voucher'] ?? '').toString(),
        (e['type'] ?? '').toString(),
        dr.toStringAsFixed(2),
        cr.toStringAsFixed(2),
        running.toStringAsFixed(2),
      ]);
    }

    return Container(
      color: const Color(0xFFEFF6FF),
      child: Column(
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(color: Color(0xFF1D4ED8)),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'General Ledger',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  SizedBox(
                    width: 280,
                    child: _SectionCard(
                      title: 'Account & period',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Opening (from master): ${opening.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 10),
                          _CompactFormRow(
                            label: 'Account',
                            field: _compactInput(controller: _filterAccount, hintText: 'Filter by party name'),
                          ),
                          _CompactFormRow(label: 'From', field: _dateInput(_fromDate)),
                          _CompactFormRow(label: 'To', field: _dateInput(_toDate)),
                          FilledButton.icon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.filter_alt, size: 16),
                            label: const Text('Apply'),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SectionCard(
                      title: 'Posted lines with running balance',
                      expandChild: true,
                      contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: _SimpleTable(
                        headers: const ['Date', 'Voucher', 'Type', 'Debit', 'Credit', 'Balance'],
                        selectedIndex: null,
                        rows: tableRows,
                        onRowTap: (_) {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayBookScreen() {
    final raw = <Map<String, dynamic>>[
      ..._records('Receipt').map((e) => {'date': e['date'], 'module': 'Receipt', 'no': e['voucherNo'], 'amount': e['amount']}),
      ..._records('Payment').map((e) => {'date': e['date'], 'module': 'Payment', 'no': e['voucherNo'], 'amount': e['amount']}),
      ...salesInvoiceRecords.map((e) => {'date': e['date'], 'module': 'Sales', 'no': e['billNo'], 'amount': e['grandTotal']}),
      ...purchaseBillRecords.map((e) => {'date': e['date'], 'module': 'Purchase', 'no': e['billNo'], 'amount': e['grandTotal']}),
    ];
    final entries = raw.where((e) => _dateInRange((e['date'] ?? '').toString(), _fromDate.text, _toDate.text)).toList()
      ..sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));

    return _moduleShell(
      title: 'Day Book',
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            _SectionCard(
              title: 'Date range',
              child: Row(
                children: [
                  Expanded(child: _dateInput(_fromDate)),
                  const SizedBox(width: 8),
                  Expanded(child: _dateInput(_toDate)),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _SectionCard(
                title: 'Daily Timeline',
                expandChild: true,
                child: ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => Divider(color: Colors.blueGrey.shade100, height: 1),
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFE0E7FF),
                        child: Text('${index + 1}', style: const TextStyle(fontSize: 11)),
                      ),
                      title: Text('${e['module']}  •  ${e['no']}'),
                      subtitle: Text((e['date'] ?? '').toString()),
                      trailing: Text(
                        (e['amount'] ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountBalanceScreen() {
    final receipt = _records('Receipt');
    final payment = _records('Payment');
    final Map<String, Map<String, double>> map = {};
    for (final a in accounts) {
      final name = (a['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      map.putIfAbsent(name, () => {'opening': 0, 'debit': 0, 'credit': 0, 'closing': 0});
    }
    for (final r in receipt) {
      final acc = (r['account'] ?? '').toString();
      if (acc.isEmpty) continue;
      map.putIfAbsent(acc, () => {'opening': 0, 'debit': 0, 'credit': 0, 'closing': 0});
      map[acc]!['debit'] = (map[acc]!['debit'] ?? 0) + ((r['amount'] as num?)?.toDouble() ?? 0);
    }
    for (final r in payment) {
      final acc = (r['account'] ?? '').toString();
      if (acc.isEmpty) continue;
      map.putIfAbsent(acc, () => {'opening': 0, 'debit': 0, 'credit': 0, 'closing': 0});
      map[acc]!['credit'] = (map[acc]!['credit'] ?? 0) + ((r['amount'] as num?)?.toDouble() ?? 0);
    }
    final q = _filterAccount.text.trim().toLowerCase();
    final rows = map.entries
        .where((e) => q.isEmpty || e.key.toLowerCase().contains(q))
        .map((e) {
          final opening = _openingBalanceForAccountName(e.key);
          final debit = e.value['debit'] ?? 0;
          final credit = e.value['credit'] ?? 0;
          final closing = opening + debit - credit;
          return [e.key, opening.toStringAsFixed(2), debit.toStringAsFixed(2), credit.toStringAsFixed(2), closing.toStringAsFixed(2)];
        })
        .toList();
    final totalOpening = rows.fold<double>(0, (s, r) => s + (double.tryParse(r[1]) ?? 0));
    final totalDebit = rows.fold<double>(0, (s, r) => s + (double.tryParse(r[2]) ?? 0));
    final totalCredit = rows.fold<double>(0, (s, r) => s + (double.tryParse(r[3]) ?? 0));
    final totalClosing = rows.fold<double>(0, (s, r) => s + (double.tryParse(r[4]) ?? 0));
    return _moduleShell(
      title: 'Account Balance',
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _statCard('Opening', totalOpening.toStringAsFixed(2), Icons.wallet)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('Debit', totalDebit.toStringAsFixed(2), Icons.arrow_downward)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('Credit', totalCredit.toStringAsFixed(2), Icons.arrow_upward)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('Closing', totalClosing.toStringAsFixed(2), Icons.account_balance)),
              ],
            ),
            const SizedBox(height: 10),
            _SectionCard(
              title: 'Filters',
              child: Row(
                children: [
                  SizedBox(width: 220, child: _dateInput(_toDate)),
                  const SizedBox(width: 8),
                  Expanded(child: _compactInput(controller: _filterAccount, hintText: 'Search account')),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _SectionCard(
                title: 'Account-wise Summary',
                expandChild: true,
                child: _SimpleTable(
                  headers: const ['Account', 'Opening', 'Debit', 'Credit', 'Closing'],
                  selectedIndex: null,
                  rows: rows,
                  onRowTap: (_) {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bankReconciliationScreen() {
    final rows = _records('Bank Reconciliation');
    if (rows.isEmpty) {
      rows.addAll([
        {'date': _today(), 'ref': 'BNK-101', 'system': 1200.0, 'bank': 1200.0, 'status': 'Success'},
        {'date': _today(), 'ref': 'BNK-102', 'system': 980.0, 'bank': 0.0, 'status': 'Pending'},
      ]);
    }
    return _moduleShell(
      title: 'Bank Reconciliation',
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            _SectionCard(
              title: 'Bank Filters',
              child: Row(
                children: [
                  Expanded(child: _compactInput(controller: _filterAccount, hintText: 'Bank Account')),
                  const SizedBox(width: 8),
                  Expanded(child: _dateInput(_fromDate)),
                  const SizedBox(width: 8),
                  Expanded(child: _dateInput(_toDate)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _SectionCard(
                title: 'System vs bank statement',
                expandChild: true,
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final matched = (row['status'] ?? '') == 'Success';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blueGrey.shade100),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text((row['date'] ?? '').toString())),
                          Expanded(flex: 2, child: Text((row['ref'] ?? '').toString())),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Books', style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade600)),
                                Text((row['system'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Bank', style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade600)),
                                Text((row['bank'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Switch(
                              value: matched,
                              onChanged: (v) {
                                setState(() {
                                  row['status'] = v ? 'Success' : 'Pending';
                                });
                              },
                            ),
                          ),
                          Text(
                            matched ? 'Matched' : 'Unmatched',
                            style: TextStyle(
                              color: matched ? const Color(0xFF166534) : const Color(0xFF9A3412),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _finalReportsScreen() {
    final totalSales = salesInvoiceRecords.fold<double>(
      0,
      (sum, r) => sum + ((r['grandTotal'] as num?)?.toDouble() ?? 0),
    );
    final totalPurchase = purchaseBillRecords.fold<double>(
      0,
      (sum, r) => sum + ((r['grandTotal'] as num?)?.toDouble() ?? 0),
    );
    final receiptTotal = _records('Receipt').fold<double>(
      0,
      (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0),
    );
    final paymentTotal = _records('Payment').fold<double>(
      0,
      (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0),
    );
    final net = totalSales - totalPurchase + receiptTotal - paymentTotal;
    final tradeProfit = totalSales - totalPurchase;
    return _moduleShell(
      title: 'Final Reports',
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            _SectionCard(
              title: 'Reporting Period',
              child: Row(
                children: [
                  Expanded(child: _dateInput(_fromDate)),
                  const SizedBox(width: 8),
                  Expanded(child: _dateInput(_toDate)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _statCard('Total sales', totalSales.toStringAsFixed(2), Icons.trending_up)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('Total purchase', totalPurchase.toStringAsFixed(2), Icons.shopping_cart)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('Gross profit', tradeProfit.toStringAsFixed(2), Icons.savings)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _statCard('Receipts', receiptTotal.toStringAsFixed(2), Icons.payments)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('Payments', paymentTotal.toStringAsFixed(2), Icons.request_quote)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('Net position', net.toStringAsFixed(2), Icons.dashboard_customize)),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _SectionCard(
                title: 'Report Insights',
                expandChild: true,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE0E7FF), Color(0xFFC7D2FE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Net Position', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(
                              net.toStringAsFixed(2),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: (totalSales <= 0) ? 0 : (totalPurchase / totalSales).clamp(0, 1),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              net >= 0 ? 'Business is in profit zone' : 'Business is in loss zone',
                              style: TextStyle(
                                color: net >= 0 ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _SimpleTable(
                        headers: const ['Report', 'Value', 'Status'],
                        selectedIndex: null,
                        rows: [
                          ['Total Sales', totalSales.toStringAsFixed(2), 'Success'],
                          ['Total Purchase', totalPurchase.toStringAsFixed(2), 'Success'],
                          ['Receipts', receiptTotal.toStringAsFixed(2), 'Success'],
                          ['Payments', paymentTotal.toStringAsFixed(2), 'Success'],
                          ['Net Profit / Loss', net.toStringAsFixed(2), net >= 0 ? 'Success' : 'Danger'],
                        ],
                        onRowTap: (_) {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.title) {
      case 'Receipt':
        return _receiptScreen();
      case 'Payment':
        return _paymentScreen();
      case 'Journal Voucher':
        return _journalVoucherScreen();
      case 'Sales Register':
        return _salesRegisterScreen();
      case 'Purchase Register':
        return _purchaseRegisterScreen();
      case 'GST Reports':
        return _gstReportScreen();
      case 'General Ledger':
        return _generalLedgerScreen();
      case 'Day Book':
        return _dayBookScreen();
      case 'Account Balance':
        return _accountBalanceScreen();
      case 'Bank Reconciliation':
        return _bankReconciliationScreen();
      case 'Final Reports':
        return _finalReportsScreen();
      case 'Receipt/Payment Register':
        return _receiptPaymentRegisterScreen();
      case 'Journal Register':
        return _journalRegisterScreen();
      case 'Actual v/s Posting':
        return _actualVsPostingScreen();
      case 'VAT Reports':
        return _vatReportsScreen();
      case 'eInvoicing':
        return _eInvoicingScreen();
      case 'Cr/Dr Note Register':
        return Container(
          color: const Color(0xFFF5F5F4),
          child: Column(
            children: [
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(color: Color(0xFF44403C)),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Cr / Dr Note register',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    if (widget.onClose != null)
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _SectionCard(
                    title: 'From Invoice module (Credit / Debit Note)',
                    expandChild: true,
                    child: _SimpleTable(
                      headers: const ['Note No', 'Date', 'Type', 'Account', 'Amount', 'Reason'],
                      selectedIndex: null,
                      rows: creditDebitNotes
                          .map(
                            (r) => [
                              (r['noteNo'] ?? '').toString(),
                              (r['date'] ?? '').toString(),
                              (r['type'] ?? '').toString(),
                              (r['account'] ?? '').toString(),
                              (r['amount'] ?? '').toString(),
                              (r['reason'] ?? '').toString(),
                            ],
                          )
                          .toList(),
                      onRowTap: (_) {},
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case 'Stock Transfer Register':
        return Container(
          color: const Color(0xFFF0FDFA),
          child: Column(
            children: [
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(color: Color(0xFF0F766E)),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Stock transfer register',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    if (widget.onClose != null)
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _SectionCard(
                    title: 'From Inventory → Stock Transfer',
                    expandChild: true,
                    child: _SimpleTable(
                      headers: const ['No', 'Date', 'From', 'To', 'Items', 'Total Qty'],
                      selectedIndex: null,
                      rows: stockTransferRecords
                          .map(
                            (r) => [
                              (r['transferNo'] ?? '').toString(),
                              (r['date'] ?? '').toString(),
                              (r['from'] ?? '').toString(),
                              (r['to'] ?? '').toString(),
                              (r['totalItems'] ?? '').toString(),
                              (r['totalQty'] ?? '').toString(),
                            ],
                          )
                          .toList(),
                      onRowTap: (_) {},
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case 'Interest Calculation':
        final rate = double.tryParse(_interestRate.text) ?? 12;
        final days = double.tryParse(_interestDuration.text) ?? 30;
        final party = _interestParty.text.trim();
        final closing = party.isEmpty ? 0.0 : _closingBookForParty(party);
        final interest = closing * (rate / 100) * (days / 365);
        final interestRows = <List<String>>[
          [
            party.isEmpty ? '(all parties)' : party,
            closing.toStringAsFixed(2),
            '${rate.toStringAsFixed(2)}% × ${days.toStringAsFixed(0)}d',
            interest.toStringAsFixed(2),
            'Estimate',
          ],
        ];
        return Container(
          color: const Color(0xFFFFF1F2),
          child: Column(
            children: [
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(color: Color(0xFFBE123C)),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Interest on outstanding',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    if (widget.onClose != null)
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      _SectionCard(
                        title: 'Parameters',
                        child: Column(
                          children: [
                            _CompactFormRow(
                              label: 'Party',
                              field: _compactInput(
                                controller: _interestParty,
                                hintText: 'Match name from Account Master',
                                onSubmitted: (_) => setState(() {}),
                              ),
                            ),
                            _CompactFormRow(
                              label: 'Rate % p.a.',
                              field: _compactInput(controller: _interestRate, keyboardType: TextInputType.number),
                            ),
                            _CompactFormRow(
                              label: 'Duration (days)',
                              field: _compactInput(controller: _interestDuration, keyboardType: TextInputType.number),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: () => setState(() {}),
                                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFBE123C)),
                                child: const Text('Calculate'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _SectionCard(
                          title: 'Result',
                          expandChild: true,
                          child: _SimpleTable(
                            headers: const ['Party', 'Outstanding', 'Rate × days', 'Interest', 'Note'],
                            selectedIndex: null,
                            rows: interestRows,
                            onRowTap: (_) {},
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      case 'Currency Reconciliation':
        final systemInr = _records('Receipt').fold<double>(0, (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));
        final physical = double.tryParse(_physicalCashCount.text) ?? 0;
        final rateFx = double.tryParse(_forexRate.text) ?? 1;
        final diffInr = physical - systemInr;
        final usdEquiv = rateFx > 0 ? diffInr / rateFx : 0;
        return Container(
          color: const Color(0xFFECFEFF),
          child: Column(
            children: [
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(color: Color(0xFF0E7490)),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Currency reconciliation',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    if (widget.onClose != null)
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 340,
                        child: _SectionCard(
                          title: 'INR vs counted cash',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _CompactFormRow(label: 'As on', field: _dateInput(_toDate)),
                              _CompactFormRow(
                                label: 'Books (receipts)',
                                field: SizedBox(
                                  height: 34,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      systemInr.toStringAsFixed(2),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                              _CompactFormRow(
                                label: 'Physical count',
                                field: _compactInput(
                                  controller: _physicalCashCount,
                                  keyboardType: TextInputType.number,
                                  hintText: 'INR',
                                  onSubmitted: (_) => setState(() {}),
                                ),
                              ),
                              _CompactFormRow(
                                label: 'Difference (INR)',
                                field: SizedBox(
                                  height: 34,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      diffInr.toStringAsFixed(2),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: diffInr == 0 ? const Color(0xFF166534) : const Color(0xFF9A3412),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const Divider(),
                              _CompactFormRow(
                                label: 'FX rate (INR/USD)',
                                field: _compactInput(
                                  controller: _forexRate,
                                  keyboardType: TextInputType.number,
                                  onSubmitted: (_) => setState(() {}),
                                ),
                              ),
                              _CompactFormRow(
                                label: 'Difference (USD eq.)',
                                field: SizedBox(
                                  height: 34,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      usdEquiv.toStringAsFixed(2),
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SectionCard(
                          title: 'Adjustment log',
                          expandChild: true,
                          child: _SimpleTable(
                            headers: const ['Date', 'Reference', 'Account', 'Amount', 'Status'],
                            selectedIndex: null,
                            rows: _records('Currency Reconciliation')
                                .map((r) => [(r['date'] ?? _today()).toString(), (r['ref'] ?? 'N/A').toString(), (r['account'] ?? '').toString(), (r['amount'] ?? '0').toString(), (r['status'] ?? 'Pending').toString()])
                                .toList(),
                            onRowTap: (_) {},
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      default:
        return _unknownAccountModuleScreen();
    }
  }
}

class SalesInvoiceScreen extends StatelessWidget {
  final VoidCallback? onClose;
  const SalesInvoiceScreen({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    return _InvoiceModuleScreen(
      title: 'Sales Invoice',
      partyLabel: 'Account',
      saveButtonText: 'Save Invoice',
      records: salesInvoiceRecords,
      nextNoGetter: () => _salesInvoiceSeed++,
      isPurchase: false,
      onClose: onClose,
    );
  }
}

class PurchaseBillScreen extends StatelessWidget {
  final VoidCallback? onClose;
  const PurchaseBillScreen({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    return _InvoiceModuleScreen(
      title: 'Purchase Bill',
      partyLabel: 'Supplier',
      saveButtonText: 'Save Bill',
      records: purchaseBillRecords,
      nextNoGetter: () => _purchaseBillSeed++,
      isPurchase: true,
      onClose: onClose,
    );
  }
}

class _InvoiceModuleScreen extends StatefulWidget {
  final String title;
  final String partyLabel;
  final String saveButtonText;
  final List<Map<String, dynamic>> records;
  final int Function() nextNoGetter;
  final bool isPurchase;
  final VoidCallback? onClose;

  const _InvoiceModuleScreen({
    required this.title,
    required this.partyLabel,
    required this.saveButtonText,
    required this.records,
    required this.nextNoGetter,
    required this.isPurchase,
    this.onClose,
  });

  @override
  State<_InvoiceModuleScreen> createState() => _InvoiceModuleScreenState();
}

class _InvoiceModuleScreenState extends State<_InvoiceModuleScreen> {
  final _billingSeriesController = TextEditingController(text: 'CASH');
  final _billNoController = TextEditingController();
  final _dateController = TextEditingController();
  final _partyController = TextEditingController();
  final _doctorController = TextEditingController();
  final _patientController = TextEditingController();
  final _addressController = TextEditingController();
  final _mobileController = TextEditingController();
  final _discountPercentController = TextEditingController(text: '0');
  final _discountAmountController = TextEditingController(text: '0');
  final _schemeDiscountController = TextEditingController(text: '0');

  final _productSearchController = TextEditingController();
  final _packController = TextEditingController();
  final _batchController = TextEditingController();
  final _expiryController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _freeController = TextEditingController(text: '0');
  final _rateController = TextEditingController(text: '0');

  final _seriesFocus = FocusNode();
  final _billNoFocus = FocusNode();
  final _dateFocus = FocusNode();
  final _partyFocus = FocusNode();
  final _doctorFocus = FocusNode();
  final _patientFocus = FocusNode();
  final _gstFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _mobileFocus = FocusNode();
  final _discountFocus = FocusNode();
  final _productFocus = FocusNode();
  final _packFocus = FocusNode();
  final _batchFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _qtyFocus = FocusNode();
  final _freeFocus = FocusNode();
  final _rateFocus = FocusNode();
  final _discountAmountFocus = FocusNode();

  final List<Map<String, dynamic>> _invoiceItems = [];
  Map<String, dynamic>? _selectedProduct;
  int? _selectedRowIndex;
  int? _selectedRecordIndex;
  /// When editing an existing saved invoice/bill, reuse this document id.
  int? _editingDocumentId;
  bool _manualBillNo = false;
  String _gstType = 'GST Local';

  @override
  void initState() {
    super.initState();
    _partyController.addListener(() {
      if (mounted) setState(() {});
    });
    _qtyController.addListener(() {
      if (mounted) setState(() {});
    });
    _freeController.addListener(() {
      if (mounted) setState(() {});
    });
    _resetForm();
  }

  @override
  void dispose() {
    _billingSeriesController.dispose();
    _billNoController.dispose();
    _dateController.dispose();
    _partyController.dispose();
    _doctorController.dispose();
    _patientController.dispose();
    _addressController.dispose();
    _mobileController.dispose();
    _discountPercentController.dispose();
    _discountAmountController.dispose();
    _schemeDiscountController.dispose();
    _productSearchController.dispose();
    _packController.dispose();
    _batchController.dispose();
    _expiryController.dispose();
    _qtyController.dispose();
    _freeController.dispose();
    _rateController.dispose();
    _seriesFocus.dispose();
    _billNoFocus.dispose();
    _dateFocus.dispose();
    _partyFocus.dispose();
    _doctorFocus.dispose();
    _patientFocus.dispose();
    _gstFocus.dispose();
    _addressFocus.dispose();
    _mobileFocus.dispose();
    _discountFocus.dispose();
    _productFocus.dispose();
    _packFocus.dispose();
    _batchFocus.dispose();
    _expiryFocus.dispose();
    _qtyFocus.dispose();
    _freeFocus.dispose();
    _rateFocus.dispose();
    _discountAmountFocus.dispose();
    super.dispose();
  }

  String _todayString() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }

  Future<void> _pickInvoiceDate() async {
    final initial = DateTime.tryParse(_dateController.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');
    setState(() {
      _dateController.text = '${picked.year}-$mm-$dd';
    });
    nextFocus(context, _partyFocus);
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0;
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _resetEntryRow() {
    _selectedProduct = null;
    _productSearchController.clear();
    _packController.clear();
    _batchController.clear();
    _expiryController.clear();
    _qtyController.text = '1';
    _freeController.text = '0';
    _rateController.text = '0';
    _selectedRowIndex = null;
  }

  void _resetForm() {
    _dateController.text = _todayString();
    if (!_manualBillNo) {
      _billNoController.text = widget.nextNoGetter().toString();
    }
    _partyController.clear();
    _doctorController.clear();
    _patientController.clear();
    _addressController.clear();
    _mobileController.clear();
    _discountPercentController.text = '0';
    _discountAmountController.text = '0';
    _schemeDiscountController.text = '0';
    _invoiceItems.clear();
    _selectedRecordIndex = null;
    _editingDocumentId = null;
    _resetEntryRow();
  }

  int _fuzzyScore(String query, String candidate) {
    final q = query.toLowerCase().trim();
    final c = candidate.toLowerCase().trim();
    if (q.isEmpty || c.isEmpty) return 0;
    if (c == q) return 1000;
    if (c.startsWith(q)) return 800 - (c.length - q.length);
    if (c.contains(q)) return 600 - (c.length - q.length);
    int sequence = 0;
    int index = 0;
    for (int i = 0; i < q.length; i++) {
      final found = c.indexOf(q[i], index);
      if (found == -1) break;
      sequence++;
      index = found + 1;
    }
    if (sequence >= (q.length * 0.6).ceil()) {
      return 400 + sequence * 10;
    }
    int charHits = 0;
    for (final ch in q.split('')) {
      if (c.contains(ch)) {
        charHits++;
      }
    }
    if (charHits >= (q.length * 0.7).ceil()) {
      return 250 + charHits * 5;
    }
    return 0;
  }

  Iterable<Map<String, dynamic>> _findAccounts(String text) {
    final q = text.trim();
    final matches =
        accounts
            .map(
              (row) => {
                'row': row,
                'score': _fuzzyScore(q, (row['name'] ?? '').toString()),
              },
            )
            .where((x) => x['score'] as int > 0)
            .toList()
          ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return matches.take(8).map((x) => x['row'] as Map<String, dynamic>);
  }

  Iterable<Map<String, dynamic>> _findDoctors(String text) {
    final q = text.trim();
    final matches =
        doctors
            .map(
              (row) => {
                'row': row,
                'score': _fuzzyScore(q, (row['name'] ?? '').toString()),
              },
            )
            .where((x) => x['score'] as int > 0)
            .toList()
          ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return matches.take(8).map((x) => x['row'] as Map<String, dynamic>);
  }

  Iterable<Map<String, dynamic>> _findProducts(String text) {
    final q = text.trim();
    final matches =
        products
            .map(
              (row) => {
                'row': row,
                'score': _fuzzyScore(q, (row['name'] ?? '').toString()),
              },
            )
            .where((x) => x['score'] as int > 0)
            .toList()
          ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return matches.take(10).map((x) => x['row'] as Map<String, dynamic>);
  }

  void _applyProductSelection(Map<String, dynamic> row) {
    _selectedProduct = row;
    _productSearchController.text = (row['name'] ?? '').toString();
    _packController.text = (row['salesPack'] ?? row['purPack'] ?? '')
        .toString();
    _batchController.text = (row['batch'] ?? row['barcode'] ?? '').toString();
    _expiryController.text = (row['expiry'] ?? '').toString();
    _rateController.text = widget.isPurchase
        ? (row['purRate'] ?? row['wRate'] ?? row['mrp'] ?? '0').toString()
        : (row['saleRate'] ?? row['wRate'] ?? row['mrp'] ?? '0').toString();
  }

  double _parseGstPercent(dynamic raw, {double fallback = 12}) {
    final text = (raw ?? '').toString().replaceAll(RegExp(r'[^0-9.]'), '');
    final val = double.tryParse(text);
    return val == null || val < 0 ? fallback : val;
  }

  double get _selectedProductGstPercent => _selectedProduct == null
      ? 0
      : _parseGstPercent(
          _selectedProduct!['salesGst'] ??
              _selectedProduct!['purGst'] ??
              _selectedProduct!['gst'] ??
              '12',
        );

  double get _selectedProductStock => _selectedProduct == null
      ? 0
      : _toDouble(_selectedProduct!['stock']);

  double get _entryDemandQty =>
      _toDouble(_qtyController.text) + _toDouble(_freeController.text);

  double get _availableStockForCurrentEntry {
    var available = _selectedProductStock;
    if (!widget.isPurchase &&
        _selectedRowIndex != null &&
        _selectedRowIndex! >= 0 &&
        _selectedRowIndex! < _invoiceItems.length) {
      final editing = _invoiceItems[_selectedRowIndex!];
      if (editing['productId'] == _selectedProduct?['id']) {
        available += _toDouble(editing['qty']) + _toDouble(editing['free']);
      }
    }
    return available;
  }

  bool get _entryQtyExceedsStock =>
      !widget.isPurchase &&
      _selectedProduct != null &&
      _entryDemandQty > 0 &&
      _entryDemandQty > _availableStockForCurrentEntry + 0.0001;

  double _lineTax(Map<String, dynamic> row) =>
      _lineAmount(row) * (_toDouble(row['gstPercent']) / 100);

  double _lineTotal(Map<String, dynamic> row) => _lineAmount(row) + _lineTax(row);

  int get _totalItemsCount => _invoiceItems.length;
  double get _totalQty =>
      _invoiceItems.fold(0, (sum, row) => sum + _toDouble(row['qty']));

  double _lineAmount(Map<String, dynamic> row) =>
      _toDouble(row['qty']) * _toDouble(row['rate']);

  double get _subTotal =>
      _invoiceItems.fold(0, (sum, row) => sum + _lineAmount(row));
  double get _discountPercent => _toDouble(_discountPercentController.text);
  double get _discountAmountFixed => _toDouble(_discountAmountController.text);
  double get _schemeDiscount =>
      widget.isPurchase ? _toDouble(_schemeDiscountController.text) : 0;
  double get _discountAmount =>
      (_subTotal * (_discountPercent / 100)) +
      _discountAmountFixed +
      _schemeDiscount;
  double get _taxable =>
      (_subTotal - _discountAmount).clamp(0, double.infinity);
  double get _taxPercent {
    if (_invoiceItems.isEmpty) return 0;
    final values = _invoiceItems
        .map((x) => _toDouble(x['gstPercent']))
        .where((x) => x > 0);
    if (values.isEmpty) return 12;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double get _igst => _gstType == 'IGST' ? _taxable * (_taxPercent / 100) : 0;
  double get _cgst =>
      _gstType == 'IGST' ? 0 : (_taxable * (_taxPercent / 100)) / 2;
  double get _sgst =>
      _gstType == 'IGST' ? 0 : (_taxable * (_taxPercent / 100)) / 2;
  double get _beforeRound => _taxable + _igst + _cgst + _sgst;
  double get _roundOff => _beforeRound.roundToDouble() - _beforeRound;
  double get _grandTotal => _beforeRound + _roundOff;

  void _commitEntryRow() {
    final name = _productSearchController.text.trim();
    final qty = _toDouble(_qtyController.text);
    final free = _toDouble(_freeController.text);
    final rate = _toDouble(_rateController.text);
    final gstPercent = _selectedProduct == null ? 12.0 : _selectedProductGstPercent;

    if (name.isEmpty || _selectedProduct == null) {
      _showMessage('Select product from suggestion');
      return;
    }
    if (qty <= 0) {
      _showMessage('Qty must be greater than 0');
      return;
    }
    if (!widget.isPurchase &&
        _selectedProduct != null &&
        _entryDemandQty > _availableStockForCurrentEntry + 0.0001) {
      _showMessage(
        'Insufficient stock for $name (have ${_availableStockForCurrentEntry.toStringAsFixed(2)}, need ${_entryDemandQty.toStringAsFixed(2)})',
      );
      return;
    }

    final row = <String, dynamic>{
      'sr': _invoiceItems.length + 1,
      'productId': _selectedProduct!['id'],
      'productName': name,
      'pack': _packController.text.trim(),
      'batch': _batchController.text.trim(),
      'expiry': _expiryController.text.trim(),
      'qty': qty,
      'free': free,
      'rate': rate,
      'gstPercent': gstPercent,
      'stockAtBilling': _selectedProductStock,
      'amount': qty * rate,
    };

    setState(() {
      if (_selectedRowIndex != null) {
        _invoiceItems[_selectedRowIndex!] = row;
      } else {
        _invoiceItems.add(row);
      }
      for (int i = 0; i < _invoiceItems.length; i++) {
        _invoiceItems[i]['sr'] = i + 1;
      }
      _resetEntryRow();
    });
    _productFocus.requestFocus();
  }

  void _deleteSelectedRow() {
    if (_selectedRowIndex == null ||
        _selectedRowIndex! >= _invoiceItems.length) {
      _showMessage('Select row to delete');
      return;
    }
    setState(() {
      _invoiceItems.removeAt(_selectedRowIndex!);
      for (int i = 0; i < _invoiceItems.length; i++) {
        _invoiceItems[i]['sr'] = i + 1;
      }
      _resetEntryRow();
    });
  }

  void _loadRowToEntry(int index) {
    if (index < 0 || index >= _invoiceItems.length) return;
    final row = _invoiceItems[index];
    setState(() {
      _selectedRowIndex = index;
      _productSearchController.text = (row['productName'] ?? '').toString();
      _packController.text = (row['pack'] ?? '').toString();
      _batchController.text = (row['batch'] ?? '').toString();
      _expiryController.text = (row['expiry'] ?? '').toString();
      _qtyController.text = (row['qty'] ?? 0).toString();
      _freeController.text = (row['free'] ?? 0).toString();
      _rateController.text = (row['rate'] ?? 0).toString();
      _selectedProduct = products.cast<Map<String, dynamic>?>().firstWhere(
        (p) => p?['id'] == row['productId'],
        orElse: () => null,
      );
    });
  }

  Map<String, dynamic> _buildDocument() {
    return {
      'id': _editingDocumentId ?? DateTime.now().microsecondsSinceEpoch,
      'module': widget.title,
      'series': _billingSeriesController.text.trim(),
      'billNo': _billNoController.text.trim(),
      'date': _dateController.text.trim(),
      'party': _partyController.text.trim(),
      'doctor': _doctorController.text.trim(),
      'patient': _patientController.text.trim(),
      'gstType': _gstType,
      'address': _addressController.text.trim(),
      'mobile': _mobileController.text.trim(),
      'discountPercent': _discountPercent,
      'discountAmount': _discountAmountFixed,
      'schemeDiscount': _schemeDiscount,
      'subTotal': _subTotal,
      'sgst': _sgst,
      'cgst': _cgst,
      'igst': _igst,
      'roundOff': _roundOff,
      'grandTotal': _grandTotal,
      'items': _invoiceItems.map((x) => Map<String, dynamic>.from(x)).toList(),
    };
  }

  void _applyPurchaseStock() {
    _applyPurchaseStockForItems(_invoiceItems);
  }

  void _applyPurchaseStockForItems(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final id = item['productId'];
      final qty = _toDouble(item['qty']) + _toDouble(item['free']);
      if (id == null || qty <= 0) continue;
      final index = products.indexWhere((p) => p['id'] == id);
      if (index == -1) continue;
      final currentStock = _toDouble(products[index]['stock']);
      products[index]['stock'] = (currentStock + qty).toStringAsFixed(2);
    }
  }

  void _applyPurchaseStockFromDoc(Map<String, dynamic> doc) {
    final raw = (doc['items'] as List?) ?? [];
    final items = <Map<String, dynamic>>[];
    for (final x in raw) {
      if (x is Map) items.add(Map<String, dynamic>.from(x));
    }
    _applyPurchaseStockForItems(items);
  }

  void _applySalesStockDeductFromDoc(Map<String, dynamic> doc) {
    final raw = (doc['items'] as List?) ?? [];
    for (final x in raw) {
      if (x is! Map) continue;
      final item = Map<String, dynamic>.from(x);
      final id = item['productId'];
      final qty = _toDouble(item['qty']) + _toDouble(item['free']);
      if (id == null || qty <= 0) continue;
      final index = products.indexWhere((p) => p['id'] == id);
      if (index == -1) continue;
      final currentStock = _toDouble(products[index]['stock']);
      products[index]['stock'] = (currentStock - qty).toStringAsFixed(2);
    }
  }

  void _revertDocumentStock(
    Map<String, dynamic> doc, {
    required bool purchase,
  }) {
    final items = (doc['items'] as List?) ?? [];
    for (final raw in items) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final id = item['productId'];
      final qty = _toDouble(item['qty']) + _toDouble(item['free']);
      if (id == null || qty <= 0) continue;
      final index = products.indexWhere((p) => p['id'] == id);
      if (index == -1) continue;
      final currentStock = _toDouble(products[index]['stock']);
      if (purchase) {
        products[index]['stock'] = (currentStock - qty).toStringAsFixed(2);
      } else {
        products[index]['stock'] = (currentStock + qty).toStringAsFixed(2);
      }
    }
  }

  bool _canApplySalesStock() {
    for (final item in _invoiceItems) {
      final id = item['productId'];
      final qty = _toDouble(item['qty']) + _toDouble(item['free']);
      if (id == null || qty <= 0) continue;
      final index = products.indexWhere((p) => p['id'] == id);
      if (index == -1) continue;
      final currentStock = _toDouble(products[index]['stock']);
      if (currentStock + 0.0001 < qty) {
        _showMessage(
          'Insufficient stock for ${item['productName'] ?? 'product'} '
          '(have ${currentStock.toStringAsFixed(2)}, need ${qty.toStringAsFixed(2)})',
        );
        return false;
      }
    }
    return true;
  }

  void _applySalesStockDeduct() {
    for (final item in _invoiceItems) {
      final id = item['productId'];
      final qty = _toDouble(item['qty']) + _toDouble(item['free']);
      if (id == null || qty <= 0) continue;
      final index = products.indexWhere((p) => p['id'] == id);
      if (index == -1) continue;
      final currentStock = _toDouble(products[index]['stock']);
      products[index]['stock'] = (currentStock - qty).toStringAsFixed(2);
    }
  }

  Future<void> _onSave() async {
    if (_partyController.text.trim().isEmpty) {
      _showMessage('${widget.partyLabel} is required');
      return;
    }
    if (_invoiceItems.isEmpty) {
      _showMessage('Add at least one item');
      return;
    }

    Map<String, dynamic>? previousDoc;
    if (_selectedRecordIndex != null &&
        _selectedRecordIndex! >= 0 &&
        _selectedRecordIndex! < widget.records.length) {
      previousDoc = Map<String, dynamic>.from(
        widget.records[_selectedRecordIndex!],
      );
    }
    if (previousDoc != null) {
      _revertDocumentStock(previousDoc, purchase: widget.isPurchase);
    }

    if (!widget.isPurchase && !_canApplySalesStock()) {
      if (previousDoc != null) {
        _applySalesStockDeductFromDoc(previousDoc);
      }
      return;
    }

    final document = _buildDocument();
    try {
      if (widget.isPurchase) {
        await persistPurchaseBillDoc(document);
      } else {
        await persistSalesInvoiceDoc(document);
      }
    } catch (e) {
      if (previousDoc != null) {
        if (widget.isPurchase) {
          _applyPurchaseStockFromDoc(previousDoc);
        } else {
          _applySalesStockDeductFromDoc(previousDoc);
        }
      }
      _showMessage('Could not save to database: $e');
      return;
    }

    setState(() {
      if (_selectedRecordIndex != null &&
          _selectedRecordIndex! >= 0 &&
          _selectedRecordIndex! < widget.records.length) {
        widget.records[_selectedRecordIndex!] = document;
      } else {
        widget.records.insert(0, document);
      }
      if (widget.isPurchase) {
        _applyPurchaseStock();
      } else {
        _applySalesStockDeduct();
      }
    });

    try {
      for (final p in products) {
        final id = p['id'];
        if (id is int) {
          await persistProductRow(Map<String, dynamic>.from(p));
        }
      }
    } catch (e) {
      _showMessage('Stock saved to memory but product sync failed: $e');
    }

    if (!mounted) return;
    final shouldPrint = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Prompt Bill'),
          content: const Text('Print Bill?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (shouldPrint == true) {
      _onPrint();
    } else {
      _showMessage('${widget.title} saved');
    }
    setState(_resetForm);
  }

  void _onPrint() {
    _showMessage('Print command sent');
  }

  void _onClear() {
    setState(_resetForm);
  }

  Future<void> _onDeleteRecord() async {
    if (_selectedRecordIndex == null ||
        _selectedRecordIndex! >= widget.records.length) {
      _showMessage('Select record to delete');
      return;
    }
    final removed = Map<String, dynamic>.from(
      widget.records[_selectedRecordIndex!],
    );
    _revertDocumentStock(removed, purchase: widget.isPurchase);
    setState(() {
      widget.records.removeAt(_selectedRecordIndex!);
      _resetForm();
    });
    try {
      final id = removed['id'];
      if (id is int) {
        if (widget.isPurchase) {
          await deletePurchaseBillDoc(id);
        } else {
          await deleteSalesInvoiceDoc(id);
        }
      }
      for (final p in products) {
        final pid = p['id'];
        if (pid is int) {
          unawaited(persistProductRow(Map<String, dynamic>.from(p)));
        }
      }
    } catch (e) {
      _showMessage('Delete persisted copy failed: $e');
    }
    _showMessage('Deleted');
  }

  void _onEditRecord() {
    if (_selectedRecordIndex == null ||
        _selectedRecordIndex! < 0 ||
        _selectedRecordIndex! >= widget.records.length) {
      _showMessage('Select record to edit');
      return;
    }

    final row = widget.records[_selectedRecordIndex!];
    final items = (row['items'] as List?) ?? [];
    _editingDocumentId = row['id'] is int
        ? row['id'] as int
        : int.tryParse(row['id']?.toString() ?? '');
    setState(() {
      _billingSeriesController.text = (row['series'] ?? '').toString();
      _billNoController.text = (row['billNo'] ?? '').toString();
      _dateController.text = (row['date'] ?? '').toString();
      _partyController.text = (row['party'] ?? '').toString();
      _doctorController.text = (row['doctor'] ?? '').toString();
      _patientController.text = (row['patient'] ?? '').toString();
      _gstType = (row['gstType'] ?? 'GST Local').toString();
      _addressController.text = (row['address'] ?? '').toString();
      _mobileController.text = (row['mobile'] ?? '').toString();
      _discountPercentController.text = (row['discountPercent'] ?? 0)
          .toString();
      _discountAmountController.text = (row['discountAmount'] ?? 0).toString();
      _schemeDiscountController.text = (row['schemeDiscount'] ?? 0).toString();
      _invoiceItems
        ..clear()
        ..addAll(items.map((x) => Map<String, dynamic>.from(x as Map)));
      _resetEntryRow();
    });
  }

  double _customerPendingBalance(String party) {
    final key = party.trim().toLowerCase();
    if (key.isEmpty) return 0;
    var salesTotal = 0.0;
    for (final inv in salesInvoiceRecords) {
      if ((inv['party'] ?? '').toString().trim().toLowerCase() != key) continue;
      salesTotal += _toDouble(inv['grandTotal']);
    }
    var receiptTotal = 0.0;
    for (final r in accountModuleRecords['Receipt'] ?? const <Map<String, dynamic>>[]) {
      if ((r['account'] ?? '').toString().trim().toLowerCase() != key) continue;
      receiptTotal += _toDouble(r['amount']);
    }
    return salesTotal - receiptTotal;
  }

  String _customerLastPurchase(String party) {
    final key = party.trim().toLowerCase();
    if (key.isEmpty) return '-';
    String best = '';
    for (final inv in salesInvoiceRecords) {
      if ((inv['party'] ?? '').toString().trim().toLowerCase() != key) continue;
      final d = (inv['date'] ?? '').toString();
      if (d.isNotEmpty && d.compareTo(best) > 0) {
        best = d;
      }
    }
    return best.isEmpty ? '-' : best;
  }

  Widget _buildAutoField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required Iterable<Map<String, dynamic>> Function(String) optionsBuilder,
    required String Function(Map<String, dynamic>) display,
    required ValueChanged<Map<String, dynamic>> onSelected,
    FocusNode? nextFocus,
  }) {
    return _CompactFormRow(
      label: label,
      field: RawAutocomplete<Map<String, dynamic>>(
        textEditingController: controller,
        focusNode: focusNode,
        optionsBuilder: (textEditingValue) {
          if (textEditingValue.text.trim().isEmpty) {
            return const Iterable<Map<String, dynamic>>.empty();
          }
          return optionsBuilder(textEditingValue.text);
        },
        displayStringForOption: display,
        onSelected: onSelected,
        optionsViewBuilder: (context, onSelectedOpt, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              child: SizedBox(
                width: 360,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelectedOpt(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Text(display(option)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
        fieldViewBuilder: (context, textController, fieldFocusNode, onSubmit) {
          return _compactInput(
            controller: textController,
            focusNode: fieldFocusNode,
            onSubmitted: (_) {
              if (nextFocus != null) {
                nextFocus.requestFocus();
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildHeaderSection() {
    return _SectionCard(
      title: '${widget.title} Header',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _CompactFormRow(
                  label: 'Billing Series',
                  field: _compactInput(
                    controller: _billingSeriesController,
                    focusNode: _seriesFocus,
                    onSubmitted: (_) => nextFocus(context, _billNoFocus),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactFormRow(
                  label: 'Bill No',
                  field: Row(
                    children: [
                      Expanded(
                        child: _compactInput(
                          controller: _billNoController,
                          focusNode: _billNoFocus,
                          onSubmitted: (_) => nextFocus(context, _dateFocus),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: CheckboxListTile(
                          value: _manualBillNo,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Manual',
                            style: TextStyle(fontSize: 11),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (value) {
                            setState(() {
                              _manualBillNo = value ?? false;
                              if (!_manualBillNo) {
                                _billNoController.text = widget
                                    .nextNoGetter()
                                    .toString();
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactFormRow(
                  label: 'Date',
                  field: SizedBox(
                    height: 34,
                    child: TextField(
                      controller: _dateController,
                      focusNode: _dateFocus,
                      readOnly: true,
                      onTap: _pickInvoiceDate,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_month, size: 18),
                          onPressed: _pickInvoiceDate,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildAutoField(
                  label: widget.partyLabel,
                  controller: _partyController,
                  focusNode: _partyFocus,
                  optionsBuilder: _findAccounts,
                  display: (x) => (x['name'] ?? '').toString(),
                  onSelected: (selected) {
                    setState(() {
                      _partyController.text = (selected['name'] ?? '').toString();
                      _mobileController.text = (selected['mobile'] ?? '')
                          .toString();
                      _addressController.text =
                          '${selected['address1'] ?? ''} ${selected['address2'] ?? ''}'
                              .trim();
                    });
                  },
                  nextFocus: _doctorFocus,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAutoField(
                  label: 'Doctor',
                  controller: _doctorController,
                  focusNode: _doctorFocus,
                  optionsBuilder: _findDoctors,
                  display: (x) => (x['name'] ?? '').toString(),
                  onSelected: (selected) {
                    _doctorController.text = (selected['name'] ?? '')
                        .toString();
                  },
                  nextFocus: _patientFocus,
                ),
              ),
            ],
          ),
          if (_partyController.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Pending balance: ${_customerPendingBalance(_partyController.text).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                      Text(
                        'Last purchase: ${_customerLastPurchase(_partyController.text)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _CompactFormRow(
                  label: 'Patient Name',
                  field: _compactInput(
                    controller: _patientController,
                    focusNode: _patientFocus,
                    onSubmitted: (_) => nextFocus(context, _gstFocus),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactFormRow(
                  label: 'GST Type',
                  field: _compactDropdown(
                    value: _gstType,
                    values: const ['GST Local', 'IGST', 'GST Exempt'],
                    onChanged: (value) => setState(() => _gstType = value),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _CompactFormRow(
                  label: 'Address',
                  field: _compactInput(
                    controller: _addressController,
                    focusNode: _addressFocus,
                    onSubmitted: (_) => nextFocus(context, _mobileFocus),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactFormRow(
                  label: 'Mobile',
                  field: _compactInput(
                    controller: _mobileController,
                    focusNode: _mobileFocus,
                    onSubmitted: (_) => nextFocus(context, _discountFocus),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _CompactFormRow(
                  label: 'Discount %',
                  field: _compactInput(
                    controller: _discountPercentController,
                    keyboardType: TextInputType.number,
                    focusNode: _discountFocus,
                    onSubmitted: (_) => nextFocus(context, _discountAmountFocus),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactFormRow(
                  label: 'Discount ₹',
                  field: _compactInput(
                    controller: _discountAmountController,
                    keyboardType: TextInputType.number,
                    focusNode: _discountAmountFocus,
                    onSubmitted: (_) => nextFocus(context, _productFocus),
                  ),
                ),
              ),
              if (widget.isPurchase) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _CompactFormRow(
                    label: 'Scheme Disc',
                    field: _compactInput(
                      controller: _schemeDiscountController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
              ] else
                const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEntrySection() {
    return _SectionCard(
      title: 'Product Entry Grid',
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                flex: 4,
                child: Text('Product', style: TextStyle(fontSize: 11)),
              ),
              SizedBox(width: 8),
              Expanded(child: Text('Pack', style: TextStyle(fontSize: 11))),
              SizedBox(width: 8),
              Expanded(child: Text('Batch', style: TextStyle(fontSize: 11))),
              SizedBox(width: 8),
              Expanded(child: Text('Expiry', style: TextStyle(fontSize: 11))),
              SizedBox(width: 8),
              Expanded(child: Text('Qty', style: TextStyle(fontSize: 11))),
              SizedBox(width: 8),
              Expanded(child: Text('Free', style: TextStyle(fontSize: 11))),
              SizedBox(width: 8),
              Expanded(child: Text('Rate', style: TextStyle(fontSize: 11))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: RawAutocomplete<Map<String, dynamic>>(
                  textEditingController: _productSearchController,
                  focusNode: _productFocus,
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.trim().isEmpty) {
                      return const Iterable<Map<String, dynamic>>.empty();
                    }
                    return _findProducts(textEditingValue.text);
                  },
                  displayStringForOption: (row) =>
                      (row['name'] ?? '').toString(),
                  onSelected: (row) {
                    setState(() => _applyProductSelection(row));
                    _packFocus.requestFocus();
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Material(
                      elevation: 6,
                      child: SizedBox(
                        width: 420,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final row = options.elementAt(index);
                              final name = (row['name'] ?? '').toString();
                              final company = (row['company'] ?? '').toString();
                              final mrp = _toDouble(row['mrp']).toStringAsFixed(2);
                              final stock = _toDouble(row['stock']).toStringAsFixed(2);
                              return InkWell(
                                onTap: () => onSelected(row),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$name${company.isNotEmpty ? ' - $company' : ''}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'MRP ₹$mrp  ·  Stock $stock',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blueGrey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  fieldViewBuilder:
                      (context, textController, focusNode, onFieldSubmitted) {
                        return _compactInput(
                          controller: textController,
                          focusNode: focusNode,
                          onSubmitted: (_) => nextFocus(context, _packFocus),
                        );
                      },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _compactInput(
                  controller: _packController,
                  focusNode: _packFocus,
                  onSubmitted: (_) => nextFocus(context, _batchFocus),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _compactInput(
                  controller: _batchController,
                  focusNode: _batchFocus,
                  onSubmitted: (_) => nextFocus(context, _expiryFocus),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _compactInput(
                  controller: _expiryController,
                  focusNode: _expiryFocus,
                  onSubmitted: (_) => nextFocus(context, _qtyFocus),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _compactInput(
                  controller: _qtyController,
                  focusNode: _qtyFocus,
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => nextFocus(context, _freeFocus),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _compactInput(
                  controller: _freeController,
                  focusNode: _freeFocus,
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => nextFocus(context, _rateFocus),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _compactInput(
                  controller: _rateController,
                  focusNode: _rateFocus,
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _commitEntryRow(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedProduct == null
                      ? 'Select a product to auto-fill MRP / GST / stock'
                      : 'GST ${_selectedProductGstPercent.toStringAsFixed(2)}% · '
                            'Available ${_availableStockForCurrentEntry.toStringAsFixed(2)} · '
                            'Batch ${_batchController.text.trim().isEmpty ? '-' : _batchController.text.trim()}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _entryQtyExceedsStock
                        ? const Color(0xFFB91C1C)
                        : Colors.blueGrey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (_entryQtyExceedsStock)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Warning: Quantity exceeds available stock.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _commitEntryRow,
                icon: Icon(
                  _selectedRowIndex == null ? Icons.add : Icons.done,
                  size: 16,
                ),
                label: Text(
                  _selectedRowIndex == null ? 'Add Row' : 'Update Row',
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _deleteSelectedRow,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete Row'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SimpleTable(
            headers: const [
              'Sr',
              'Product Name',
              'Qty',
              'Rate',
              'GST%',
              'Line Total',
            ],
            rows: _invoiceItems
                .map(
                  (row) => [
                    (row['sr'] ?? '').toString(),
                    (row['productName'] ?? '').toString(),
                    _toDouble(row['qty']).toStringAsFixed(2),
                    _toDouble(row['rate']).toStringAsFixed(2),
                    _toDouble(row['gstPercent']).toStringAsFixed(2),
                    _lineTotal(row).toStringAsFixed(2),
                  ],
                )
                .toList(),
            selectedIndex: _selectedRowIndex,
            onRowTap: (index) => _loadRowToEntry(index),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    Widget row(String title, double value, {bool strong = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 12))),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      );
    }

    return _SectionCard(
      title: 'Bottom Summary Panel',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _onSave,
                  icon: const Icon(Icons.save, size: 16),
                  label: Text(widget.saveButtonText),
                ),
                OutlinedButton.icon(
                  onPressed: _onPrint,
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Print'),
                ),
                OutlinedButton.icon(
                  onPressed: _onClear,
                  icon: const Icon(Icons.cleaning_services, size: 16),
                  label: const Text('Clear'),
                ),
                OutlinedButton.icon(
                  onPressed: _deleteSelectedRow,
                  icon: const Icon(Icons.remove_circle_outline, size: 16),
                  label: const Text('Delete Row'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 240,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFC),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                row('Total items', _totalItemsCount.toDouble()),
                row('Total qty', _totalQty),
                row('Sub Total', _subTotal),
                row('Discount % value', _subTotal * (_discountPercent / 100)),
                row('Discount ₹', _discountAmountFixed),
                if (widget.isPurchase) row('Scheme Disc', _schemeDiscount),
                row('Discount (Total)', _discountAmount),
                row('CGST', _cgst),
                row('SGST', _sgst),
                row('IGST', _igst),
                row('Round Off', _roundOff),
                const Divider(height: 10),
                row('Grand Total', _grandTotal, strong: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordRegister() {
    return _SectionCard(
      title: '${widget.title} Register',
      child: _SimpleTable(
        headers: const ['Series', 'Bill No', 'Date', 'Party', 'Items', 'Total'],
        rows: widget.records
            .map(
              (row) => [
                (row['series'] ?? '').toString(),
                (row['billNo'] ?? '').toString(),
                (row['date'] ?? '').toString(),
                (row['party'] ?? '').toString(),
                (((row['items'] as List?) ?? []).length).toString(),
                _toDouble(row['grandTotal']).toStringAsFixed(2),
              ],
            )
            .toList(),
        selectedIndex: _selectedRecordIndex,
        onRowTap: (index) => setState(() => _selectedRecordIndex = index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        _SaveIntent: CallbackAction<_SaveIntent>(
          onInvoke: (_) {
            _onSave();
            return null;
          },
        ),
        _PrintIntent: CallbackAction<_PrintIntent>(
          onInvoke: (_) {
            _onPrint();
            return null;
          },
        ),
        _CancelIntent: CallbackAction<_CancelIntent>(
          onInvoke: (_) {
            _onClear();
            return null;
          },
        ),
      },
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.keyS, control: true):
              _SaveIntent(),
          SingleActivator(LogicalKeyboardKey.keyP, control: true):
              _PrintIntent(),
          SingleActivator(LogicalKeyboardKey.escape): _CancelIntent(),
        },
        child: _MasterCrudLayout(
          title: widget.title,
          onClose: widget.onClose,
          formWidth: 980,
          onEdit: _onEditRecord,
          onDelete: _onDeleteRecord,
          onSave: _onSave,
          onClear: _onClear,
          formChild: Column(
            children: [
              _buildHeaderSection(),
              const SizedBox(height: 8),
              _buildEntrySection(),
              const SizedBox(height: 8),
              _buildSummarySection(),
            ],
          ),
          tableChild: _buildRecordRegister(),
        ),
      ),
    );
  }
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _PrintIntent extends Intent {
  const _PrintIntent();
}

class _CancelIntent extends Intent {
  const _CancelIntent();
}

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      color: Colors.grey[400],
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: const Text('Status: Ready', style: TextStyle(fontSize: 10)),
    );
  }
}
