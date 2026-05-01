part of 'package:health_project/main.dart';

const String kCollAccount = 'erp_account';
const String kCollProduct = 'erp_product';
const String kCollDoctor = 'erp_doctor';
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

Future<void> hydrateAppDataFromDatabase() async {
  final db = HealthDatabase.instance;
  if (!db.hasPersistentSql) {
    _relinkSeedsAfterHydrate();
    return;
  }
  try {
    accounts
      ..clear()
      ..addAll(await db.loadJsonCollection(kCollAccount));
    products
      ..clear()
      ..addAll(await db.loadJsonCollection(kCollProduct));
    doctors
      ..clear()
      ..addAll(await db.loadJsonCollection(kCollDoctor));
    salesInvoiceRecords
      ..clear()
      ..addAll(await db.loadJsonCollection(kCollSales));
    purchaseBillRecords
      ..clear()
      ..addAll(await db.loadJsonCollection(kCollPurchase));
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

    _relinkSeedsAfterHydrate();
  } catch (e, st) {
    debugPrint('hydrateAppDataFromDatabase: $e\n$st');
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
}

Future<void> persistAccountRow(Map<String, dynamic> row) async {
  final id = row['id'];
  if (id is! int) return;
  await HealthDatabase.instance.upsertJsonDocument(
    kCollAccount,
    id,
    Map<String, dynamic>.from(row),
  );
}

Future<void> deleteAccountRow(int id) async {
  await HealthDatabase.instance.deleteJsonDocument(kCollAccount, id);
}

Future<void> persistProductRow(Map<String, dynamic> row) async {
  final id = row['id'];
  if (id is! int) return;
  await HealthDatabase.instance.upsertJsonDocument(
    kCollProduct,
    id,
    Map<String, dynamic>.from(row),
  );
}

Future<void> deleteProductRow(int id) async {
  await HealthDatabase.instance.deleteJsonDocument(kCollProduct, id);
}

Future<void> persistDoctorRow(Map<String, dynamic> row) async {
  final id = row['id'];
  if (id is! int) return;
  await HealthDatabase.instance.upsertJsonDocument(
    kCollDoctor,
    id,
    Map<String, dynamic>.from(row),
  );
}

Future<void> deleteDoctorRow(int id) async {
  await HealthDatabase.instance.deleteJsonDocument(kCollDoctor, id);
}

Future<void> persistSalesInvoiceDoc(Map<String, dynamic> doc) async {
  final id = doc['id'];
  if (id is! int) return;
  await HealthDatabase.instance.upsertJsonDocument(
    kCollSales,
    id,
    Map<String, dynamic>.from(doc),
  );
}

Future<void> deleteSalesInvoiceDoc(int id) async {
  await HealthDatabase.instance.deleteJsonDocument(kCollSales, id);
}

Future<void> persistPurchaseBillDoc(Map<String, dynamic> doc) async {
  final id = doc['id'];
  if (id is! int) return;
  await HealthDatabase.instance.upsertJsonDocument(
    kCollPurchase,
    id,
    Map<String, dynamic>.from(doc),
  );
}

Future<void> deletePurchaseBillDoc(int id) async {
  await HealthDatabase.instance.deleteJsonDocument(kCollPurchase, id);
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
