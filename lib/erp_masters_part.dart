part of 'package:health_project/main.dart';

String _erpNowIso() => DateTime.now().toIso8601String();

const String kErpTableCategory = 'category_master';
const String kErpTableTax = 'tax_category';
const String kErpTableStockist = 'stockist_master';
const String kErpTableSpeciality = 'speciality_master';
const String kErpTableSchedule = 'schedule_category';

List<Map<String, dynamic>> erpSortAccountsMaster(
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
        if (cityCompare != 0) return cityCompare;
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

extension HealthDatabaseErpMasters on HealthDatabase {
  Future<List<Map<String, Object?>>> erpMasterFetchAll(String table) async {
    if (!hasPersistentSql) return [];
    try {
      final db = await database;
      return await db.query(table, orderBy: 'name COLLATE NOCASE ASC');
    } catch (e, st) {
      debugPrint('erpMasterFetchAll $table: $e\n$st');
      return [];
    }
  }

  Future<int?> erpMasterInsert(String table, Map<String, Object?> row) async {
    if (!hasPersistentSql) return null;
    try {
      final db = await database;
      final now = _erpNowIso();
      final m = Map<String, Object?>.from(row)..remove('id');
      m['created_at'] = now;
      m['updated_at'] = now;
      return await db.transaction((txn) async {
        return await txn.insert(table, m);
      });
    } catch (e, st) {
      debugPrint('erpMasterInsert $table: $e\n$st');
      return null;
    }
  }

  Future<int> erpMasterUpdate(
    String table,
    int id,
    Map<String, Object?> row,
  ) async {
    if (!hasPersistentSql) return 0;
    try {
      final db = await database;
      final m = Map<String, Object?>.from(row)..remove('id');
      m['updated_at'] = _erpNowIso();
      return await db.transaction((txn) async {
        return await txn.update(table, m, where: 'id = ?', whereArgs: [id]);
      });
    } catch (e, st) {
      debugPrint('erpMasterUpdate $table: $e\n$st');
      return 0;
    }
  }

  Future<int> erpMasterDelete(String table, int id) async {
    if (!hasPersistentSql) return 0;
    try {
      final db = await database;
      return await db.transaction((txn) async {
        return await txn.delete(table, where: 'id = ?', whereArgs: [id]);
      });
    } catch (e, st) {
      debugPrint('erpMasterDelete $table: $e\n$st');
      return 0;
    }
  }
}

class _ErpMasterHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onClose;

  const _ErpMasterHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppUi.primary, Color(0xFF3B82F6), AppUi.teal],
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
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 11.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
    );
  }
}

Widget _erpActionsColumn({
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  required VoidCallback onSave,
  required VoidCallback onClear,
}) {
  return SizedBox(
    width: 150,
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
  );
}

void _erpSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 900),
    ),
  );
}

/// Name + description masters: category, speciality, schedule.
class ErpNameDescMasterScreen extends StatefulWidget {
  final String title;
  final String table;
  final IconData icon;
  final VoidCallback? onClose;

  const ErpNameDescMasterScreen({
    super.key,
    required this.title,
    required this.table,
    required this.icon,
    this.onClose,
  });

  @override
  State<ErpNameDescMasterScreen> createState() =>
      _ErpNameDescMasterScreenState();
}

class _ErpNameDescMasterScreenState extends State<ErpNameDescMasterScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  List<Map<String, Object?>> _rows = [];
  int? _selectedIndex;
  int? _editingId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final db = HealthDatabase.instance;
    final list = await db.erpMasterFetchAll(widget.table);
    if (!mounted) return;
    setState(() {
      _rows = list;
      _selectedIndex = null;
      _editingId = null;
      _name.clear();
      _desc.clear();
    });
  }

  void _clearForm() {
    setState(() {
      _selectedIndex = null;
      _editingId = null;
      _name.clear();
      _desc.clear();
    });
    _erpSnack(context, 'Cleared');
  }

  void _edit() {
    if (_selectedIndex == null) {
      _erpSnack(context, 'Select a row to edit');
      return;
    }
    final r = _rows[_selectedIndex!];
    setState(() {
      _editingId = r['id'] as int?;
      _name.text = (r['name'] ?? '').toString();
      _desc.text = (r['description'] ?? '').toString();
    });
  }

  Future<void> _delete() async {
    if (_selectedIndex == null) {
      _erpSnack(context, 'Select a row to delete');
      return;
    }
    final id = _rows[_selectedIndex!]['id'] as int?;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final n = await HealthDatabase.instance.erpMasterDelete(widget.table, id);
    if (!mounted) return;
    if (n > 0) {
      _erpSnack(context, 'Deleted');
      await _reload();
    } else {
      _erpSnack(context, 'Delete failed (database unavailable or constraint)');
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _erpSnack(context, 'Name is required');
      return;
    }
    final db = HealthDatabase.instance;
    final desc = _desc.text.trim();
    if (_editingId != null) {
      final u = await db.erpMasterUpdate(widget.table, _editingId!, {
        'name': name,
        'description': desc,
      });
      if (!mounted) return;
      if (u > 0) {
        _erpSnack(context, 'Updated');
        await _reload();
      } else {
        _erpSnack(context, 'Update failed (duplicate name or DB error)');
      }
    } else {
      final id = await db.erpMasterInsert(widget.table, {
        'name': name,
        'description': desc,
      });
      if (!mounted) return;
      if (id != null) {
        _erpSnack(context, 'Saved');
        await _reload();
      } else {
        _erpSnack(context, 'Save failed (duplicate name or DB error)');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tableRows = _rows
        .map((r) => [(r['name'] ?? '').toString(), (r['description'] ?? '').toString()])
        .toList();
    return Container(
      color: AppUi.surfaceAlt,
      child: Column(
        children: [
          _ErpMasterHeader(
            title: widget.title,
            subtitle: 'Maintain reference data used across the ERP',
            icon: widget.icon,
            onClose: widget.onClose,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 400,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                    child: _SectionCard(
                      title: 'Details',
                      child: Column(
                        children: [
                          _CompactFormRow(
                            label: 'Name',
                            field: _compactInput(controller: _name),
                          ),
                          _CompactFormRow(
                            label: 'Description',
                            topAligned: true,
                            field: _compactInput(controller: _desc, maxLines: 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 8, 10),
                    child: _SimpleTable(
                      headers: const ['Name', 'Description'],
                      selectedIndex: _selectedIndex,
                      rows: tableRows,
                      onRowTap: (i) => setState(() => _selectedIndex = i),
                    ),
                  ),
                ),
                _erpActionsColumn(
                  onEdit: _edit,
                  onDelete: _delete,
                  onSave: _save,
                  onClear: _clearForm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TaxCategoryGstScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const TaxCategoryGstScreen({super.key, this.onClose});

  @override
  State<TaxCategoryGstScreen> createState() => _TaxCategoryGstScreenState();
}

class _TaxCategoryGstScreenState extends State<TaxCategoryGstScreen> {
  final _name = TextEditingController();
  final _gst = TextEditingController();
  final _remarks = TextEditingController();
  List<Map<String, Object?>> _rows = [];
  int? _selectedIndex;
  int? _editingId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _name.dispose();
    _gst.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final list = await HealthDatabase.instance.erpMasterFetchAll(kErpTableTax);
    if (!mounted) return;
    setState(() {
      _rows = list;
      _selectedIndex = null;
      _editingId = null;
      _name.clear();
      _gst.clear();
      _remarks.clear();
    });
  }

  void _clear() {
    setState(() {
      _selectedIndex = null;
      _editingId = null;
      _name.clear();
      _gst.clear();
      _remarks.clear();
    });
    _erpSnack(context, 'Cleared');
  }

  void _edit() {
    if (_selectedIndex == null) {
      _erpSnack(context, 'Select a row to edit');
      return;
    }
    final r = _rows[_selectedIndex!];
    setState(() {
      _editingId = r['id'] as int?;
      _name.text = (r['name'] ?? '').toString();
      _gst.text = (r['gst_percent'] ?? 0).toString();
      _remarks.text = (r['remarks'] ?? '').toString();
    });
  }

  Future<void> _delete() async {
    if (_selectedIndex == null) {
      _erpSnack(context, 'Select a row to delete');
      return;
    }
    final id = _rows[_selectedIndex!]['id'] as int?;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tax category?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final n = await HealthDatabase.instance.erpMasterDelete(kErpTableTax, id);
    if (!mounted) return;
    if (n > 0) {
      _erpSnack(context, 'Deleted');
      await _reload();
    } else {
      _erpSnack(context, 'Delete failed');
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _erpSnack(context, 'Name is required');
      return;
    }
    final g = double.tryParse(_gst.text.trim());
    if (g == null || g < 0 || g > 100) {
      _erpSnack(context, 'GST % must be between 0 and 100');
      return;
    }
    final db = HealthDatabase.instance;
    if (_editingId != null) {
      final u = await db.erpMasterUpdate(kErpTableTax, _editingId!, {
        'name': name,
        'gst_percent': g,
        'remarks': _remarks.text.trim(),
      });
      if (!mounted) return;
      if (u > 0) {
        _erpSnack(context, 'Updated');
        await _reload();
      } else {
        _erpSnack(context, 'Update failed (duplicate name or DB error)');
      }
    } else {
      final id = await db.erpMasterInsert(kErpTableTax, {
        'name': name,
        'gst_percent': g,
        'remarks': _remarks.text.trim(),
      });
      if (!mounted) return;
      if (id != null) {
        _erpSnack(context, 'Saved');
        await _reload();
      } else {
        _erpSnack(context, 'Save failed (duplicate name or DB error)');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tableRows = _rows
        .map(
          (r) => [
            (r['name'] ?? '').toString(),
            (r['gst_percent'] ?? '').toString(),
            (r['remarks'] ?? '').toString(),
          ],
        )
        .toList();
    return Container(
      color: AppUi.surfaceAlt,
      child: Column(
        children: [
          _ErpMasterHeader(
            title: 'Tax Category (GST)',
            subtitle: 'GST slabs and labels for product / invoice mapping',
            icon: Icons.calculate_rounded,
            onClose: widget.onClose,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 400,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                    child: _SectionCard(
                      title: 'Tax category',
                      child: Column(
                        children: [
                          _CompactFormRow(
                            label: 'Name',
                            field: _compactInput(controller: _name),
                          ),
                          _CompactFormRow(
                            label: 'GST %',
                            field: _compactInput(
                              controller: _gst,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          _CompactFormRow(
                            label: 'Remarks',
                            topAligned: true,
                            field: _compactInput(controller: _remarks, maxLines: 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 8, 10),
                    child: _SimpleTable(
                      headers: const ['Name', 'GST %', 'Remarks'],
                      selectedIndex: _selectedIndex,
                      rows: tableRows,
                      onRowTap: (i) => setState(() => _selectedIndex = i),
                    ),
                  ),
                ),
                _erpActionsColumn(
                  onEdit: _edit,
                  onDelete: _delete,
                  onSave: _save,
                  onClear: _clear,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StockistMasterScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const StockistMasterScreen({super.key, this.onClose});

  @override
  State<StockistMasterScreen> createState() => _StockistMasterScreenState();
}

class _StockistMasterScreenState extends State<StockistMasterScreen> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _gst = TextEditingController();
  final _lic = TextEditingController();
  final _remarks = TextEditingController();
  List<Map<String, Object?>> _rows = [];
  int? _selectedIndex;
  int? _editingId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _address.dispose();
    _city.dispose();
    _gst.dispose();
    _lic.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final list = await HealthDatabase.instance.erpMasterFetchAll(kErpTableStockist);
    if (!mounted) return;
    setState(() {
      _rows = list;
      _selectedIndex = null;
      _editingId = null;
      _name.clear();
      _mobile.clear();
      _address.clear();
      _city.clear();
      _gst.clear();
      _lic.clear();
      _remarks.clear();
    });
  }

  void _clear() {
    setState(() {
      _selectedIndex = null;
      _editingId = null;
      _name.clear();
      _mobile.clear();
      _address.clear();
      _city.clear();
      _gst.clear();
      _lic.clear();
      _remarks.clear();
    });
    _erpSnack(context, 'Cleared');
  }

  void _edit() {
    if (_selectedIndex == null) {
      _erpSnack(context, 'Select a row to edit');
      return;
    }
    final r = _rows[_selectedIndex!];
    setState(() {
      _editingId = r['id'] as int?;
      _name.text = (r['name'] ?? '').toString();
      _mobile.text = (r['mobile'] ?? '').toString();
      _address.text = (r['address'] ?? '').toString();
      _city.text = (r['city'] ?? '').toString();
      _gst.text = (r['gst'] ?? '').toString();
      _lic.text = (r['drug_license'] ?? '').toString();
      _remarks.text = (r['remarks'] ?? '').toString();
    });
  }

  Future<void> _delete() async {
    if (_selectedIndex == null) {
      _erpSnack(context, 'Select a row to delete');
      return;
    }
    final id = _rows[_selectedIndex!]['id'] as int?;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete stockist?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final n = await HealthDatabase.instance.erpMasterDelete(kErpTableStockist, id);
    if (!mounted) return;
    if (n > 0) {
      _erpSnack(context, 'Deleted');
      await _reload();
    } else {
      _erpSnack(context, 'Delete failed');
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _erpSnack(context, 'Name is required');
      return;
    }
    final row = <String, Object?>{
      'name': name,
      'mobile': _mobile.text.trim(),
      'address': _address.text.trim(),
      'city': _city.text.trim(),
      'gst': _gst.text.trim(),
      'drug_license': _lic.text.trim(),
      'remarks': _remarks.text.trim(),
    };
    final db = HealthDatabase.instance;
    if (_editingId != null) {
      final u = await db.erpMasterUpdate(kErpTableStockist, _editingId!, row);
      if (!mounted) return;
      if (u > 0) {
        _erpSnack(context, 'Updated');
        await _reload();
      } else {
        _erpSnack(context, 'Update failed (duplicate name or DB error)');
      }
    } else {
      final id = await db.erpMasterInsert(kErpTableStockist, row);
      if (!mounted) return;
      if (id != null) {
        _erpSnack(context, 'Saved');
        await _reload();
      } else {
        _erpSnack(context, 'Save failed (duplicate name or DB error)');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tableRows = _rows
        .map(
          (r) => [
            (r['name'] ?? '').toString(),
            (r['city'] ?? '').toString(),
            (r['mobile'] ?? '').toString(),
          ],
        )
        .toList();
    return Container(
      color: AppUi.surfaceAlt,
      child: Column(
        children: [
          _ErpMasterHeader(
            title: 'Stockist Master',
            subtitle: 'Wholesale / distributor parties reference list',
            icon: Icons.local_shipping_rounded,
            onClose: widget.onClose,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                    child: _SectionCard(
                      title: 'Stockist',
                      child: Column(
                        children: [
                          _CompactFormRow(
                            label: 'Name',
                            field: _compactInput(controller: _name),
                          ),
                          _CompactFormRow(
                            label: 'Mobile',
                            field: _compactInput(controller: _mobile),
                          ),
                          _CompactFormRow(
                            label: 'City',
                            field: _compactInput(controller: _city),
                          ),
                          _CompactFormRow(
                            label: 'Address',
                            topAligned: true,
                            field: _compactInput(controller: _address, maxLines: 2),
                          ),
                          _CompactFormRow(
                            label: 'GSTIN',
                            field: _compactInput(controller: _gst),
                          ),
                          _CompactFormRow(
                            label: 'Drug Lic.',
                            field: _compactInput(controller: _lic),
                          ),
                          _CompactFormRow(
                            label: 'Remarks',
                            topAligned: true,
                            field: _compactInput(controller: _remarks, maxLines: 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 8, 10),
                    child: _SimpleTable(
                      headers: const ['Name', 'City', 'Mobile'],
                      selectedIndex: _selectedIndex,
                      rows: tableRows,
                      onRowTap: (i) => setState(() => _selectedIndex = i),
                    ),
                  ),
                ),
                _erpActionsColumn(
                  onEdit: _edit,
                  onDelete: _delete,
                  onSave: _save,
                  onClear: _clear,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryMasterScreen extends StatelessWidget {
  final VoidCallback? onClose;
  const CategoryMasterScreen({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    return ErpNameDescMasterScreen(
      title: 'Category Master',
      table: kErpTableCategory,
      icon: Icons.category_rounded,
      onClose: onClose,
    );
  }
}

class SpecialityMasterScreen extends StatelessWidget {
  final VoidCallback? onClose;
  const SpecialityMasterScreen({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    return ErpNameDescMasterScreen(
      title: 'Speciality Master',
      table: kErpTableSpeciality,
      icon: Icons.medical_information_rounded,
      onClose: onClose,
    );
  }
}

class ScheduledCategoryMasterScreen extends StatelessWidget {
  final VoidCallback? onClose;
  const ScheduledCategoryMasterScreen({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    return ErpNameDescMasterScreen(
      title: 'Scheduled Category',
      table: kErpTableSchedule,
      icon: Icons.schedule_rounded,
      onClose: onClose,
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

  String _sortingTypeLocal = 'AccountWise';
  final _name = TextEditingController();
  final _short = TextEditingController();
  final _mobile = TextEditingController();
  final _city = TextEditingController();
  final _gst = TextEditingController();
  final _addr1 = TextEditingController();
  final _addr2 = TextEditingController();
  final _pin = TextEditingController();
  String _ledgerType = 'Customer';
  final _opening = TextEditingController();
  int? _selectedIndex;
  int? _editingId;

  List<Map<String, dynamic>> get _sorted {
    return erpSortAccountsMaster(accounts, _sortingTypeLocal);
  }

  @override
  void initState() {
    super.initState();
    _sortingTypeLocal = sortingType;
  }

  @override
  void dispose() {
    _name.dispose();
    _short.dispose();
    _mobile.dispose();
    _city.dispose();
    _gst.dispose();
    _addr1.dispose();
    _addr2.dispose();
    _pin.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _loadRowToForm(Map<String, dynamic> row) {
    _editingId = row['id'] as int?;
    _name.text = (row['name'] ?? '').toString();
    _short.text = (row['shortName'] ?? '').toString();
    _mobile.text = (row['mobile'] ?? '').toString();
    _city.text = (row['city'] ?? '').toString();
    _gst.text = (row['gst'] ?? '').toString();
    _addr1.text = (row['address1'] ?? '').toString();
    _addr2.text = (row['address2'] ?? '').toString();
    _pin.text = (row['pin'] ?? '').toString();
    _ledgerType = (row['accountType'] ?? 'Customer').toString();
    _opening.text = (row['openingBalance'] ?? 0).toString();
  }

  void _clear() {
    setState(() {
      _selectedIndex = null;
      _editingId = null;
      _name.clear();
      _short.clear();
      _mobile.clear();
      _city.clear();
      _gst.clear();
      _addr1.clear();
      _addr2.clear();
      _pin.clear();
      _ledgerType = 'Customer';
      _opening.text = '0';
      _sortingTypeLocal = 'AccountWise';
      sortingType = 'AccountWise';
    });
    _erpSnack(context, 'Cleared');
  }

  void _edit() {
    if (_selectedIndex == null) {
      _erpSnack(context, 'Select a row to edit');
      return;
    }
    setState(() => _loadRowToForm(_sorted[_selectedIndex!]));
  }

  Future<void> _delete() async {
    if (_selectedIndex == null) {
      _erpSnack(context, 'Select a row to delete');
      return;
    }
    final row = _sorted[_selectedIndex!];
    final id = row['id'] as int?;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'Removes this account from the database. Only continue if no linked invoices exist.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteAccountRow(id);
      accounts.removeWhere((a) => a['id'] == id);
      if (!mounted) return;
      setState(() {
        _selectedIndex = null;
        _editingId = null;
        _name.clear();
        _short.clear();
        _mobile.clear();
        _city.clear();
        _gst.clear();
        _addr1.clear();
        _addr2.clear();
        _pin.clear();
        _ledgerType = 'Customer';
        _opening.text = '0';
      });
      _erpSnack(context, 'Account deleted');
    } catch (e) {
      if (mounted) _erpSnack(context, 'Delete failed: $e');
    }
  }

  Map<String, dynamic> _formToMap({
    required int id,
    Map<String, dynamic>? base,
  }) {
    final m = base != null
        ? Map<String, dynamic>.from(base)
        : <String, dynamic>{
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
          };
    m['id'] = id;
    m['name'] = _name.text.trim();
    m['shortName'] = _short.text.trim();
    m['mobile'] = _mobile.text.trim();
    m['city'] = _city.text.trim();
    m['gst'] = _gst.text.trim();
    m['address1'] = _addr1.text.trim();
    m['address2'] = _addr2.text.trim();
    m['pin'] = _pin.text.trim();
    m['openingBalance'] = double.tryParse(_opening.text.trim()) ?? 0;
    m['accountType'] = _ledgerType;
    return m;
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _erpSnack(context, 'Name is required');
      return;
    }
    sortingType = _sortingTypeLocal;
    try {
      if (_editingId != null) {
        final ix = accounts.indexWhere((a) => a['id'] == _editingId);
        if (ix < 0) {
          _erpSnack(context, 'Account not found');
          return;
        }
        final dup = accounts.any((a) {
          final same = (a['name'] ?? '').toString().trim().toLowerCase() ==
              _name.text.trim().toLowerCase();
          return same && a['id'] != _editingId;
        });
        if (dup) {
          _erpSnack(context, 'Duplicate account name');
          return;
        }
        accounts[ix] = _formToMap(id: _editingId!, base: accounts[ix]);
        await persistAccountRow(accounts[ix]);
      } else {
        final dup = accounts.any(
          (a) =>
              (a['name'] ?? '').toString().trim().toLowerCase() ==
              _name.text.trim().toLowerCase(),
        );
        if (dup) {
          _erpSnack(context, 'Duplicate account name');
          return;
        }
        _relinkSeedsAfterHydrate();
        final id = _accountSeed++;
        final rec = _formToMap(id: id, base: null);
        accounts.add(rec);
        await persistAccountRow(rec);
      }
      if (!mounted) return;
      setState(() {
        _selectedIndex = null;
        _editingId = null;
        _name.clear();
        _short.clear();
        _mobile.clear();
        _city.clear();
        _gst.clear();
        _addr1.clear();
        _addr2.clear();
        _pin.clear();
        _ledgerType = 'Customer';
        _opening.text = '0';
      });
      _erpSnack(context, 'Saved');
    } catch (e) {
      if (mounted) _erpSnack(context, 'Save error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _sorted;
    final rows = list
        .map(
          (a) => [
            (a['name'] ?? '').toString(),
            (a['mobile'] ?? '').toString(),
            (a['city'] ?? '').toString(),
            (a['accountType'] ?? '').toString(),
          ],
        )
        .toList();
    return Container(
      color: AppUi.surfaceAlt,
      child: Column(
        children: [
          _ErpMasterHeader(
            title: 'Account Information Edit',
            subtitle: 'Edit party master records and default account list sorting',
            icon: Icons.account_balance_wallet_rounded,
            onClose: widget.onClose,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                    child: _SectionCard(
                      title: 'Account details',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CompactFormRow(
                            label: 'List sort',
                            field: _compactDropdown(
                              value: _sortingTypeLocal,
                              values: _sortingTypes,
                              onChanged: (v) => setState(() => _sortingTypeLocal = v),
                            ),
                          ),
                          _CompactFormRow(
                            label: 'Name',
                            field: _compactInput(controller: _name),
                          ),
                          _CompactFormRow(
                            label: 'Short name',
                            field: _compactInput(controller: _short),
                          ),
                          _CompactFormRow(
                            label: 'Type',
                            field: _compactDropdown(
                              value: _ledgerType,
                              values: const ['Customer', 'Supplier'],
                              onChanged: (v) => setState(() => _ledgerType = v),
                            ),
                          ),
                          _CompactFormRow(
                            label: 'Mobile',
                            field: _compactInput(controller: _mobile),
                          ),
                          _CompactFormRow(
                            label: 'City',
                            field: _compactInput(controller: _city),
                          ),
                          _CompactFormRow(
                            label: 'GSTIN',
                            field: _compactInput(controller: _gst),
                          ),
                          _CompactFormRow(
                            label: 'Address 1',
                            topAligned: true,
                            field: _compactInput(controller: _addr1, maxLines: 2),
                          ),
                          _CompactFormRow(
                            label: 'Address 2',
                            topAligned: true,
                            field: _compactInput(controller: _addr2, maxLines: 2),
                          ),
                          _CompactFormRow(
                            label: 'PIN',
                            field: _compactInput(controller: _pin),
                          ),
                          _CompactFormRow(
                            label: 'Opening',
                            field: _compactInput(controller: _opening),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 8, 10),
                    child: _SimpleTable(
                      headers: const ['Name', 'Mobile', 'City', 'Type'],
                      selectedIndex: _selectedIndex,
                      rows: rows,
                      onRowTap: (i) => setState(() => _selectedIndex = i),
                    ),
                  ),
                ),
                _erpActionsColumn(
                  onEdit: _edit,
                  onDelete: _delete,
                  onSave: _save,
                  onClear: _clear,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProductInfoEditScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const ProductInfoEditScreen({super.key, this.onClose});

  @override
  State<ProductInfoEditScreen> createState() => _ProductInfoEditScreenState();
}

class _ProductInfoEditScreenState extends State<ProductInfoEditScreen> {
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _cat = TextEditingController();
  final _mrp = TextEditingController();
  final _sale = TextEditingController();
  final _stock = TextEditingController();
  final _hsn = TextEditingController();
  final _barcode = TextEditingController();
  final _expiry = TextEditingController();
  int? _selectedIndex;
  int? _editingId;

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _cat.dispose();
    _mrp.dispose();
    _sale.dispose();
    _stock.dispose();
    _hsn.dispose();
    _barcode.dispose();
    _expiry.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _list => products;

  void _loadForm(Map<String, dynamic> p) {
    _editingId = p['id'] as int?;
    _name.text = (p['name'] ?? '').toString();
    _company.text = (p['company'] ?? '').toString();
    _cat.text = (p['category'] ?? '').toString();
    _mrp.text = (p['mrp'] ?? '').toString();
    _sale.text = (p['saleRate'] ?? p['wRate'] ?? '').toString();
    _stock.text = (p['stock'] ?? '').toString();
    _hsn.text = (p['hsn'] ?? '').toString();
    _barcode.text = (p['barcode'] ?? '').toString();
    _expiry.text = (p['expiryDate'] ?? '').toString();
  }

  void _clear() {
    setState(() {
      _selectedIndex = null;
      _editingId = null;
      _name.clear();
      _company.clear();
      _cat.clear();
      _mrp.clear();
      _sale.clear();
      _stock.clear();
      _hsn.clear();
      _barcode.clear();
      _expiry.clear();
    });
    _erpSnack(context, 'Cleared');
  }

  void _edit() {
    if (_selectedIndex == null) {
      _erpSnack(context, 'Select a row to edit');
      return;
    }
    setState(() => _loadForm(_list[_selectedIndex!]));
  }

  Future<void> _delete() async {
    if (_selectedIndex == null) {
      _erpSnack(context, 'Select a row to delete');
      return;
    }
    final id = _list[_selectedIndex!]['id'] as int?;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: const Text('Removes product master. Ensure it is not referenced on open invoices.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteProductRow(id);
      products.removeWhere((p) => p['id'] == id);
      if (!mounted) return;
      setState(() {
        _selectedIndex = null;
        _editingId = null;
        _name.clear();
        _company.clear();
        _cat.clear();
        _mrp.clear();
        _sale.clear();
        _stock.clear();
        _hsn.clear();
        _barcode.clear();
        _expiry.clear();
      });
      _erpSnack(context, 'Deleted');
    } catch (e) {
      if (mounted) _erpSnack(context, 'Delete failed: $e');
    }
  }

  Map<String, dynamic> _buildProductRecord(int id) {
    final saleRateStr = _sale.text.trim();
    final sv = double.tryParse(saleRateStr) ?? 0;
    final cost = sv * 0.85;
    final marginRs = sv - cost;
    final margin = sv == 0 ? 0.0 : (marginRs / sv) * 100;
    if (_editingId != null) {
      final base = Map<String, dynamic>.from(
        products.firstWhere((p) => p['id'] == id),
      );
      base['name'] = _name.text.trim();
      base['company'] = _company.text.trim();
      base['category'] = _cat.text.trim();
      base['mrp'] = _mrp.text.trim();
      base['saleRate'] = saleRateStr;
      base['wRate'] = saleRateStr;
      base['stock'] = _stock.text.trim();
      base['hsn'] = _hsn.text.trim();
      base['barcode'] = _barcode.text.trim();
      base['expiryDate'] = _expiry.text.trim();
      base['costRate'] = cost.toStringAsFixed(2);
      base['margin'] = margin.toStringAsFixed(2);
      base['marginRs'] = marginRs.toStringAsFixed(2);
      return base;
    }
    return <String, dynamic>{
      'id': id,
      'name': _name.text.trim(),
      'description': '',
      'company': _company.text.trim(),
      'purPack': '1',
      'salesPack': '1',
      'minStock': '10',
      'maxStock': '500',
      'mrp': _mrp.text.trim(),
      'vatOn': 'W/Rate',
      'favourite': '',
      'generic': '',
      'remarks': '',
      'discount': 'Yes',
      'hsn': _hsn.text.trim(),
      'purGst': 'GST 12% (P)',
      'salesGst': 'GST 12% (S)',
      'ratio': '',
      'reorderQty': '20',
      'expiryDate': _expiry.text.trim(),
      'expiry': 'Yes',
      'addVat': '',
      'taxOnRate': 'Inclusive',
      'barcode': _barcode.text.trim(),
      'category': _cat.text.trim().isEmpty ? 'TABLET' : _cat.text.trim(),
      'schedule': 'H',
      'wRate': saleRateStr,
      'excise': '0.00',
      'suffered': '0.00',
      'cst': '0.00',
      'lst': '0.00',
      'lstRs': '0.00',
      'octroi': '0.00',
      'disc': '0.00',
      'saleRate': saleRateStr,
      'costRate': cost.toStringAsFixed(2),
      'margin': margin.toStringAsFixed(2),
      'marginRs': marginRs.toStringAsFixed(2),
      'stock': _stock.text.trim(),
    };
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _erpSnack(context, 'Name is required');
      return;
    }
    if (double.tryParse(_mrp.text.trim()) == null ||
        double.tryParse(_sale.text.trim()) == null ||
        double.tryParse(_stock.text.trim()) == null) {
      _erpSnack(context, 'MRP, sale rate and stock must be numeric');
      return;
    }
    try {
      if (_editingId != null) {
        final ix = products.indexWhere((p) => p['id'] == _editingId);
        if (ix < 0) {
          _erpSnack(context, 'Product not found');
          return;
        }
        final dup = products.any((p) {
          final same =
              (p['name'] ?? '').toString().trim().toLowerCase() == _name.text.trim().toLowerCase();
          return same && p['id'] != _editingId;
        });
        if (dup) {
          _erpSnack(context, 'Duplicate product name');
          return;
        }
        products[ix] = _buildProductRecord(_editingId!);
        await persistProductRow(products[ix]);
      } else {
        final dup = products.any(
          (p) =>
              (p['name'] ?? '').toString().trim().toLowerCase() ==
              _name.text.trim().toLowerCase(),
        );
        if (dup) {
          _erpSnack(context, 'Duplicate product name');
          return;
        }
        _relinkSeedsAfterHydrate();
        final id = _productSeed++;
        final rec = _buildProductRecord(id);
        products.add(rec);
        await persistProductRow(rec);
      }
      if (!mounted) return;
      setState(() {
        _selectedIndex = null;
        _editingId = null;
        _name.clear();
        _company.clear();
        _cat.clear();
        _mrp.clear();
        _sale.clear();
        _stock.clear();
        _hsn.clear();
        _barcode.clear();
        _expiry.clear();
      });
      _erpSnack(context, 'Saved');
    } catch (e) {
      if (mounted) _erpSnack(context, 'Save error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _list
        .map(
          (p) => [
            (p['name'] ?? '').toString(),
            (p['company'] ?? '').toString(),
            (p['mrp'] ?? '').toString(),
            (p['stock'] ?? '').toString(),
          ],
        )
        .toList();
    return Container(
      color: AppUi.surfaceAlt,
      child: Column(
        children: [
          _ErpMasterHeader(
            title: 'Product Information Edit',
            subtitle: 'Edit medicine / inventory master fields',
            icon: Icons.medication_rounded,
            onClose: widget.onClose,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                    child: _SectionCard(
                      title: 'Product',
                      child: Column(
                        children: [
                          _CompactFormRow(
                            label: 'Name',
                            field: _compactInput(controller: _name),
                          ),
                          _CompactFormRow(
                            label: 'Company',
                            field: _compactInput(controller: _company),
                          ),
                          _CompactFormRow(
                            label: 'Category',
                            field: _compactInput(controller: _cat),
                          ),
                          _CompactFormRow(
                            label: 'MRP',
                            field: _compactInput(
                              controller: _mrp,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          _CompactFormRow(
                            label: 'Sale rate',
                            field: _compactInput(
                              controller: _sale,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          _CompactFormRow(
                            label: 'Stock',
                            field: _compactInput(
                              controller: _stock,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          _CompactFormRow(
                            label: 'HSN',
                            field: _compactInput(controller: _hsn),
                          ),
                          _CompactFormRow(
                            label: 'Barcode',
                            field: _compactInput(controller: _barcode),
                          ),
                          _CompactFormRow(
                            label: 'Expiry',
                            field: _compactInput(controller: _expiry),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 8, 10),
                    child: _SimpleTable(
                      headers: const ['Name', 'Company', 'MRP', 'Stock'],
                      selectedIndex: _selectedIndex,
                      rows: rows,
                      onRowTap: (i) => setState(() => _selectedIndex = i),
                    ),
                  ),
                ),
                _erpActionsColumn(
                  onEdit: _edit,
                  onDelete: _delete,
                  onSave: _save,
                  onClear: _clear,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
