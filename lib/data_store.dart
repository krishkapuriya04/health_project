part of 'package:health_project/main.dart';

const String kCollAccount = 'erp_account';
const String kCollProduct = 'erp_product';
const String kCollDoctor = 'erp_doctor';
const String kCollPatient = 'erp_patient';
const String kCollSales = 'erp_sales_invoice';
const String kCollPurchase = 'erp_purchase_bill';
const String kCollStockTransfer = 'erp_stock_transfer';
const String kCollDiscountRule = 'erp_discount_rule';
const String kCollScheme = 'erp_scheme';
const String kCollDocCommission = 'erp_doctor_commission';
const String kCollDailyClosing = 'erp_daily_closing';
const String kKvAccountModule = 'erp_account_module_v1';
const String kKvGlobalSettings = 'erp_global_settings';
const String kKvLastBackupAt = 'erp_last_backup_at';

/// Loads app state: **accounts** and **products** use SQLite as source of truth; JSON documents
/// only append rows missing from SQL (backup / migration). Other collections remain JSON-first until
/// fully mirrored relationally.

Future<void> hydrateAppDataFromDatabase() async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) {
    debugPrint(
      '[HYDRATE] skipped: no persistent SQLite (web or DB init failed). '
      'In-memory data will not survive restart.',
    );
    _relinkSeedsAfterHydrate();
    return;
  }
  try {
    await _hydrateAccountsSqlPrimary();
    await _hydrateProductsSqlPrimary();
    doctors
      ..clear()
      ..addAll(await db.loadJsonCollection(kCollDoctor));
    patients
      ..clear()
      ..addAll(await db.loadJsonCollection(kCollPatient));
    await _hydrateSalesInvoicesSqlPrimary();
    await _hydratePurchasesSqlPrimary();
    stockTransferRecords
      ..clear()
      ..addAll(await db.loadJsonCollection(kCollStockTransfer));
    discountRules
      ..clear()
      ..addAll(await db.loadJsonCollection(kCollDiscountRule));
    schemeOffers
      ..clear()
      ..addAll(await db.loadJsonCollection(kCollScheme));
    doctorCommissions
      ..clear()
      ..addAll(await db.loadJsonCollection(kCollDocCommission));
    dailyClosingRecords
      ..clear()
      ..addAll(await db.loadJsonCollection(kCollDailyClosing));

    final am = await db.getAppKv(kKvAccountModule);
    if (am != null && am.isNotEmpty) {
      final decoded = jsonDecode(am);
      if (decoded is Map<String, dynamic>) {
        accountModuleRecords.clear();
        decoded.forEach((key, value) {
          if (value is List) {
            accountModuleRecords[key] = value
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
        });
      }
    }

    final gs = await db.getAppKv(kKvGlobalSettings);
    if (gs != null && gs.isNotEmpty) {
      final decoded = jsonDecode(gs);
      if (decoded is Map<String, dynamic>) {
        globalMedicalStoreSettings
          ..clear()
          ..addAll(Map<String, dynamic>.from(decoded));
      }
    }

    final lb = await db.getAppKv(kKvLastBackupAt);
    if (lb != null && lb.isNotEmpty) {
      lastAppBackupAt = DateTime.tryParse(lb);
    }

    await syncAllAccountModuleReceiptsPaymentsToMedSql();
    _relinkSeedsAfterHydrate();
    debugPrint(
      '[HYDRATE] done — accounts=${accounts.length} products=${products.length} '
      'salesInvoices=${salesInvoiceRecords.length} purchases=${purchaseBillRecords.length} '
      'doctors=${doctors.length} patients=${patients.length}',
    );
  } catch (e, st) {
    debugPrint('hydrateAppDataFromDatabase: $e\n$st');
  }
}

double _sqlNum(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim()) ?? 0;
}

/// App-shaped account row from relational [accounts] (SQL is canonical).
Map<String, dynamic> _appAccountMapFromMedRow(Map<String, Object?> r) {
  final id = r['id'];
  if (id is! int) return {};
  final addr = (r['address'] ?? '').toString();
  return <String, dynamic>{
    'id': id,
    'name': (r['name'] ?? '').toString(),
    'shortName': '',
    'mobile': (r['mobile'] ?? '').toString(),
    'city': (r['city'] ?? '').toString(),
    'gst': (r['gst'] ?? '').toString(),
    'address1': addr,
    'address2': '',
    'pin': '',
    'keyPerson': '',
    'phone': '',
    'email': '',
    'tinLst': '',
    'cstReg': '',
    'drugLic1': '',
    'drugLic2': '',
    'discount': '',
    'phone2': '',
    'fax': '',
    'pisCode': '',
    'date1': '',
    'date2': '',
    'drugLic3': '',
    'drugLic4': '',
    'openingBalance': _sqlNum(r['opening_balance']),
    'accountType': (r['account_type'] ?? 'Customer').toString(),
  };
}

/// App-shaped product row from relational [products] (SQL is canonical).
Map<String, dynamic> _appProductMapFromMedRow(Map<String, Object?> r) {
  final id = r['id'];
  if (id is! int) return {};
  final mrp = _sqlNum(r['mrp']);
  final saleRate = _sqlNum(r['sale_rate']);
  final stock = _sqlNum(r['stock']);
  final rq = _sqlNum(r['reorder_level']);
  final exp = (r['expiry_date'] ?? '').toString();
  final srStr = saleRate.toStringAsFixed(2);
  final costRate = saleRate * 0.85;
  final marginRs = saleRate - costRate;
  final marginPct = saleRate == 0 ? 0.0 : (marginRs / saleRate) * 100;
  return <String, dynamic>{
    'id': id,
    'name': (r['name'] ?? '').toString(),
    'description': '',
    'company': '',
    'purPack': '',
    'salesPack': '',
    'minStock': '',
    'maxStock': '',
    'mrp': mrp.toStringAsFixed(2),
    'vatOn': 'W/Rate',
    'favourite': '',
    'generic': '',
    'remarks': '',
    'discount': 'Yes',
    'hsn': (r['hsn'] ?? '').toString(),
    'purGst': 'GST 12% (P)',
    'salesGst': 'GST 12% (S)',
    'ratio': '',
    'reorderQty': rq > 0 ? rq.toStringAsFixed(0) : '',
    'expiryDate': exp,
    'expiry': 'Yes',
    'addVat': '',
    'taxOnRate': 'Inclusive',
    'barcode': (r['barcode'] ?? '').toString(),
    'category': 'TABLET',
    'schedule': '(none)',
    'wRate': srStr,
    'excise': '0.00',
    'suffered': '0.00',
    'cst': '0.00',
    'lst': '0.00',
    'lstRs': '0.00',
    'octroi': '0.00',
    'disc': '0.00',
    'saleRate': srStr,
    'costRate': costRate.toStringAsFixed(2),
    'margin': marginPct.toStringAsFixed(2),
    'marginRs': marginRs.toStringAsFixed(2),
    'stock': stock.toStringAsFixed(2),
  };
}

/// Load accounts from SQLite first; JSON documents only fill ids missing in SQL (backup).
Future<void> _hydrateAccountsSqlPrimary() async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) return;
  try {
    accounts.clear();
    for (final r in await db.fetchMedAccounts()) {
      final m = _appAccountMapFromMedRow(r);
      if (m.isEmpty) continue;
      accounts.add(m);
    }
    final have = accounts.map((a) => a['id']).whereType<int>().toSet();
    for (final row in await db.loadJsonCollection(kCollAccount)) {
      final id = row['id'];
      if (id is! int || have.contains(id)) continue;
      accounts.add(Map<String, dynamic>.from(row));
    }
    debugPrint('[HYDRATE] accounts loaded: ${accounts.length}');
  } catch (e, st) {
    debugPrint('_hydrateAccountsSqlPrimary: $e\n$st');
    accounts.clear();
    try {
      accounts.addAll(await db.loadJsonCollection(kCollAccount));
    } catch (e2, st2) {
      debugPrint('_hydrateAccountsSqlPrimary JSON fallback: $e2\n$st2');
    }
  }
}

/// Load products from SQLite first; JSON documents only fill ids missing in SQL (backup).
Future<void> _hydrateProductsSqlPrimary() async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) return;
  try {
    products.clear();
    for (final r in await db.fetchMedProducts()) {
      final m = _appProductMapFromMedRow(r);
      if (m.isEmpty) continue;
      products.add(m);
    }
    final have = products.map((p) => p['id']).whereType<int>().toSet();
    for (final row in await db.loadJsonCollection(kCollProduct)) {
      final id = row['id'];
      if (id is! int || have.contains(id)) continue;
      products.add(Map<String, dynamic>.from(row));
    }
    debugPrint('[HYDRATE] products loaded: ${products.length}');
  } catch (e, st) {
    debugPrint('_hydrateProductsSqlPrimary: $e\n$st');
    products.clear();
    try {
      products.addAll(await db.loadJsonCollection(kCollProduct));
    } catch (e2, st2) {
      debugPrint('_hydrateProductsSqlPrimary JSON fallback: $e2\n$st2');
    }
  }
}

/// Rebuilds one sales invoice document from relational [sales_invoices] + line items.
Future<Map<String, dynamic>?> _buildSalesInvoiceDocFromSql(
  Map<String, Object?> header,
) async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) return null;
  final id = header['id'];
  if (id is! int) return null;
  try {
    final rawItems = await db.fetchMedSalesInvoiceItems(id);
    final lines = <Map<String, dynamic>>[];
    for (final it in rawItems) {
      lines.add(<String, dynamic>{
        'sr': it['line_no'],
        'productId': it['product_id'],
        'productName': (it['product_name'] ?? '').toString(),
        'pack': (it['pack'] ?? '').toString(),
        'batch': (it['batch'] ?? '').toString(),
        'expiry': (it['expiry'] ?? '').toString(),
        'qty': _sqlNum(it['qty']),
        'free': _sqlNum(it['free_qty']),
        'rate': _sqlNum(it['rate']),
        'gstPercent': _sqlNum(it['gst_percent']),
        'amount': _sqlNum(it['amount']),
      });
    }
    return <String, dynamic>{
      'id': id,
      'module': (header['notes'] ?? '').toString(),
      'series': (header['series'] ?? '').toString(),
      'billNo': (header['bill_no'] ?? '').toString(),
      'date': (header['invoice_date'] ?? '').toString(),
      'party': (header['party_name'] ?? '').toString(),
      'accountId': header['account_id'],
      'doctor': (header['doctor'] ?? '').toString(),
      'patient': (header['patient'] ?? '').toString(),
      'gstType': 'GST Local',
      'address': '',
      'mobile': '',
      'discountPercent': _sqlNum(header['discount_percent']),
      'discountAmount': _sqlNum(header['discount_amount']),
      'schemeDiscount': _sqlNum(header['scheme_discount']),
      'subTotal': _sqlNum(header['subtotal']),
      'sgst': _sqlNum(header['sgst']),
      'cgst': _sqlNum(header['cgst']),
      'igst': _sqlNum(header['igst']),
      'roundOff': _sqlNum(header['round_off']),
      'grandTotal': _sqlNum(header['grand_total']),
      'items': lines,
    };
  } catch (e, st) {
    debugPrint('_buildSalesInvoiceDocFromSql id=$id: $e\n$st');
    return null;
  }
}

/// Rebuilds one purchase bill document from relational [purchases] + line items.
Future<Map<String, dynamic>?> _buildPurchaseDocFromSql(
  Map<String, Object?> header,
) async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) return null;
  final id = header['id'];
  if (id is! int) return null;
  try {
    final rawItems = await db.fetchMedPurchaseItems(id);
    final lines = <Map<String, dynamic>>[];
    for (final it in rawItems) {
      lines.add(<String, dynamic>{
        'sr': it['line_no'],
        'productId': it['product_id'],
        'productName': (it['product_name'] ?? '').toString(),
        'pack': (it['pack'] ?? '').toString(),
        'batch': (it['batch'] ?? '').toString(),
        'expiry': (it['expiry'] ?? '').toString(),
        'qty': _sqlNum(it['qty']),
        'free': _sqlNum(it['free_qty']),
        'rate': _sqlNum(it['rate']),
        'gstPercent': _sqlNum(it['gst_percent']),
        'amount': _sqlNum(it['amount']),
      });
    }
    return <String, dynamic>{
      'id': id,
      'module': (header['notes'] ?? '').toString(),
      'series': (header['series'] ?? '').toString(),
      'billNo': (header['bill_no'] ?? '').toString(),
      'date': (header['purchase_date'] ?? '').toString(),
      'party': (header['party_name'] ?? '').toString(),
      'accountId': header['supplier_account_id'],
      'doctor': '',
      'patient': '',
      'gstType': 'GST Local',
      'address': '',
      'mobile': '',
      'discountPercent': 0.0,
      'discountAmount': _sqlNum(header['discount_amount']),
      'schemeDiscount': _sqlNum(header['scheme_discount']),
      'subTotal': _sqlNum(header['subtotal']),
      'sgst': _sqlNum(header['sgst']),
      'cgst': _sqlNum(header['cgst']),
      'igst': _sqlNum(header['igst']),
      'roundOff': _sqlNum(header['round_off']),
      'grandTotal': _sqlNum(header['grand_total']),
      'items': lines,
    };
  } catch (e, st) {
    debugPrint('_buildPurchaseDocFromSql id=$id: $e\n$st');
    return null;
  }
}

/// Sales invoices: SQLite [sales_invoices] is canonical; JSON only fills missing ids.
Future<void> _hydrateSalesInvoicesSqlPrimary() async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) return;
  try {
    salesInvoiceRecords.clear();
    final headers = await db.fetchMedSalesInvoices();
    debugPrint('[HYDRATE] sales_invoices SQL headers: ${headers.length}');
    for (final h in headers) {
      final doc = await _buildSalesInvoiceDocFromSql(h);
      if (doc != null) {
        salesInvoiceRecords.add(doc);
      }
    }
    final have =
        salesInvoiceRecords.map((e) => e['id']).whereType<int>().toSet();
    final jsonRows = await db.loadJsonCollection(kCollSales);
    var orphan = 0;
    for (final row in jsonRows) {
      final id = row['id'];
      if (id is! int || have.contains(id)) continue;
      salesInvoiceRecords.add(Map<String, dynamic>.from(row));
      orphan++;
    }
    if (orphan > 0) {
      debugPrint(
        '[HYDRATE] merged $orphan sales invoice(s) from JSON only (no SQL row)',
      );
    }
  } catch (e, st) {
    debugPrint('_hydrateSalesInvoicesSqlPrimary: $e\n$st');
    salesInvoiceRecords.clear();
    try {
      salesInvoiceRecords.addAll(await db.loadJsonCollection(kCollSales));
      debugPrint(
        '[HYDRATE] sales invoices JSON fallback: ${salesInvoiceRecords.length}',
      );
    } catch (e2, st2) {
      debugPrint('_hydrateSalesInvoicesSqlPrimary JSON fallback: $e2\n$st2');
    }
  }
}

/// Purchase bills: SQLite [purchases] is canonical; JSON only fills missing ids.
Future<void> _hydratePurchasesSqlPrimary() async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) return;
  try {
    purchaseBillRecords.clear();
    final headers = await db.fetchMedPurchases();
    debugPrint('[HYDRATE] purchases SQL headers: ${headers.length}');
    for (final h in headers) {
      final doc = await _buildPurchaseDocFromSql(h);
      if (doc != null) {
        purchaseBillRecords.add(doc);
      }
    }
    final have =
        purchaseBillRecords.map((e) => e['id']).whereType<int>().toSet();
    final jsonRows = await db.loadJsonCollection(kCollPurchase);
    var orphan = 0;
    for (final row in jsonRows) {
      final id = row['id'];
      if (id is! int || have.contains(id)) continue;
      purchaseBillRecords.add(Map<String, dynamic>.from(row));
      orphan++;
    }
    if (orphan > 0) {
      debugPrint(
        '[HYDRATE] merged $orphan purchase(s) from JSON only (no SQL row)',
      );
    }
  } catch (e, st) {
    debugPrint('_hydratePurchasesSqlPrimary: $e\n$st');
    purchaseBillRecords.clear();
    try {
      purchaseBillRecords.addAll(await db.loadJsonCollection(kCollPurchase));
      debugPrint(
        '[HYDRATE] purchase bills JSON fallback: ${purchaseBillRecords.length}',
      );
    } catch (e2, st2) {
      debugPrint('_hydratePurchasesSqlPrimary JSON fallback: $e2\n$st2');
    }
  }
}

/// Stable PK for [payment_receipts] (Receipt / Payment share local ids in app).
int medSqlPaymentReceiptPrimaryKey(String moduleType, int localId) {
  final base = moduleType == 'Receipt' ? 100000000 : 200000000;
  return base + localId;
}

int? medResolveAccountIdByName(String name) {
  final k = name.trim().toLowerCase();
  if (k.isEmpty) return null;
  for (final a in accounts) {
    if ((a['name'] ?? '').toString().trim().toLowerCase() == k) {
      return a['id'] as int?;
    }
  }
  return null;
}

double medJsonReceiptsTotalForParty(String partyLower) {
  var t = 0.0;
  for (final r in accountModuleRecords['Receipt'] ?? const []) {
    if ((r['account'] ?? '').toString().trim().toLowerCase() == partyLower) {
      t += _sqlNum(r['amount']);
    }
  }
  return t;
}

double medJsonPaymentsTotalForParty(String partyLower) {
  var t = 0.0;
  for (final r in accountModuleRecords['Payment'] ?? const []) {
    if ((r['account'] ?? '').toString().trim().toLowerCase() == partyLower) {
      t += _sqlNum(r['amount']);
    }
  }
  return t;
}

Future<void> upsertAccountModuleRowToMedPaymentReceipt(
  Map<String, dynamic> row,
  String moduleType,
) async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) return;
  final localId = row['id'];
  if (localId is! int) return;
  final entry = moduleType == 'Receipt' ? 'receipt' : 'payment';
  final accName = (row['account'] ?? '').toString();
  final aid = medResolveAccountIdByName(accName);
  final sqlId = medSqlPaymentReceiptPrimaryKey(moduleType, localId);
  final ref = <String>[
    (row['voucherNo'] ?? '').toString(),
    (row['reference'] ?? '').toString(),
  ].where((s) => s.trim().isNotEmpty).join(' / ');
  await db.upsertMedPaymentReceiptRow({
    'id': sqlId,
    'entry_type': entry,
    'voucher_date': (row['date'] ?? '').toString(),
    'account_id': aid,
    'amount': _sqlNum(row['amount']),
    'reference_no': ref,
    'remarks': (row['remarks'] ?? '').toString(),
  });
}

Future<void> deleteAccountModuleRowFromMedPaymentReceipt(
  int localId,
  String moduleType,
) async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) return;
  await db.deleteMedPaymentReceipt(
    medSqlPaymentReceiptPrimaryKey(moduleType, localId),
  );
}

Future<void> syncAllAccountModuleReceiptsPaymentsToMedSql() async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) return;
  try {
    for (final r in accountModuleRecords['Receipt'] ??
        const <Map<String, dynamic>>[]) {
      await upsertAccountModuleRowToMedPaymentReceipt(
        Map<String, dynamic>.from(r),
        'Receipt',
      );
    }
    for (final r in accountModuleRecords['Payment'] ??
        const <Map<String, dynamic>>[]) {
      await upsertAccountModuleRowToMedPaymentReceipt(
        Map<String, dynamic>.from(r),
        'Payment',
      );
    }
  } catch (e, st) {
    debugPrint('syncAllAccountModuleReceiptsPaymentsToMedSql: $e\n$st');
  }
}

/// `ledger` = opening + sales − receipts + purchases − payments.
/// `pendingRec` / `pendingPay` = non‑negative UI pending by account type.
Future<Map<String, double>> medAccountBalanceBreakdown(
  Map<String, dynamic> accountRow,
) async {
  final db = HealthDatabase.instance;
  final id = accountRow['id'];
  final name = (accountRow['name'] ?? '').toString();
  final type =
      (accountRow['accountType'] ?? 'Customer').toString().toLowerCase();
  final opening = _sqlNum(accountRow['openingBalance']);
  final partyKey = name.trim().toLowerCase();
  final isSupplier =
      type.contains('supplier') ||
      type.contains('stockist') ||
      type.contains('creditor');

  if (id is! int || !db.hasPersistentSql) {
    final salesJ = medJsonSalesTotalForParty(partyKey);
    final purJ = medJsonPurchasesTotalForParty(partyKey);
    final recJ = medJsonReceiptsTotalForParty(partyKey);
    final payJ = medJsonPaymentsTotalForParty(partyKey);
    final ledger = opening + salesJ - recJ + purJ - payJ;
    final pendingRec = isSupplier
        ? 0.0
        : (opening + salesJ - recJ).clamp(0.0, double.infinity);
    final pendingPay = isSupplier
        ? (opening + purJ - payJ).clamp(0.0, double.infinity)
        : 0.0;
    return {
      'ledger': ledger,
      'pendingRec': pendingRec,
      'pendingPay': pendingPay,
    };
  }

  final sales = await db.medSqlSumSalesForAccount(
    accountId: id,
    partyNameLower: name,
  );
  final purchases = await db.medSqlSumPurchasesForAccount(
    accountId: id,
    partyNameLower: name,
  );
  var receipts = await db.medSqlSumReceiptsForAccount(id);
  var payments = await db.medSqlSumPaymentsForAccount(id);
  if (receipts < 0.000001) {
    receipts = medJsonReceiptsTotalForParty(partyKey);
  }
  if (payments < 0.000001) {
    payments = medJsonPaymentsTotalForParty(partyKey);
  }

  final ledger = opening + sales - receipts + purchases - payments;
  final pendingRec = isSupplier
      ? 0.0
      : (opening + sales - receipts).clamp(0.0, double.infinity);
  final pendingPay = isSupplier
      ? (opening + purchases - payments).clamp(0.0, double.infinity)
      : 0.0;
  return {
    'ledger': ledger,
    'pendingRec': pendingRec,
    'pendingPay': pendingPay,
  };
}

double medJsonSalesTotalForParty(String partyLower) {
  var t = 0.0;
  for (final inv in salesInvoiceRecords) {
    if ((inv['party'] ?? '').toString().trim().toLowerCase() == partyLower) {
      t += _sqlNum(inv['grandTotal']);
    }
  }
  return t;
}

double medJsonPurchasesTotalForParty(String partyLower) {
  var t = 0.0;
  for (final inv in purchaseBillRecords) {
    if ((inv['party'] ?? '').toString().trim().toLowerCase() == partyLower) {
      t += _sqlNum(inv['grandTotal']);
    }
  }
  return t;
}

/// Sum of non‑negative receivable pending for customer‑type accounts (JSON only).
double medApproxCustomerPendingTotal() {
  var total = 0.0;
  for (final a in accounts) {
    final type = (a['accountType'] ?? 'Customer').toString().toLowerCase();
    if (type.contains('supplier') ||
        type.contains('stockist') ||
        type.contains('creditor')) {
      continue;
    }
    final partyKey = (a['name'] ?? '').toString().trim().toLowerCase();
    final opening = _sqlNum(a['openingBalance']);
    final salesJ = medJsonSalesTotalForParty(partyKey);
    final recJ = medJsonReceiptsTotalForParty(partyKey);
    total += (opening + salesJ - recJ).clamp(0.0, double.infinity);
  }
  return total;
}

Future<double> medTotalCustomerPendingReceivableSql() async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) {
    return medApproxCustomerPendingTotal();
  }
  var total = 0.0;
  for (final a in accounts) {
    final type =
        (a['accountType'] ?? 'Customer').toString().toLowerCase();
    if (type.contains('supplier') ||
        type.contains('stockist') ||
        type.contains('creditor')) {
      continue;
    }
    final br = await medAccountBalanceBreakdown(a);
    total += br['pendingRec'] ?? 0;
  }
  return total;
}

Future<void> syncSalesOrPurchaseDocumentToRelational(
  Map<String, dynamic> document, {
  Map<String, dynamic>? previousDoc,
  required bool isPurchase,
}) async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) return;
  Future<void> sqlStockEffect(
    Map<String, dynamic> doc, {
    required bool purchase,
    required bool undo,
  }) async {
    final items = (doc['items'] as List?) ?? [];
    for (final raw in items) {
      if (raw is! Map) continue;
      final it = Map<String, dynamic>.from(raw);
      final pid = it['productId'];
      if (pid is! int) continue;
      final q = _sqlNum(it['qty']) + _sqlNum(it['free']);
      if (q <= 0) continue;
      final delta = purchase
          ? (undo ? -q : q)
          : (undo ? q : -q);
      await db.medApplyProductStockDelta(pid, delta);
    }
  }

  try {
    if (previousDoc != null) {
      await sqlStockEffect(previousDoc, purchase: isPurchase, undo: true);
    }
    if (isPurchase) {
      await db.replaceMedPurchaseFromDocument(document);
    } else {
      await db.replaceMedSalesInvoiceFromDocument(document);
    }
    await sqlStockEffect(document, purchase: isPurchase, undo: false);
  } catch (e, st) {
    debugPrint('syncSalesOrPurchaseDocumentToRelational: $e\n$st');
    rethrow;
  }
}

void _relinkSeedsAfterHydrate() {
  var maxA = 0;
  for (final a in accounts) {
    final id = a['id'];
    if (id is int && id > maxA) maxA = id;
  }
  if (maxA >= _accountSeed) _accountSeed = maxA + 1;

  var maxP = 0;
  for (final a in products) {
    final id = a['id'];
    if (id is int && id > maxP) maxP = id;
  }
  if (maxP >= _productSeed) _productSeed = maxP + 1;

  var maxD = 0;
  for (final a in doctors) {
    final id = a['id'];
    if (id is int && id > maxD) maxD = id;
  }
  if (maxD >= _doctorSeed) _doctorSeed = maxD + 1;

  var maxS = 0;
  for (final a in salesInvoiceRecords) {
    final id = a['id'];
    if (id is int && id > maxS) maxS = id;
    final bill = int.tryParse((a['billNo'] ?? '').toString());
    if (bill != null && bill > maxS) maxS = bill;
  }
  if (maxS >= _salesInvoiceSeed) _salesInvoiceSeed = maxS + 1;

  var maxPur = 0;
  for (final a in purchaseBillRecords) {
    final id = a['id'];
    if (id is int && id > maxPur) maxPur = id;
    final bill = int.tryParse((a['billNo'] ?? '').toString());
    if (bill != null && bill > maxPur) maxPur = bill;
  }
  if (maxPur >= _purchaseBillSeed) _purchaseBillSeed = maxPur + 1;

  var maxSt = 0;
  for (final a in stockTransferRecords) {
    final id = a['id'];
    if (id is int && id > maxSt) maxSt = id;
    final tn = (a['transferNo'] ?? '').toString();
    final m = RegExp(r'(\d+)\s*$').firstMatch(tn);
    final n = m != null ? int.tryParse(m.group(1)!) : null;
    if (n != null && n > maxSt) maxSt = n;
  }
  if (maxSt >= _stockTransferSeed) _stockTransferSeed = maxSt + 1;

  var maxCl = 0;
  for (final a in dailyClosingRecords) {
    final id = a['closingId'];
    if (id is int && id > maxCl) maxCl = id;
  }
  if (maxCl >= _dailyClosingSeed) _dailyClosingSeed = maxCl + 1;

  var maxDr = 0;
  for (final a in discountRules) {
    final id = a['id'];
    if (id is int && id > maxDr) maxDr = id;
  }
  if (maxDr >= _discountRuleSeed) _discountRuleSeed = maxDr + 1;

  var maxSc = 0;
  for (final a in schemeOffers) {
    final id = a['id'];
    if (id is int && id > maxSc) maxSc = id;
  }
  if (maxSc >= _schemeOfferSeed) _schemeOfferSeed = maxSc + 1;

  var maxDc = 0;
  for (final a in doctorCommissions) {
    final id = a['id'];
    if (id is int && id > maxDc) maxDc = id;
  }
  if (maxDc >= _doctorCommissionSeed) _doctorCommissionSeed = maxDc + 1;

  var maxPt = 0;
  for (final a in patients) {
    final id = a['id'];
    if (id is int && id > maxPt) maxPt = id;
  }
  if (maxPt >= _patientSeed) _patientSeed = maxPt + 1;
}

Future<void> persistAccountRow(Map<String, dynamic> row) async {
  final id = row['id'];
  if (id is! int) return;
  final copy = Map<String, dynamic>.from(row);
  final db = HealthDatabase.instance;
  if (db.hasPersistentSql) {
    try {
      await db.upsertMedAccountFromAppRow(copy);
    } catch (e, st) {
      debugPrint('persistAccountRow (SQL): $e\n$st');
    }
  }
  try {
    await db.upsertJsonDocument(kCollAccount, id, copy);
    debugPrint('[SAVE] account id=$id → SQLite + json_documents OK');
  } catch (e, st) {
    debugPrint('persistAccountRow (JSON backup): $e\n$st');
    rethrow;
  }
}

Future<void> deleteAccountRow(int id) async {
  final db = HealthDatabase.instance;
  if (db.hasPersistentSql) {
    try {
      await db.deleteMedAccount(id);
    } catch (e, st) {
      debugPrint('deleteAccountRow (SQL): $e\n$st');
    }
  }
  try {
    await db.deleteJsonDocument(kCollAccount, id);
  } catch (e, st) {
    debugPrint('deleteAccountRow (JSON): $e\n$st');
    rethrow;
  }
}

Future<void> persistProductRow(Map<String, dynamic> row) async {
  final id = row['id'];
  if (id is! int) return;
  final copy = Map<String, dynamic>.from(row);
  final db = HealthDatabase.instance;
  if (db.hasPersistentSql) {
    try {
      await db.upsertMedProductFromAppRow(copy);
    } catch (e, st) {
      debugPrint('persistProductRow (SQL): $e\n$st');
    }
  }
  try {
    await db.upsertJsonDocument(kCollProduct, id, copy);
    debugPrint('[SAVE] product id=$id → SQLite + json_documents OK');
  } catch (e, st) {
    debugPrint('persistProductRow (JSON backup): $e\n$st');
    rethrow;
  }
}

Future<void> deleteProductRow(int id) async {
  final db = HealthDatabase.instance;
  if (db.hasPersistentSql) {
    try {
      await db.deleteMedProduct(id);
    } catch (e, st) {
      debugPrint('deleteProductRow (SQL): $e\n$st');
    }
  }
  try {
    await db.deleteJsonDocument(kCollProduct, id);
  } catch (e, st) {
    debugPrint('deleteProductRow (JSON): $e\n$st');
    rethrow;
  }
}

Future<void> persistDoctorRow(Map<String, dynamic> row) async {
  try {
    final id = row['id'];
    if (id is! int) return;
    await HealthDatabase.instance.upsertJsonDocument(
      kCollDoctor,
      id,
      Map<String, dynamic>.from(row),
    );
  } catch (e, st) {
    debugPrint('persistDoctorRow: $e\n$st');
    rethrow;
  }
}

Future<void> persistPatientRow(Map<String, dynamic> row) async {
  try {
    final id = row['id'];
    if (id is! int) return;
    await HealthDatabase.instance.upsertJsonDocument(
      kCollPatient,
      id,
      Map<String, dynamic>.from(row),
    );
    debugPrint('[SAVE] patient id=$id → json_documents OK');
  } catch (e, st) {
    debugPrint('persistPatientRow: $e\n$st');
    rethrow;
  }
}

Future<void> deleteDoctorRow(int id) async {
  try {
    await HealthDatabase.instance.deleteJsonDocument(kCollDoctor, id);
  } catch (e, st) {
    debugPrint('deleteDoctorRow: $e\n$st');
    rethrow;
  }
}

Future<void> persistSalesInvoiceDoc(Map<String, dynamic> doc) async {
  try {
    final id = doc['id'];
    if (id is! int) return;
    await HealthDatabase.instance.upsertJsonDocument(
      kCollSales,
      id,
      Map<String, dynamic>.from(doc),
    );
    debugPrint(
      '[SAVE] sales invoice id=$id → json_documents OK (relational mirror on save)',
    );
  } catch (e, st) {
    debugPrint('persistSalesInvoiceDoc: $e\n$st');
    rethrow;
  }
}

Future<void> deleteSalesInvoiceDoc(int id) async {
  final db = HealthDatabase.instance;
  if (db.hasPersistentSql) {
    try {
      await db.deleteMedSalesInvoice(id);
      debugPrint('[DELETE] sales invoice id=$id removed from SQLite');
    } catch (e, st) {
      debugPrint('deleteSalesInvoiceDoc (SQL): $e\n$st');
    }
  }
  try {
    await HealthDatabase.instance.deleteJsonDocument(kCollSales, id);
    debugPrint('[DELETE] sales invoice id=$id removed from json_documents');
  } catch (e, st) {
    debugPrint('deleteSalesInvoiceDoc (JSON): $e\n$st');
    rethrow;
  }
}

Future<void> persistPurchaseBillDoc(Map<String, dynamic> doc) async {
  try {
    final id = doc['id'];
    if (id is! int) return;
    await HealthDatabase.instance.upsertJsonDocument(
      kCollPurchase,
      id,
      Map<String, dynamic>.from(doc),
    );
    debugPrint(
      '[SAVE] purchase bill id=$id → json_documents OK (relational mirror on save)',
    );
  } catch (e, st) {
    debugPrint('persistPurchaseBillDoc: $e\n$st');
    rethrow;
  }
}

Future<void> deletePurchaseBillDoc(int id) async {
  final db = HealthDatabase.instance;
  if (db.hasPersistentSql) {
    try {
      await db.deleteMedPurchase(id);
      debugPrint('[DELETE] purchase id=$id removed from SQLite');
    } catch (e, st) {
      debugPrint('deletePurchaseBillDoc (SQL): $e\n$st');
    }
  }
  try {
    await HealthDatabase.instance.deleteJsonDocument(kCollPurchase, id);
    debugPrint('[DELETE] purchase id=$id removed from json_documents');
  } catch (e, st) {
    debugPrint('deletePurchaseBillDoc (JSON): $e\n$st');
    rethrow;
  }
}

Future<void> persistStockTransferDoc(Map<String, dynamic> doc) async {
  try {
    final id = doc['id'];
    final int docId = id is int ? id : doc.hashCode;
    await HealthDatabase.instance.upsertJsonDocument(
      kCollStockTransfer,
      docId,
      Map<String, dynamic>.from(doc),
    );
  } catch (e, st) {
    debugPrint('persistStockTransferDoc: $e\n$st');
  }
}

Future<void> deleteStockTransferDoc(int id) async {
  try {
    await HealthDatabase.instance.deleteJsonDocument(kCollStockTransfer, id);
  } catch (e, st) {
    debugPrint('deleteStockTransferDoc: $e\n$st');
  }
}

Future<void> persistAccountModuleSnapshot() async {
  try {
    final payload = <String, dynamic>{};
    accountModuleRecords.forEach((k, v) {
      payload[k] = v.map((e) => Map<String, dynamic>.from(e)).toList();
    });
    await HealthDatabase.instance.putAppKv(
      kKvAccountModule,
      jsonEncode(payload),
    );
  } catch (e, st) {
    debugPrint('persistAccountModuleSnapshot: $e\n$st');
  }
}

Future<void> persistGlobalSettingsSnapshot() async {
  try {
    await HealthDatabase.instance.putAppKv(
      kKvGlobalSettings,
      jsonEncode(Map<String, dynamic>.from(globalMedicalStoreSettings)),
    );
  } catch (e, st) {
    debugPrint('persistGlobalSettingsSnapshot: $e\n$st');
  }
}

Future<void> persistDiscountRule(Map<String, dynamic> row) async {
  try {
    final id = row['id'];
    if (id is! int) return;
    await HealthDatabase.instance.upsertJsonDocument(
      kCollDiscountRule,
      id,
      Map<String, dynamic>.from(row),
    );
  } catch (e, st) {
    debugPrint('persistDiscountRule: $e\n$st');
  }
}

Future<void> persistSchemeOffer(Map<String, dynamic> row) async {
  try {
    final id = row['id'];
    if (id is! int) return;
    await HealthDatabase.instance.upsertJsonDocument(
      kCollScheme,
      id,
      Map<String, dynamic>.from(row),
    );
  } catch (e, st) {
    debugPrint('persistSchemeOffer: $e\n$st');
  }
}

Future<void> persistDoctorCommission(Map<String, dynamic> row) async {
  try {
    final id = row['id'];
    if (id is! int) return;
    await HealthDatabase.instance.upsertJsonDocument(
      kCollDocCommission,
      id,
      Map<String, dynamic>.from(row),
    );
  } catch (e, st) {
    debugPrint('persistDoctorCommission: $e\n$st');
  }
}

Future<void> persistDailyClosing(Map<String, dynamic> row) async {
  try {
    final id = row['closingId'];
    final int docId = id is int ? id : row.hashCode;
    await HealthDatabase.instance.upsertJsonDocument(
      kCollDailyClosing,
      docId,
      Map<String, dynamic>.from(row),
    );
  } catch (e, st) {
    debugPrint('persistDailyClosing: $e\n$st');
  }
}

Future<void> deleteJsonDocById(String collection, int id) async {
  try {
    await HealthDatabase.instance.deleteJsonDocument(collection, id);
  } catch (e, st) {
    debugPrint('deleteJsonDocById($collection,$id): $e\n$st');
  }
}

Map<String, dynamic> buildFullExportMap() {
  final am = <String, dynamic>{};
  accountModuleRecords.forEach((k, v) {
    am[k] = v.map((e) => Map<String, dynamic>.from(e)).toList();
  });
  return {
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'accounts': accounts.map((e) => Map<String, dynamic>.from(e)).toList(),
    'products': products.map((e) => Map<String, dynamic>.from(e)).toList(),
    'doctors': doctors.map((e) => Map<String, dynamic>.from(e)).toList(),
    'salesInvoiceRecords':
        salesInvoiceRecords.map((e) => Map<String, dynamic>.from(e)).toList(),
    'purchaseBillRecords':
        purchaseBillRecords.map((e) => Map<String, dynamic>.from(e)).toList(),
    'stockTransferRecords':
        stockTransferRecords.map((e) => Map<String, dynamic>.from(e)).toList(),
    'discountRules': discountRules.map((e) => Map<String, dynamic>.from(e)).toList(),
    'schemeOffers': schemeOffers.map((e) => Map<String, dynamic>.from(e)).toList(),
    'doctorCommissions':
        doctorCommissions.map((e) => Map<String, dynamic>.from(e)).toList(),
    'dailyClosingRecords':
        dailyClosingRecords.map((e) => Map<String, dynamic>.from(e)).toList(),
    'accountModuleRecords': am,
    'globalMedicalStoreSettings':
        Map<String, dynamic>.from(globalMedicalStoreSettings),
    'seeds': {
      'account': _accountSeed,
      'product': _productSeed,
      'doctor': _doctorSeed,
      'sales': _salesInvoiceSeed,
      'purchase': _purchaseBillSeed,
      'stockTransfer': _stockTransferSeed,
      'dailyClosing': _dailyClosingSeed,
      'discountRule': _discountRuleSeed,
      'scheme': _schemeOfferSeed,
      'doctorCommission': _doctorCommissionSeed,
    },
  };
}

Future<String> exportFullSystemJsonString() async {
  return JsonEncoder.withIndent('  ').convert(buildFullExportMap());
}

Future<void> applyFullSystemImportFromJsonString(String raw) async {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Root must be a JSON object');
  }
  final m = Map<String, dynamic>.from(decoded);
  void repList(String key, List<Map<String, dynamic>> target) {
    final v = m[key];
    if (v is List) {
      target
        ..clear()
        ..addAll(v.map((e) => Map<String, dynamic>.from(e as Map)));
    }
  }

  repList('accounts', accounts);
  repList('products', products);
  repList('doctors', doctors);
  repList('salesInvoiceRecords', salesInvoiceRecords);
  repList('purchaseBillRecords', purchaseBillRecords);
  repList('stockTransferRecords', stockTransferRecords);
  repList('discountRules', discountRules);
  repList('schemeOffers', schemeOffers);
  repList('doctorCommissions', doctorCommissions);
  repList('dailyClosingRecords', dailyClosingRecords);

  final am = m['accountModuleRecords'];
  accountModuleRecords.clear();
  if (am is Map<String, dynamic>) {
    am.forEach((key, value) {
      if (value is List) {
        accountModuleRecords[key] = value
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    });
  }

  final gs = m['globalMedicalStoreSettings'];
  if (gs is Map<String, dynamic>) {
    globalMedicalStoreSettings
      ..clear()
      ..addAll(Map<String, dynamic>.from(gs));
  }

  final seeds = m['seeds'];
  if (seeds is Map<String, dynamic>) {
    _accountSeed = (seeds['account'] as num?)?.toInt() ?? _accountSeed;
    _productSeed = (seeds['product'] as num?)?.toInt() ?? _productSeed;
    _doctorSeed = (seeds['doctor'] as num?)?.toInt() ?? _doctorSeed;
    _salesInvoiceSeed = (seeds['sales'] as num?)?.toInt() ?? _salesInvoiceSeed;
    _purchaseBillSeed = (seeds['purchase'] as num?)?.toInt() ?? _purchaseBillSeed;
    _stockTransferSeed =
        (seeds['stockTransfer'] as num?)?.toInt() ?? _stockTransferSeed;
    _dailyClosingSeed =
        (seeds['dailyClosing'] as num?)?.toInt() ?? _dailyClosingSeed;
    _discountRuleSeed =
        (seeds['discountRule'] as num?)?.toInt() ?? _discountRuleSeed;
    _schemeOfferSeed = (seeds['scheme'] as num?)?.toInt() ?? _schemeOfferSeed;
    _doctorCommissionSeed =
        (seeds['doctorCommission'] as num?)?.toInt() ?? _doctorCommissionSeed;
  } else {
    _relinkSeedsAfterHydrate();
  }

  final ex = m['exportedAt'];
  if (ex is String) {
    lastAppBackupAt = DateTime.tryParse(ex) ?? lastAppBackupAt;
  }

  await rewriteAllPersistentCollections();
}

Future<void> rewriteAllPersistentCollections() async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) return;
  try {
    final batch = (await db.database).batch();
    batch.delete('json_documents', where: 'collection = ?', whereArgs: [kCollAccount]);
    batch.delete('json_documents', where: 'collection = ?', whereArgs: [kCollProduct]);
    batch.delete('json_documents', where: 'collection = ?', whereArgs: [kCollDoctor]);
    batch.delete('json_documents', where: 'collection = ?', whereArgs: [kCollPatient]);
    batch.delete('json_documents', where: 'collection = ?', whereArgs: [kCollSales]);
    batch.delete('json_documents', where: 'collection = ?', whereArgs: [kCollPurchase]);
    batch.delete('json_documents', where: 'collection = ?', whereArgs: [kCollStockTransfer]);
    batch.delete('json_documents', where: 'collection = ?', whereArgs: [kCollDiscountRule]);
    batch.delete('json_documents', where: 'collection = ?', whereArgs: [kCollScheme]);
    batch.delete('json_documents', where: 'collection = ?', whereArgs: [kCollDocCommission]);
    batch.delete('json_documents', where: 'collection = ?', whereArgs: [kCollDailyClosing]);
    await batch.commit(noResult: true);

    for (final a in accounts) {
      await persistAccountRow(a);
    }
    for (final a in products) {
      await persistProductRow(a);
    }
    for (final a in doctors) {
      await persistDoctorRow(a);
    }
    for (final a in patients) {
      await persistPatientRow(a);
    }
    for (final a in salesInvoiceRecords) {
      await persistSalesInvoiceDoc(a);
    }
    for (final a in purchaseBillRecords) {
      await persistPurchaseBillDoc(a);
    }
    for (final a in stockTransferRecords) {
      await persistStockTransferDoc(a);
    }
    for (final a in discountRules) {
      await persistDiscountRule(a);
    }
    for (final a in schemeOffers) {
      await persistSchemeOffer(a);
    }
    for (final a in doctorCommissions) {
      await persistDoctorCommission(a);
    }
    for (final a in dailyClosingRecords) {
      await persistDailyClosing(a);
    }
    await persistAccountModuleSnapshot();
    await persistGlobalSettingsSnapshot();
  } catch (e, st) {
    debugPrint('rewriteAllPersistentCollections: $e\n$st');
  }
}

Future<void> _refreshInMemoryProductStockFromSql() async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) return;
  for (var i = 0; i < products.length; i++) {
    final id = products[i]['id'] as int?;
    if (id == null) continue;
    try {
      final r = await db.fetchMedProductById(id);
      if (r != null) {
        products[i]['stock'] = _sqlNum(r['stock']).toStringAsFixed(2);
      }
    } catch (e, st) {
      debugPrint('_refreshInMemoryProductStockFromSql id=$id: $e\n$st');
    }
  }
}

Map<String, dynamic> _demoTaxTotals(
  List<Map<String, dynamic>> items, {
  double discountPercent = 0,
  double discountAmountFixed = 0,
  double schemeDiscount = 0,
}) {
  var sub = 0.0;
  for (final it in items) {
    sub += _sqlNum(it['qty']) * _sqlNum(it['rate']);
  }
  final pctDisc = sub * (discountPercent / 100);
  final totalDisc = pctDisc + discountAmountFixed + schemeDiscount;
  final taxable = (sub - totalDisc).clamp(0.0, double.infinity);
  const taxP = 12.0;
  final taxAmt = taxable * (taxP / 100);
  final cgst = taxAmt / 2;
  final sgst = taxAmt / 2;
  final before = taxable + cgst + sgst;
  final roundOff = before.roundToDouble() - before;
  return <String, dynamic>{
    'subTotal': sub,
    'discountPercent': discountPercent,
    'discountAmount': discountAmountFixed,
    'schemeDiscount': schemeDiscount,
    'sgst': sgst,
    'cgst': cgst,
    'igst': 0.0,
    'roundOff': roundOff,
    'grandTotal': before + roundOff,
  };
}

Map<String, dynamic> _demoLine({
  required int lineNo,
  required int productId,
  required String productName,
  required double qty,
  double free = 0,
  required double rate,
  double gstPercent = 12,
}) {
  final amt = qty * rate;
  return <String, dynamic>{
    'sr': lineNo,
    'productId': productId,
    'productName': productName,
    'pack': '1 strip',
    'batch': 'DEMO${(productId * 17 + lineNo) % 900000}',
    'expiry': '2027-12-31',
    'qty': qty,
    'free': free,
    'rate': rate,
    'gstPercent': gstPercent,
    'amount': amt,
  };
}

Map<String, dynamic> _demoProductRow({
  required int id,
  required String name,
  required String company,
  required String category,
  required double mrp,
  required double saleRate,
  required double stock,
  String salesGst = 'GST 12% (S)',
  String? expiryDate,
  String? batchNo,
  String? purGst,
}) {
  final srStr = saleRate.toStringAsFixed(2);
  final costRate = saleRate * 0.85;
  final marginRs = saleRate - costRate;
  final marginPct = saleRate == 0 ? 0.0 : (marginRs / saleRate) * 100;
  final out = <String, dynamic>{
    'id': id,
    'name': name,
    'description': '',
    'company': company,
    'purPack': '1',
    'salesPack': '1',
    'minStock': '10',
    'maxStock': '500',
    'mrp': mrp.toStringAsFixed(2),
    'vatOn': 'W/Rate',
    'favourite': '',
    'generic': '',
    'remarks': '',
    'discount': 'Yes',
    'hsn': '3004',
    'purGst': purGst ?? 'GST 12% (P)',
    'salesGst': salesGst,
    'ratio': '',
    'reorderQty': '20',
    'expiryDate': expiryDate ?? '2027-12-31',
    'expiry': 'Yes',
    'addVat': '',
    'taxOnRate': 'Inclusive',
    'barcode': 'DEMO$id',
    'category': category,
    'schedule': 'H',
    'wRate': srStr,
    'excise': '0.00',
    'suffered': '0.00',
    'cst': '0.00',
    'lst': '0.00',
    'lstRs': '0.00',
    'octroi': '0.00',
    'disc': '0.00',
    'saleRate': srStr,
    'costRate': costRate.toStringAsFixed(2),
    'margin': marginPct.toStringAsFixed(2),
    'marginRs': marginRs.toStringAsFixed(2),
    'stock': stock.toStringAsFixed(2),
  };
  if (batchNo != null && batchNo.isNotEmpty) {
    out['batch'] = batchNo;
  }
  return out;
}

/// One-time realistic demo dataset when the store has no accounts and no products yet.
Future<void> seedDemoData() async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) {
    debugPrint('[DEMO] skip seedDemoData: no persistent SQLite');
    return;
  }
  if (accounts.isNotEmpty || products.isNotEmpty) {
    debugPrint(
      '[DEMO] skip seedDemoData: data already present '
      '(accounts=${accounts.length} products=${products.length})',
    );
    return;
  }

  debugPrint('[DEMO] seedDemoData: inserting presentation dataset…');

  const int a0 = 50100;
  final accountRows = <Map<String, dynamic>>[
    {
      'id': a0,
      'name': 'Rahul Patel',
      'shortName': 'Rahul',
      'mobile': '9879012345',
      'city': 'Anand',
      'gst': '24AAAAA0000A1Z5',
      'address1': 'Station Road, Anand',
      'address2': '',
      'pin': '388001',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 1200.0,
      'accountType': 'Customer',
    },
    {
      'id': a0 + 1,
      'name': 'Priya Shah',
      'shortName': 'Priya',
      'mobile': '9879022345',
      'city': 'Ahmedabad',
      'gst': '24BBBBB0000B1Z5',
      'address1': 'Navrangpura, Ahmedabad',
      'address2': '',
      'pin': '380009',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 0.0,
      'accountType': 'Customer',
    },
    {
      'id': a0 + 2,
      'name': 'Amit Kumar',
      'shortName': 'Amit',
      'mobile': '9879033345',
      'city': 'Surat',
      'gst': '24CCCCC0000C1Z5',
      'address1': 'Ring Road, Surat',
      'address2': '',
      'pin': '395007',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 500.0,
      'accountType': 'Customer',
    },
    {
      'id': a0 + 3,
      'name': 'Neha Joshi',
      'shortName': 'Neha',
      'mobile': '9879044345',
      'city': 'Vadodara',
      'gst': '24DDDDD0000D1Z5',
      'address1': 'Alkapuri, Vadodara',
      'address2': '',
      'pin': '390007',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 0.0,
      'accountType': 'Customer',
    },
    {
      'id': a0 + 4,
      'name': 'Vikram Singh',
      'shortName': 'Vikram',
      'mobile': '9879055345',
      'city': 'Rajkot',
      'gst': '24EEEEE0000E1Z5',
      'address1': 'Kalawad Road, Rajkot',
      'address2': '',
      'pin': '360005',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 2500.0,
      'accountType': 'Customer',
    },
    {
      'id': a0 + 5,
      'name': 'Kiran Desai',
      'shortName': 'Kiran',
      'mobile': '9879066345',
      'city': 'Anand',
      'gst': '24FFFFF0000F1Z5',
      'address1': 'Vidhyanagar, Anand',
      'address2': '',
      'pin': '388120',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 0.0,
      'accountType': 'Customer',
    },
    {
      'id': a0 + 6,
      'name': 'ABC Pharma Distributor',
      'shortName': 'ABC',
      'mobile': '9825011111',
      'city': 'Ahmedabad',
      'gst': '24GGGGG0000G1Z5',
      'address1': 'GIDC Vatva, Ahmedabad',
      'address2': '',
      'pin': '382445',
      'keyPerson': 'Mr. Joshi',
      'phone': '079-12345678',
      'email': 'abc@pharma.in',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': 'GJ-AHD-12345',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 15000.0,
      'accountType': 'Supplier',
    },
    {
      'id': a0 + 7,
      'name': 'MedPlus Supplier',
      'shortName': 'MedPlus',
      'mobile': '9825022222',
      'city': 'Surat',
      'gst': '24HHHHH0000H1Z5',
      'address1': 'Hazira, Surat',
      'address2': '',
      'pin': '394510',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 8000.0,
      'accountType': 'Supplier',
    },
    {
      'id': a0 + 8,
      'name': 'Sun Pharma Wholesaler',
      'shortName': 'SunDist',
      'mobile': '9825033333',
      'city': 'Vadodara',
      'gst': '24IIIII0000I1Z5',
      'address1': 'Alembic Road, Vadodara',
      'address2': '',
      'pin': '390023',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 22000.0,
      'accountType': 'Supplier',
    },
    {
      'id': a0 + 9,
      'name': 'Krishna Distributors',
      'shortName': 'Krishna',
      'mobile': '9825044444',
      'city': 'Rajkot',
      'gst': '24JJJJJ0000J1Z5',
      'address1': 'Shapar, Rajkot',
      'address2': '',
      'pin': '360024',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 5000.0,
      'accountType': 'Supplier',
    },
  ];
  for (final row in accountRows) {
    accounts.add(Map<String, dynamic>.from(row));
    await persistAccountRow(accounts.last);
  }

  const int p0 = 50200;
  final productDefs = <List<Object>>[
    ['Paracetamol 500 mg', 'Cipla', 'TABLET', 25.0, 22.0, 220.0],
    ['Crocin Advance', 'GSK', 'TABLET', 45.0, 40.0, 200.0],
    ['Dolo 650', 'Micro Labs', 'TABLET', 38.0, 34.0, 210.0],
    ['Azithromycin 500 mg', 'Alembic', 'TABLET', 120.0, 105.0, 180.0],
    ['Amoxicillin 250 mg', 'Dr Reddy', 'Capsule', 55.0, 48.0, 190.0],
    ['Pantoprazole 40 mg', 'Sun Pharma', 'TABLET', 95.0, 82.0, 170.0],
    ['ORS Powder', 'WHO', 'Powder', 22.0, 18.0, 300.0],
    ['Vitamin D3 Capsules', 'Cadila', 'Capsule', 180.0, 155.0, 160.0],
    ['Insulin Injection', 'Novo Nordisk', 'Injection', 420.0, 390.0, 120.0],
    ['Cetirizine 10 mg', 'Alkem', 'TABLET', 12.0, 9.5, 260.0],
    ['Ibuprofen 400 mg', 'Abbott', 'TABLET', 28.0, 24.0, 200.0],
    ['Metformin 500 mg', 'USV', 'TABLET', 32.0, 28.0, 210.0],
    ['Omeprazole 20 mg', 'Torrent', 'Capsule', 48.0, 42.0, 185.0],
    ['Azithral 500', 'Pfizer', 'TABLET', 135.0, 118.0, 140.0],
    ['Electral ORS', 'FDC', 'Powder', 24.0, 20.0, 280.0],
    ['Zincovit', 'Apex', 'TABLET', 95.0, 85.0, 175.0],
    ['Calcium + D3', 'Mankind', 'TABLET', 110.0, 98.0, 165.0],
    ['Salbutamol Inhaler', 'Cipla', 'Inhaler', 120.0, 105.0, 130.0],
  ];
  for (var i = 0; i < productDefs.length; i++) {
    final d = productDefs[i];
    final row = _demoProductRow(
      id: p0 + i,
      name: d[0] as String,
      company: d[1] as String,
      category: d[2] as String,
      mrp: d[3] as double,
      saleRate: d[4] as double,
      stock: d[5] as double,
    );
    products.add(row);
    await persistProductRow(products.last);
  }

  const int d0 = 50300;
  final doctorRows = <Map<String, dynamic>>[
    {
      'id': d0,
      'name': 'Dr. Mehta',
      'shortName': 'Mehta',
      'addressC': 'Anand',
      'addressR': '',
      'phoneC': '',
      'phoneR': '',
      'mobile': '9826111001',
      'city': 'Anand',
      'speciality': 'Physician',
      'email': '',
      'birthDate': '',
      'discount': '',
      'remarks': '',
    },
    {
      'id': d0 + 1,
      'name': 'Dr. Shah',
      'shortName': 'Shah',
      'addressC': 'Ahmedabad',
      'addressR': '',
      'phoneC': '',
      'phoneR': '',
      'mobile': '9826111002',
      'city': 'Ahmedabad',
      'speciality': 'Cardiology',
      'email': '',
      'birthDate': '',
      'discount': '',
      'remarks': '',
    },
    {
      'id': d0 + 2,
      'name': 'Dr. Patel',
      'shortName': 'Patel',
      'addressC': 'Surat',
      'addressR': '',
      'phoneC': '',
      'phoneR': '',
      'mobile': '9826111003',
      'city': 'Surat',
      'speciality': 'Pediatrics',
      'email': '',
      'birthDate': '',
      'discount': '',
      'remarks': '',
    },
    {
      'id': d0 + 3,
      'name': 'Dr. Khan',
      'shortName': 'Khan',
      'addressC': 'Vadodara',
      'addressR': '',
      'phoneC': '',
      'phoneR': '',
      'mobile': '9826111004',
      'city': 'Vadodara',
      'speciality': 'Orthopedics',
      'email': '',
      'birthDate': '',
      'discount': '',
      'remarks': '',
    },
    {
      'id': d0 + 4,
      'name': 'Dr. Desai',
      'shortName': 'Desai',
      'addressC': 'Rajkot',
      'addressR': '',
      'phoneC': '',
      'phoneR': '',
      'mobile': '9826111005',
      'city': 'Rajkot',
      'speciality': 'General Medicine',
      'email': '',
      'birthDate': '',
      'discount': '',
      'remarks': '',
    },
  ];
  for (final row in doctorRows) {
    doctors.add(Map<String, dynamic>.from(row));
    await persistDoctorRow(doctors.last);
  }

  const int pt0 = 50400;
  final patientRows = <Map<String, dynamic>>[
    {'id': pt0, 'name': 'Arjun Modi', 'mobile': '9909911001', 'address': 'Anand'},
    {'id': pt0 + 1, 'name': 'Sneha Iyer', 'mobile': '9909911002', 'address': 'Ahmedabad'},
    {'id': pt0 + 2, 'name': 'Harsh Trivedi', 'mobile': '9909911003', 'address': 'Surat'},
    {'id': pt0 + 3, 'name': 'Pooja Nair', 'mobile': '9909911004', 'address': 'Vadodara'},
    {'id': pt0 + 4, 'name': 'Rohan Bhatt', 'mobile': '9909911005', 'address': 'Rajkot'},
    {'id': pt0 + 5, 'name': 'Isha Agarwal', 'mobile': '9909911006', 'address': 'Anand'},
    {'id': pt0 + 6, 'name': 'Dev Chauhan', 'mobile': '9909911007', 'address': 'Ahmedabad'},
    {'id': pt0 + 7, 'name': 'Ananya Rao', 'mobile': '9909911008', 'address': 'Surat'},
  ];
  for (final row in patientRows) {
    patients.add(Map<String, dynamic>.from(row));
    await persistPatientRow(patients.last);
  }

  final suppliers = accountRows
      .where((a) => (a['accountType'] ?? '').toString() == 'Supplier')
      .toList();
  final customers = accountRows
      .where((a) => (a['accountType'] ?? '').toString() == 'Customer')
      .toList();

  var purId = 60001;
  var purBill = 501;
  for (var b = 0; b < 8; b++) {
    final sup = suppliers[b % suppliers.length];
    final pid1 = p0 + (b % 18);
    final pid2 = p0 + ((b + 3) % 18);
    final items = <Map<String, dynamic>>[
      _demoLine(
        lineNo: 1,
        productId: pid1,
        productName: (products.firstWhere((e) => e['id'] == pid1)['name'] ?? '')
            .toString(),
        qty: 35 + (b * 3).toDouble(),
        rate: _sqlNum(products.firstWhere((e) => e['id'] == pid1)['saleRate']),
      ),
      _demoLine(
        lineNo: 2,
        productId: pid2,
        productName: (products.firstWhere((e) => e['id'] == pid2)['name'] ?? '')
            .toString(),
        qty: 28 + (b * 2).toDouble(),
        rate: _sqlNum(products.firstWhere((e) => e['id'] == pid2)['saleRate']),
      ),
    ];
    final tax = _demoTaxTotals(items);
    final doc = <String, dynamic>{
      'id': purId++,
      'module': 'Purchase Bill',
      'series': 'PUR',
      'billNo': '${purBill++}',
      'date': [
        '2026-01-08',
        '2026-01-14',
        '2026-01-22',
        '2026-02-03',
        '2026-02-11',
        '2026-02-19',
        '2026-03-04',
        '2026-03-17',
      ][b],
      'party': sup['name'],
      'accountId': sup['id'],
      'doctor': '',
      'patient': '',
      'gstType': 'GST Local',
      'address': '',
      'mobile': '',
      ...tax,
      'items': items,
    };
    await persistPurchaseBillDoc(doc);
    await syncSalesOrPurchaseDocumentToRelational(
      doc,
      previousDoc: null,
      isPurchase: true,
    );
    purchaseBillRecords.insert(0, Map<String, dynamic>.from(doc));
  }

  await _refreshInMemoryProductStockFromSql();

  var salId = 61001;
  var salBill = 1001;
  final doctorNames = doctorRows.map((e) => e['name'] as String).toList();
  final patientNames = patientRows.map((e) => e['name'] as String).toList();
  for (var s = 0; s < 12; s++) {
    final cust = customers[s % customers.length];
    final pid1 = p0 + (s % 18);
    final pid2 = p0 + ((s + 5) % 18);
    final pid3 = p0 + ((s + 11) % 18);
    final items = <Map<String, dynamic>>[
      _demoLine(
        lineNo: 1,
        productId: pid1,
        productName: (products.firstWhere((e) => e['id'] == pid1)['name'] ?? '')
            .toString(),
        qty: 4 + (s % 4).toDouble(),
        rate: _sqlNum(products.firstWhere((e) => e['id'] == pid1)['saleRate']),
      ),
      _demoLine(
        lineNo: 2,
        productId: pid2,
        productName: (products.firstWhere((e) => e['id'] == pid2)['name'] ?? '')
            .toString(),
        qty: 3,
        rate: _sqlNum(products.firstWhere((e) => e['id'] == pid2)['saleRate']),
      ),
      _demoLine(
        lineNo: 3,
        productId: pid3,
        productName: (products.firstWhere((e) => e['id'] == pid3)['name'] ?? '')
            .toString(),
        qty: 2,
        free: s.isEven ? 1.0 : 0.0,
        rate: _sqlNum(products.firstWhere((e) => e['id'] == pid3)['saleRate']),
      ),
    ];
    final discPct = s % 4 == 0 ? 5.0 : 0.0;
    final tax = _demoTaxTotals(
      items,
      discountPercent: discPct,
      discountAmountFixed: s % 5 == 0 ? 10.0 : 0.0,
    );
    final doc = <String, dynamic>{
      'id': salId++,
      'module': 'Sales Invoice',
      'series': 'CASH',
      'billNo': '${salBill++}',
      'date': [
        '2026-01-21',
        '2026-01-26',
        '2026-02-06',
        '2026-02-13',
        '2026-02-21',
        '2026-03-02',
        '2026-03-11',
        '2026-03-19',
        '2026-04-03',
        '2026-04-09',
        '2026-04-16',
        '2026-04-23',
      ][s],
      'party': cust['name'],
      'accountId': cust['id'],
      'doctor': doctorNames[s % doctorNames.length],
      'patient': patientNames[s % patientNames.length],
      'gstType': 'GST Local',
      'address': cust['address1'],
      'mobile': cust['mobile'],
      ...tax,
      'items': items,
    };
    await persistSalesInvoiceDoc(doc);
    await syncSalesOrPurchaseDocumentToRelational(
      doc,
      previousDoc: null,
      isPurchase: false,
    );
    salesInvoiceRecords.insert(0, Map<String, dynamic>.from(doc));
  }

  await _refreshInMemoryProductStockFromSql();
  _relinkSeedsAfterHydrate();

  debugPrint(
    '[DEMO] seedDemoData complete — accounts=${accounts.length} '
    'products=${products.length} doctors=${doctors.length} patients=${patients.length} '
    'purchases=${purchaseBillRecords.length} sales=${salesInvoiceRecords.length}',
  );
}

String _normDemoName(String? s) => (s ?? '').trim().toLowerCase();

bool _quickDemoPurchaseBillExists(String billNo) =>
    purchaseBillRecords.any((d) => (d['billNo'] ?? '').toString() == billNo);

bool _quickDemoSalesBillExists(String billNo) =>
    salesInvoiceRecords.any((d) => (d['billNo'] ?? '').toString() == billNo);

int? _quickDemoProductIdByName(String name) {
  final k = _normDemoName(name);
  for (final p in products) {
    if (_normDemoName(p['name']) == k) return p['id'] as int?;
  }
  return null;
}

Future<double> _quickDemoSqlStock(int productId) async {
  final db = HealthDatabase.instance;
  if (db.hasPersistentSql) {
    try {
      final r = await db.fetchMedProductById(productId);
      if (r != null) return _sqlNum(r['stock']);
    } catch (_) {}
  }
  for (final p in products) {
    if (p['id'] == productId) return _sqlNum(p['stock']);
  }
  return 0;
}

Future<int?> _ensureQuickDemoAccount(Map<String, dynamic> template) async {
  final name = (template['name'] ?? '').toString();
  final key = _normDemoName(name);
  for (final a in accounts) {
    if (_normDemoName(a['name']) == key) return a['id'] as int?;
  }
  _relinkSeedsAfterHydrate();
  final id = _accountSeed++;
  final row = Map<String, dynamic>.from(template)..['id'] = id;
  accounts.add(row);
  await persistAccountRow(row);
  return id;
}

Future<int?> _ensureQuickDemoProduct({
  required String name,
  required String company,
  required String category,
  required double mrp,
  required double saleRate,
  required double stock,
  required String salesGst,
  required String purGst,
  required String expiryDate,
  required String batchNo,
}) async {
  final existing = _quickDemoProductIdByName(name);
  if (existing != null) return existing;
  _relinkSeedsAfterHydrate();
  final id = _productSeed++;
  final row = _demoProductRow(
    id: id,
    name: name,
    company: company,
    category: category,
    mrp: mrp,
    saleRate: saleRate,
    stock: stock,
    salesGst: salesGst,
    purGst: purGst,
    expiryDate: expiryDate,
    batchNo: batchNo,
  );
  products.add(row);
  await persistProductRow(products.last);
  return id;
}

Future<int?> _ensureQuickDemoDoctor(Map<String, dynamic> template) async {
  final name = (template['name'] ?? '').toString();
  final key = _normDemoName(name);
  for (final d in doctors) {
    if (_normDemoName(d['name']) == key) return d['id'] as int?;
  }
  _relinkSeedsAfterHydrate();
  final id = _doctorSeed++;
  final row = Map<String, dynamic>.from(template)..['id'] = id;
  doctors.add(row);
  await persistDoctorRow(row);
  return id;
}

Future<int?> _ensureQuickDemoPatient(Map<String, dynamic> template) async {
  final name = (template['name'] ?? '').toString();
  final key = _normDemoName(name);
  for (final p in patients) {
    if (_normDemoName(p['name']) == key) return p['id'] as int?;
  }
  _relinkSeedsAfterHydrate();
  final id = _patientSeed++;
  final row = Map<String, dynamic>.from(template)..['id'] = id;
  patients.add(row);
  await persistPatientRow(row);
  return id;
}

/// Idempotent presentation dataset: skips rows that already exist (by name or DEMOQ bill no).
/// Call once from [main] when you want demo data (see commented line there).
Future<void> fillDemoDataNow() async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) {
    debugPrint('[DEMO] fillDemoDataNow: skip (no SQLite)');
    return;
  }
  _relinkSeedsAfterHydrate();
  debugPrint('[DEMO] fillDemoDataNow: start');

  final customerTemplates = <Map<String, dynamic>>[
    {
      'name': 'Rahul Patel',
      'shortName': 'Rahul',
      'mobile': '9879012345',
      'city': 'Anand',
      'gst': '24AAAAA0000A1Z5',
      'address1': 'Station Road, Anand',
      'address2': '',
      'pin': '388001',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 1200.0,
      'accountType': 'Customer',
    },
    {
      'name': 'Priya Shah',
      'shortName': 'Priya',
      'mobile': '9879022345',
      'city': 'Ahmedabad',
      'gst': '24BBBBB0000B1Z5',
      'address1': 'Navrangpura, Ahmedabad',
      'address2': '',
      'pin': '380009',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 0.0,
      'accountType': 'Customer',
    },
    {
      'name': 'Amit Kumar',
      'shortName': 'Amit',
      'mobile': '9879033345',
      'city': 'Surat',
      'gst': '24CCCCC0000C1Z5',
      'address1': 'Ring Road, Surat',
      'address2': '',
      'pin': '395007',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 500.0,
      'accountType': 'Customer',
    },
    {
      'name': 'Neha Joshi',
      'shortName': 'Neha',
      'mobile': '9879044345',
      'city': 'Vadodara',
      'gst': '24DDDDD0000D1Z5',
      'address1': 'Alkapuri, Vadodara',
      'address2': '',
      'pin': '390007',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 0.0,
      'accountType': 'Customer',
    },
    {
      'name': 'Vikram Singh',
      'shortName': 'Vikram',
      'mobile': '9879055345',
      'city': 'Rajkot',
      'gst': '24EEEEE0000E1Z5',
      'address1': 'Kalawad Road, Rajkot',
      'address2': '',
      'pin': '360005',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 2500.0,
      'accountType': 'Customer',
    },
    {
      'name': 'Kiran Desai',
      'shortName': 'Kiran',
      'mobile': '9879066345',
      'city': 'Anand',
      'gst': '24FFFFF0000F1Z5',
      'address1': 'Vidhyanagar, Anand',
      'address2': '',
      'pin': '388120',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 0.0,
      'accountType': 'Customer',
    },
  ];

  final supplierTemplates = <Map<String, dynamic>>[
    {
      'name': 'ABC Pharma Distributor',
      'shortName': 'ABC',
      'mobile': '9825011111',
      'city': 'Ahmedabad',
      'gst': '24GGGGG0000G1Z5',
      'address1': 'GIDC Vatva, Ahmedabad',
      'address2': '',
      'pin': '382445',
      'keyPerson': 'Mr. Joshi',
      'phone': '079-12345678',
      'email': 'abc@pharma.in',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': 'GJ-AHD-12345',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 15000.0,
      'accountType': 'Supplier',
    },
    {
      'name': 'MedPlus Supplier',
      'shortName': 'MedPlus',
      'mobile': '9825022222',
      'city': 'Surat',
      'gst': '24HHHHH0000H1Z5',
      'address1': 'Hazira, Surat',
      'address2': '',
      'pin': '394510',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 8000.0,
      'accountType': 'Supplier',
    },
    {
      'name': 'Sun Pharma Wholesaler',
      'shortName': 'SunDist',
      'mobile': '9825033333',
      'city': 'Vadodara',
      'gst': '24IIIII0000I1Z5',
      'address1': 'Alembic Road, Vadodara',
      'address2': '',
      'pin': '390023',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 22000.0,
      'accountType': 'Supplier',
    },
    {
      'name': 'Krishna Distributors',
      'shortName': 'Krishna',
      'mobile': '9825044444',
      'city': 'Rajkot',
      'gst': '24JJJJJ0000J1Z5',
      'address1': 'Shapar, Rajkot',
      'address2': '',
      'pin': '360024',
      'keyPerson': '',
      'phone': '',
      'email': '',
      'tinLst': '',
      'cstReg': '',
      'drugLic1': '',
      'drugLic2': '',
      'discount': '',
      'phone2': '',
      'fax': '',
      'pisCode': '',
      'date1': '',
      'date2': '',
      'drugLic3': '',
      'drugLic4': '',
      'openingBalance': 5000.0,
      'accountType': 'Supplier',
    },
  ];

  for (final t in customerTemplates) {
    await _ensureQuickDemoAccount(t);
  }
  for (final t in supplierTemplates) {
    await _ensureQuickDemoAccount(t);
  }

  final demoProductNames = <String>[
    'Paracetamol 500 mg',
    'Dolo 650',
    'Crocin',
    'Azithromycin 500 mg',
    'Amoxicillin',
    'Pantoprazole',
    'Ibuprofen',
    'Cetirizine',
    'ORS Powder',
    'Vitamin D3',
    'Insulin Injection',
    'Cough Syrup',
    'Calcium Tablets',
    'Zinc Tablets',
    'Multivitamin',
  ];
  final demoCompanies = <String>[
    'Cipla',
    'Micro Labs',
    'GSK',
    'Alembic',
    'Dr Reddy',
    'Sun Pharma',
    'Abbott',
    'Alkem',
    'FDC',
    'Cadila',
    'Novo Nordisk',
    'Glenmark',
    'USV',
    'Himalaya',
    'Pfizer',
  ];
  final demoCats = <String>[
    'TABLET',
    'TABLET',
    'TABLET',
    'TABLET',
    'Capsule',
    'TABLET',
    'TABLET',
    'TABLET',
    'Powder',
    'Capsule',
    'Injection',
    'Syrup',
    'TABLET',
    'TABLET',
    'TABLET',
  ];
  final demoMrp = <double>[
    25, 38, 36, 120, 55, 95, 28, 12, 22, 180, 420, 88, 65, 45, 125,
  ];
  final demoSr = <double>[
    22, 34, 32, 105, 48, 82, 24, 9.5, 18, 155, 390, 72, 58, 40, 110,
  ];
  final demoStock = <double>[
    72, 68, 70, 55, 80, 60, 75, 90, 95, 58, 42, 66, 77, 83, 64,
  ];
  final demoSalesGst = <String>[
    'GST 12% (S)', 'GST 12% (S)', 'GST 12% (S)', 'GST 12% (S)', 'GST 12% (S)',
    'GST 12% (S)', 'GST 12% (S)', 'GST 12% (S)', 'GST 5% (S)', 'GST 12% (S)',
    'GST 18% (S)', 'GST 12% (S)', 'GST 12% (S)', 'GST 12% (S)', 'GST 12% (S)',
  ];
  final demoPurGst = <String>[
    'GST 12% (P)', 'GST 12% (P)', 'GST 12% (P)', 'GST 12% (P)', 'GST 12% (P)',
    'GST 12% (P)', 'GST 12% (P)', 'GST 12% (P)', 'GST 5% (P)', 'GST 12% (P)',
    'GST 18% (P)', 'GST 12% (P)', 'GST 12% (P)', 'GST 12% (P)', 'GST 12% (P)',
  ];
  final demoExpiry = <String>[
    '2027-06-30',
    '2027-09-15',
    '2028-01-20',
    '2027-04-10',
    '2027-11-01',
    '2028-03-22',
    '2027-08-08',
    '2027-12-31',
    '2026-12-31',
    '2028-02-14',
    '2027-07-07',
    '2027-10-25',
    '2028-04-04',
    '2027-05-18',
    '2027-09-09',
  ];

  for (var i = 0; i < demoProductNames.length; i++) {
    await _ensureQuickDemoProduct(
      name: demoProductNames[i],
      company: demoCompanies[i],
      category: demoCats[i],
      mrp: demoMrp[i],
      saleRate: demoSr[i],
      stock: demoStock[i],
      salesGst: demoSalesGst[i],
      purGst: demoPurGst[i],
      expiryDate: demoExpiry[i],
      batchNo: 'QDM${(101 + i).toString()}',
    );
  }

  final doctorTemplates = <Map<String, dynamic>>[
    {
      'name': 'Dr. Mehta',
      'shortName': 'Mehta',
      'addressC': 'Anand',
      'addressR': '',
      'phoneC': '',
      'phoneR': '',
      'mobile': '9826111001',
      'city': 'Anand',
      'speciality': 'Physician',
      'email': '',
      'birthDate': '',
      'discount': '',
      'remarks': '',
    },
    {
      'name': 'Dr. Shah',
      'shortName': 'Shah',
      'addressC': 'Ahmedabad',
      'addressR': '',
      'phoneC': '',
      'phoneR': '',
      'mobile': '9826111002',
      'city': 'Ahmedabad',
      'speciality': 'Cardiology',
      'email': '',
      'birthDate': '',
      'discount': '',
      'remarks': '',
    },
    {
      'name': 'Dr. Patel',
      'shortName': 'Patel',
      'addressC': 'Surat',
      'addressR': '',
      'phoneC': '',
      'phoneR': '',
      'mobile': '9826111003',
      'city': 'Surat',
      'speciality': 'Pediatrics',
      'email': '',
      'birthDate': '',
      'discount': '',
      'remarks': '',
    },
    {
      'name': 'Dr. Khan',
      'shortName': 'Khan',
      'addressC': 'Vadodara',
      'addressR': '',
      'phoneC': '',
      'phoneR': '',
      'mobile': '9826111004',
      'city': 'Vadodara',
      'speciality': 'Orthopedics',
      'email': '',
      'birthDate': '',
      'discount': '',
      'remarks': '',
    },
    {
      'name': 'Dr. Desai',
      'shortName': 'Desai',
      'addressC': 'Rajkot',
      'addressR': '',
      'phoneC': '',
      'phoneR': '',
      'mobile': '9826111005',
      'city': 'Rajkot',
      'speciality': 'General Medicine',
      'email': '',
      'birthDate': '',
      'discount': '',
      'remarks': '',
    },
  ];
  for (final t in doctorTemplates) {
    await _ensureQuickDemoDoctor(t);
  }

  final patientTemplates = <Map<String, dynamic>>[
    {'name': 'Arjun Modi', 'mobile': '9909911001', 'address': 'Anand'},
    {'name': 'Sneha Iyer', 'mobile': '9909911002', 'address': 'Ahmedabad'},
    {'name': 'Harsh Trivedi', 'mobile': '9909911003', 'address': 'Surat'},
    {'name': 'Pooja Nair', 'mobile': '9909911004', 'address': 'Vadodara'},
    {'name': 'Rohan Bhatt', 'mobile': '9909911005', 'address': 'Rajkot'},
    {'name': 'Isha Agarwal', 'mobile': '9909911006', 'address': 'Anand'},
    {'name': 'Dev Chauhan', 'mobile': '9909911007', 'address': 'Ahmedabad'},
    {'name': 'Ananya Rao', 'mobile': '9909911008', 'address': 'Surat'},
    {'name': 'Manish Kulkarni', 'mobile': '9909911009', 'address': 'Vadodara'},
    {'name': 'Kavya Menon', 'mobile': '9909911010', 'address': 'Surat'},
  ];
  for (final t in patientTemplates) {
    await _ensureQuickDemoPatient(t);
  }

  _relinkSeedsAfterHydrate();

  final supplierNames =
      supplierTemplates.map((e) => e['name']!.toString()).toList();
  final purchaseDates = <String>[
    '2026-01-08',
    '2026-01-14',
    '2026-01-22',
    '2026-02-03',
    '2026-02-11',
    '2026-02-19',
    '2026-03-04',
    '2026-03-17',
  ];

  for (var b = 0; b < 8; b++) {
    final billNo = 'DEMOQ-P${(b + 1).toString().padLeft(2, '0')}';
    if (_quickDemoPurchaseBillExists(billNo)) continue;

    final supName = supplierNames[b % supplierNames.length];
    final supId = medResolveAccountIdByName(supName);
    if (supId == null) continue;

    final n = demoProductNames.length;
    final name1 = demoProductNames[b % n];
    final name2 = demoProductNames[(b + 5) % n];
    final pid1 = _quickDemoProductIdByName(name1);
    final pid2 = _quickDemoProductIdByName(name2);
    if (pid1 == null || pid2 == null) continue;

    final qty1 = (20 + (b * 11) % 81).toDouble();
    final qty2 = (25 + (b * 7) % 76).toDouble();
    final p1 = products.firstWhere((e) => e['id'] == pid1);
    final p2 = products.firstWhere((e) => e['id'] == pid2);
    final items = <Map<String, dynamic>>[
      _demoLine(
        lineNo: 1,
        productId: pid1,
        productName: (p1['name'] ?? '').toString(),
        qty: qty1,
        rate: _sqlNum(p1['saleRate']),
      ),
      _demoLine(
        lineNo: 2,
        productId: pid2,
        productName: (p2['name'] ?? '').toString(),
        qty: qty2,
        rate: _sqlNum(p2['saleRate']),
      ),
    ];
    final tax = _demoTaxTotals(items);
    final docId = _purchaseBillSeed++;
    final doc = <String, dynamic>{
      'id': docId,
      'module': 'Purchase Bill',
      'series': 'PUR',
      'billNo': billNo,
      'date': purchaseDates[b],
      'party': supName,
      'accountId': supId,
      'doctor': '',
      'patient': '',
      'gstType': 'GST Local',
      'address': '',
      'mobile': '',
      ...tax,
      'items': items,
    };
    await persistPurchaseBillDoc(doc);
    await syncSalesOrPurchaseDocumentToRelational(
      doc,
      previousDoc: null,
      isPurchase: true,
    );
    purchaseBillRecords.insert(0, Map<String, dynamic>.from(doc));
  }

  await _refreshInMemoryProductStockFromSql();

  final saleDates = <String>[
    '2026-01-21',
    '2026-01-26',
    '2026-02-06',
    '2026-02-13',
    '2026-02-21',
    '2026-03-02',
    '2026-03-11',
    '2026-03-19',
    '2026-04-03',
    '2026-04-09',
  ];
  final doctorDisplay = doctorTemplates
      .map((e) => (e['name'] ?? '').toString())
      .toList();
  final patientDisplay = patientTemplates
      .map((e) => (e['name'] ?? '').toString())
      .toList();

  for (var s = 0; s < 10; s++) {
    final billNo = 'DEMOQ-S${(s + 1).toString().padLeft(2, '0')}';
    if (_quickDemoSalesBillExists(billNo)) continue;

    final custName = customerTemplates[s % customerTemplates.length]['name']!
        .toString();
    final custId = medResolveAccountIdByName(custName);
    if (custId == null) continue;

    final custRow = accounts.firstWhere(
      (a) => a['id'] == custId,
      orElse: () => <String, dynamic>{},
    );

    final n = demoProductNames.length;
    final nLines = (s % 3 == 0) ? 2 : 3;
    final idx1 = s % n;
    final idx2 = (s + 4) % n;
    final idx3 = (s + 9) % n;
    final ids = <int>[];
    for (final idx in [idx1, idx2, if (nLines == 3) idx3]) {
      final nm = demoProductNames[idx];
      final pid = _quickDemoProductIdByName(nm);
      if (pid != null) ids.add(pid);
    }
    if (ids.isEmpty) continue;

    final items = <Map<String, dynamic>>[];
    var lineNo = 0;
    for (var k = 0; k < ids.length; k++) {
      final pid = ids[k];
      final want = (3 + (s + k) % 6).toDouble();
      final avail = await _quickDemoSqlStock(pid);
      final qty = want.clamp(0, avail).floorToDouble();
      if (qty < 1) continue;
      final prow = products.firstWhere((e) => e['id'] == pid);
      lineNo++;
      items.add(
        _demoLine(
          lineNo: lineNo,
          productId: pid,
          productName: (prow['name'] ?? '').toString(),
          qty: qty,
          free: 0.0,
          rate: _sqlNum(prow['saleRate']),
        ),
      );
    }
    if (items.isEmpty) continue;

    final discPct = s % 4 == 0 ? 5.0 : 0.0;
    final tax = _demoTaxTotals(
      items,
      discountPercent: discPct,
      discountAmountFixed: s % 5 == 0 ? 8.0 : 0.0,
    );
    final docId = _salesInvoiceSeed++;
    final doc = <String, dynamic>{
      'id': docId,
      'module': 'Sales Invoice',
      'series': 'CASH',
      'billNo': billNo,
      'date': saleDates[s],
      'party': custName,
      'accountId': custId,
      'doctor': doctorDisplay[s % doctorDisplay.length],
      'patient': patientDisplay[s % patientDisplay.length],
      'gstType': 'GST Local',
      'address': (custRow['address1'] ?? '').toString(),
      'mobile': (custRow['mobile'] ?? '').toString(),
      ...tax,
      'items': items,
    };
    await persistSalesInvoiceDoc(doc);
    await syncSalesOrPurchaseDocumentToRelational(
      doc,
      previousDoc: null,
      isPurchase: false,
    );
    salesInvoiceRecords.insert(0, Map<String, dynamic>.from(doc));
    await _refreshInMemoryProductStockFromSql();
  }

  await _refreshInMemoryProductStockFromSql();
  _relinkSeedsAfterHydrate();
  debugPrint(
    '[DEMO] fillDemoDataNow complete — accounts=${accounts.length} '
    'products=${products.length} doctors=${doctors.length} patients=${patients.length} '
    'purchases=${purchaseBillRecords.length} sales=${salesInvoiceRecords.length}',
  );
}
