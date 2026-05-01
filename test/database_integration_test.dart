import 'package:flutter_test/flutter_test.dart';
import 'package:health_project/main.dart';

void main() {
  test('SQLite service CRUD smoke test', () async {
    await HealthDatabase.instance.initialize();

    final accountId = await HealthDatabase.instance.insertAccount({
      'name': 'A1',
      'mobile': '9999999999',
      'city': 'Surat',
      'gst': 'GST-01',
      'address': 'Address 1',
      'created_at': DateTime.now().toIso8601String(),
    });

    var accounts = await HealthDatabase.instance.fetchAccounts();
    expect(accounts.any((r) => r['id'] == accountId), isTrue);

    await HealthDatabase.instance.updateAccount(accountId, {
      'name': 'A1 Updated',
      'city': 'Ahmedabad',
    });

    accounts = await HealthDatabase.instance.fetchAccounts();
    final updated = accounts.firstWhere((r) => r['id'] == accountId);
    expect(updated['name'], 'A1 Updated');

    final deletedCount = await HealthDatabase.instance.deleteAccount(accountId);
    expect(deletedCount, greaterThan(0));
  });
}
