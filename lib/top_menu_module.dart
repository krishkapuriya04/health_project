part of 'package:health_project/main.dart';

String normalizeTopMenuLabel(String label) =>
    label.replaceAll(RegExp(r'\s*>\s*$'), '').trim();

void appendAppActivityLog(String action) {
  final user = users.isNotEmpty
      ? (users.first['username'] ?? 'User').toString()
      : 'System';
  appActivityLog.insert(0, {
    'at': DateTime.now().toIso8601String(),
    'action': action,
    'user': user,
  });
  if (appActivityLog.length > 500) {
    appActivityLog.removeRange(500, appActivityLog.length);
  }
}

double _tmParseDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

/// Sum receipt or payment rows for `dayPrefix` (ISO date prefix, e.g. 2026-05-01).
double _tmSumAccountModuleDay(
  String listKey,
  String dayPrefix, {
  bool cashOnly = false,
}) {
  final rows = accountModuleRecords[listKey] ?? const <Map<String, dynamic>>[];
  var t = 0.0;
  for (final r in rows) {
    final d = '${r['date'] ?? ''}';
    if (!d.startsWith(dayPrefix)) continue;
    if (cashOnly) {
      final mode = '${r['mode'] ?? ''}'.trim().toLowerCase();
      if (mode != 'cash') continue;
    }
    t += _tmParseDouble(r['amount']);
  }
  return t;
}

DateTime? _tryParseExpiryDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;
  final p = s.split(RegExp(r'[/-]'));
  if (p.length != 3) return null;
  final a = int.tryParse(p[0].trim());
  final b = int.tryParse(p[1].trim());
  final c = int.tryParse(p[2].trim());
  if (a == null || b == null || c == null) return null;
  if (c < 100) {
    return DateTime(c + 2000, b, a);
  }
  if (a > 31) {
    return DateTime(a, b, c);
  }
  return DateTime(c, b, a);
}

List<Map<String, dynamic>> _collectBatchExpiryRows() {
  final rows = <Map<String, dynamic>>[];
  void scan(String module, Map<String, dynamic> inv) {
    final items = inv['items'];
    if (items is! List) return;
    final bill = (inv['billNo'] ?? '').toString();
    for (final raw in items) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      rows.add({
        'productName': m['productName'] ?? '',
        'batch': m['batch'] ?? '',
        'expiry': m['expiry'] ?? '',
        'qty': _tmParseDouble(m['qty']),
        'bill': bill,
        'module': module,
      });
    }
  }

  for (final inv in salesInvoiceRecords) {
    scan('Sales', inv);
  }
  for (final inv in purchaseBillRecords) {
    scan('Purchase', inv);
  }
  return rows;
}

class _TopMenuPalette {
  const _TopMenuPalette({
    required this.primary,
    required this.surface,
    required this.icon,
  });

  final Color primary;
  final Color surface;
  final IconData icon;

  static _TopMenuPalette forGroup(String group) {
    switch (group) {
      case 'Special':
        return const _TopMenuPalette(
          primary: Color(0xFF4F46E5),
          surface: Color(0xFFEEF2FF),
          icon: Icons.auto_awesome,
        );
      case 'Periodical':
        return const _TopMenuPalette(
          primary: Color(0xFF0D9488),
          surface: Color(0xFFCCFBF1),
          icon: Icons.calendar_month,
        );
      case 'Utility':
        return const _TopMenuPalette(
          primary: Color(0xFFB45309),
          surface: Color(0xFFFEF3C7),
          icon: Icons.build_circle,
        );
      case 'Printers':
        return const _TopMenuPalette(
          primary: Color(0xFF6D28D9),
          surface: Color(0xFFEDE9FE),
          icon: Icons.print,
        );
      case 'ActiveWork':
        return const _TopMenuPalette(
          primary: Color(0xFFEA580C),
          surface: Color(0xFFFFEDD5),
          icon: Icons.bolt,
        );
      case 'Infoserver':
        return const _TopMenuPalette(
          primary: Color(0xFF0369A1),
          surface: Color(0xFFE0F2FE),
          icon: Icons.cloud,
        );
      default:
        return const _TopMenuPalette(
          primary: Color(0xFF475569),
          surface: Color(0xFFF1F5F9),
          icon: Icons.widgets,
        );
    }
  }
}

class TopMenuModuleScreen extends StatelessWidget {
  final String group;
  final String item;
  final VoidCallback onClose;
  final void Function(String screen, {String? placeholderTitle}) onNavigate;
  final VoidCallback onRefresh;

  const TopMenuModuleScreen({
    super.key,
    required this.group,
    required this.item,
    required this.onClose,
    required this.onNavigate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final p = _TopMenuPalette.forGroup(group);
    return Material(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(
                bottom: BorderSide(color: p.primary.withValues(alpha: 0.25)),
              ),
            ),
            child: Row(
              children: [
                Icon(p.icon, color: p.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: p.primary,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        item,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: onClose,
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _TopMenuBodyRouter(
                group: group,
                item: item,
                palette: p,
                onNavigate: onNavigate,
                onRefresh: onRefresh,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopMenuBodyRouter extends StatelessWidget {
  final String group;
  final String item;
  final _TopMenuPalette palette;
  final void Function(String screen, {String? placeholderTitle}) onNavigate;
  final VoidCallback onRefresh;

  // ignore: prefer_const_constructors_in_immutables
  _TopMenuBodyRouter({
    required this.group,
    required this.item,
    required this.palette,
    required this.onNavigate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    switch ((group, item)) {
      case ('Special', 'Discount Management'):
        return _DiscountRulesPanel(palette: palette, onRefresh: onRefresh);
      case ('Special', 'Scheme / Offers'):
        return _SchemeOffersPanel(palette: palette, onRefresh: onRefresh);
      case ('Special', 'Doctor Commission'):
        return _DoctorCommissionPanel(palette: palette, onRefresh: onRefresh);
      case ('Special', 'Order Chit Register'):
        return _OrderChitRegisterPanel(palette: palette, onRefresh: onRefresh);
      case ('Special', 'Challan Register'):
        return _ChallanRegisterPanel(palette: palette);
      case ('Special', 'Schedule Register'):
        return _ScheduleRegisterPanel(palette: palette, onRefresh: onRefresh);
      case ('Special', 'Sales Margin'):
        return _SalesMarginPanel(palette: palette);
      case ('Special', 'Invoice Import'):
        return _InvoiceImportPanel(palette: palette, onRefresh: onRefresh);
      case ('Special', 'Proforma/Special Invoice'):
      case ('Special', 'Proforma Invoice Print'):
      case ('Special', 'Proforma Invoice Report'):
        return _ProformaHubPanel(
          palette: palette,
          item: item,
          onRefresh: onRefresh,
        );
      case ('Periodical', 'Expiry Management'):
        return _ExpiryManagementPanel(palette: palette);
      case ('Periodical', 'Physical Verification'):
        return _PhysicalVerificationPanel(palette: palette);
      case ('Periodical', 'Backup & Restore'):
        return _SessionBackupPanel(
          palette: palette,
          mode: _BackupPanelMode.both,
          onRefresh: onRefresh,
        );
      case ('Periodical', 'Daily Closing'):
        return _DailyClosingPanel(palette: palette, onRefresh: onRefresh);
      case ('Utility', 'Calculator'):
        return _CalculatorWorkspacePanel(palette: palette);
      case ('Utility', 'Backup'):
        return _SessionBackupPanel(
          palette: palette,
          mode: _BackupPanelMode.backupOnly,
          onRefresh: onRefresh,
        );
      case ('Utility', 'Restore'):
        return _SessionBackupPanel(
          palette: palette,
          mode: _BackupPanelMode.restoreOnly,
          onRefresh: onRefresh,
        );
      case ('Utility', 'Import / Export Data'):
        return _ImportExportPanel(palette: palette, onRefresh: onRefresh);
      case ('Utility', 'Store Settings'):
        return _StoreSettingsPanel(palette: palette, onRefresh: onRefresh);
      case ('Utility', 'Task Scheduler'):
        return _TaskSchedulerPanel(palette: palette, onRefresh: onRefresh);
      case ('Printers', 'Report Print'):
        return _ReportPrintPanel(palette: palette);
      case ('Printers', 'Print Setup'):
        return _PrintSetupPanel(palette: palette, onRefresh: onRefresh);
      case ('Printers', 'Default Printer'):
        return _DefaultPrinterPanel(palette: palette, onRefresh: onRefresh);
      case ('Printers', 'Label Printing'):
        return _LabelPrintPanel(palette: palette, onRefresh: onRefresh);
      case ('Printers', 'Barcode Printing'):
        return _BarcodePrintPanel(palette: palette, onRefresh: onRefresh);
      case ('ActiveWork', 'Active Work List'):
        return _ActiveWorkListPanel(palette: palette, onRefresh: onRefresh);
      case ('ActiveWork', 'Pending Tasks'):
        return _PendingTasksPanel(palette: palette, onRefresh: onRefresh);
      case ('ActiveWork', 'Current Sales Activity'):
        return _CurrentSalesActivityPanel(palette: palette);
      case ('ActiveWork', 'User Activity Log'):
        return _UserActivityLogPanel(palette: palette);
      case ('Infoserver', 'Sync Data'):
        return _InfoserverSyncPanel(palette: palette, onRefresh: onRefresh);
      case ('Infoserver', 'Upload/Download'):
        return _InfoserverTransferPanel(palette: palette, onRefresh: onRefresh);
      case ('Infoserver', 'Server Settings'):
        return _InfoserverServerSettingsPanel(
          palette: palette,
          onRefresh: onRefresh,
        );
      case ('Infoserver', 'Analytics Dashboard'):
        return _InfoserverAnalyticsPanel(palette: palette);
      case ('Infoserver', 'Notifications & Alerts'):
        return _InfoserverNotificationsPanel(palette: palette);
      case ('Periodical', 'Scheme/Discount Report'):
        return _SchemeDiscountReportPanel(palette: palette);
      case ('Periodical', 'Doctor Analysis'):
        return _DoctorSalesAnalysisPanel(palette: palette);
      case ('Periodical', 'Party Analysis'):
        return _PartySalesAnalysisPanel(palette: palette);
      case ('Periodical', 'Patient Analysis'):
        return _PatientSalesAnalysisPanel(palette: palette);
      case ('Periodical', 'Account Receivable'):
        return _AccountReceivablePanel(palette: palette);
      case ('Periodical', 'Account Payable'):
        return _AccountPayablePanel(palette: palette);
      default:
        return _DynamicOperationsDeck(
          group: group,
          item: item,
          palette: palette,
          onNavigate: onNavigate,
          onRefresh: onRefresh,
        );
    }
  }
}

class MedicalCalculatorDialog extends StatefulWidget {
  const MedicalCalculatorDialog({super.key});

  @override
  State<MedicalCalculatorDialog> createState() =>
      _MedicalCalculatorDialogState();
}

class _MedicalCalculatorDialogState extends State<MedicalCalculatorDialog> {
  static final Map<LogicalKeyboardKey, String> _numpadKeys = {
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
    LogicalKeyboardKey.numpadAdd: '+',
    LogicalKeyboardKey.numpadSubtract: '-',
    LogicalKeyboardKey.numpadMultiply: '*',
    LogicalKeyboardKey.numpadDivide: '/',
    LogicalKeyboardKey.numpadDecimal: '.',
  };

  final FocusNode _focusNode = FocusNode();
  final List<String> _history = [];
  String _expr = '';
  String _display = '0';

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String _toInternal(String token) {
    switch (token) {
      case '÷':
        return '/';
      case '×':
        return '*';
      default:
        return token;
    }
  }

  void _tap(String s) {
    setState(() {
      if (s == 'C') {
        _expr = '';
        _display = '0';
        return;
      }
      if (s == '⌫') {
        if (_expr.isNotEmpty) {
          _expr = _expr.substring(0, _expr.length - 1);
        }
        _display = _expr.isEmpty ? '0' : _expr;
        return;
      }
      if (s == '%') {
        try {
          final raw = _expr.isNotEmpty ? _expr : _display;
          final sanitized = raw.replaceAll('×', '*').replaceAll('÷', '/');
          final result = _ExprParser().parse(sanitized);
          final p = result / 100;
          _display = _fmtCalc(p);
          _expr = _display == 'Error' ? '' : _display;
        } catch (_) {
          _display = 'Error';
          _expr = '';
        }
        return;
      }
      if (s == '=') {
        try {
          final sanitized = _expr.replaceAll('×', '*').replaceAll('÷', '/');
          final result = _ExprParser().parse(sanitized);
          final out = _fmtCalc(result);
          if (_expr.isNotEmpty) {
            _history.insert(0, '$_expr = $out');
            if (_history.length > 40) {
              _history.removeLast();
            }
          }
          _display = out;
          _expr = _display == 'Error' ? '' : _display;
        } catch (_) {
          _display = 'Error';
          _expr = '';
        }
        return;
      }
      _expr += _toInternal(s);
      _display = _expr;
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final logical = event.logicalKey;
    if (logical == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.enter ||
        logical == LogicalKeyboardKey.numpadEnter) {
      _tap('=');
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.backspace) {
      _tap('⌫');
      return KeyEventResult.handled;
    }
    final np = _numpadKeys[logical];
    if (np != null) {
      _tap(np);
      return KeyEventResult.handled;
    }
    final ch = event.character;
    if (ch != null && ch.isNotEmpty) {
      final c = ch;
      if (c == ',') {
        _tap('.');
        return KeyEventResult.handled;
      }
      if (c.length == 1 && '0123456789.+-*/()'.contains(c)) {
        _tap(c);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _copyResult() async {
    await Clipboard.setData(ClipboardData(text: _display));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied result'),
        duration: Duration(milliseconds: 500),
      ),
    );
  }

  static const double _keyH = 50;
  static const double _keyPad = 4;

  Widget _calcKey(
    String label, {
    bool equals = false,
    bool muted = false,
    int flex = 1,
  }) {
    final bg = equals
        ? const Color(0xFFF97316)
        : muted
            ? const Color(0xFF334155)
            : const Color(0xFF1E293B);
    final fg = equals ? Colors.white : const Color(0xFFE2E8F0);
    final display = label == '/' ? '÷' : (label == '*' ? '×' : label);
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(_keyPad),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              if (label == '⌫') {
                _tap('⌫');
              } else if (label == 'C') {
                _tap('C');
              } else if (label == '=') {
                _tap('=');
              } else if (label == '%') {
                _tap('%');
              } else {
                _tap(label);
              }
            },
            child: SizedBox(
              height: _keyH,
              child: Center(
                child: Text(
                  display,
                  style: TextStyle(
                    fontSize: display.length > 1 ? 16 : 21,
                    fontWeight: equals ? FontWeight.w800 : FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _calcRow(List<Widget> children) {
    return SizedBox(
      height: _keyH + _keyPad * 2,
      child: Row(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: const Color(0xFF0F172A),
          elevation: 32,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _onKey,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.calculate_rounded,
                          color: Color(0xFF38BDF8),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Calculator',
                          style: TextStyle(
                            color: Color(0xFFF8FAFC),
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _expr = '';
                          _display = '0';
                        }),
                        child: const Text(
                          'Clear all',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy',
                        visualDensity: VisualDensity.compact,
                        onPressed: _copyResult,
                        icon: const Icon(
                          Icons.copy_rounded,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close (Esc)',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF94A3B8),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 34,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      itemCount: _history.length.clamp(0, 8),
                      itemBuilder: (context, i) {
                        final h = _history[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Text(
                                h,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 76,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _display,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontSize: 34,
                          fontWeight: FontWeight.w400,
                          height: 1.0,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Type numbers · Enter = · Esc closes',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
                  ),
                  const SizedBox(height: 6),
                  _calcRow([
                    _calcKey('C', muted: true),
                    _calcKey('%', muted: true),
                    _calcKey('⌫', muted: true),
                    _calcKey('/', muted: true),
                  ]),
                  _calcRow([
                    _calcKey('7'),
                    _calcKey('8'),
                    _calcKey('9'),
                    _calcKey('*', muted: true),
                  ]),
                  _calcRow([
                    _calcKey('4'),
                    _calcKey('5'),
                    _calcKey('6'),
                    _calcKey('-', muted: true),
                  ]),
                  _calcRow([
                    _calcKey('1'),
                    _calcKey('2'),
                    _calcKey('3'),
                    _calcKey('+', muted: true),
                  ]),
                  _calcRow([
                    _calcKey('0', flex: 2),
                    _calcKey('.'),
                    _calcKey('=', equals: true),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
String _fmtCalc(double v) {
  if (!v.isFinite) return 'Error';
  var t = v.toStringAsFixed(8);
  t = t.replaceFirst(RegExp(r'\.?0+$'), '');
  return t.isEmpty ? '0' : t;
}

class _ExprParser {
  int _i = 0;
  late String _s;

  double parse(String input) {
    _s = input.replaceAll(' ', '');
    _i = 0;
    if (_s.isEmpty) return 0;
    final v = _expr();
    if (_i != _s.length) {
      throw const FormatException('trailing');
    }
    return v;
  }

  double _expr() {
    var v = _term();
    while (true) {
      if (_match('+')) {
        v += _term();
      } else if (_match('-')) {
        v -= _term();
      } else {
        break;
      }
    }
    return v;
  }

  double _term() {
    var v = _factor();
    while (true) {
      if (_match('*')) {
        v *= _factor();
      } else if (_match('/')) {
        final d = _factor();
        if (d == 0) throw Exception('div0');
        v /= d;
      } else {
        break;
      }
    }
    return v;
  }

  double _factor() {
    if (_match('+')) return _factor();
    if (_match('-')) return -_factor();
    if (_match('(')) {
      final inner = _expr();
      _expect(')');
      return inner;
    }
    return _readNumber();
  }

  bool _match(String ch) {
    if (_i < _s.length && _s[_i] == ch) {
      _i++;
      return true;
    }
    return false;
  }

  void _expect(String ch) {
    if (!_match(ch)) throw FormatException('expected $ch');
  }

  double _readNumber() {
    final start = _i;
    while (_i < _s.length && (RegExp(r'[0-9.]').hasMatch(_s[_i]))) {
      _i++;
    }
    if (start == _i) throw const FormatException('num');
    return double.parse(_s.substring(start, _i));
  }
}

Widget _tmCard({
  required _TopMenuPalette palette,
  required String title,
  required Widget child,
}) {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: palette.primary.withValues(alpha: 0.22)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: palette.primary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _DiscountRulesPanel extends StatefulWidget {
  const _DiscountRulesPanel({
    required this.palette,
    required this.onRefresh,
  });

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_DiscountRulesPanel> createState() => _DiscountRulesPanelState();
}

class _DiscountRulesPanelState extends State<_DiscountRulesPanel> {
  String _scope = 'product';
  final _target = TextEditingController();
  final _percent = TextEditingController();

  @override
  void dispose() {
    _target.dispose();
    _percent.dispose();
    super.dispose();
  }

  void _apply() {
    final p = double.tryParse(_percent.text.trim());
    if (p == null || p <= 0 || p > 100) {
      return;
    }
    if (_target.text.trim().isEmpty) return;
    final row = <String, dynamic>{
      'id': _discountRuleSeed++,
      'scope': _scope,
      'target': _target.text.trim(),
      'percent': p,
    };
    discountRules.insert(0, row);
    unawaited(persistDiscountRule(row));
    appendAppActivityLog('Discount rule added ($_scope ${_target.text})');
    _target.clear();
    _percent.clear();
    widget.onRefresh();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tmCard(
          palette: widget.palette,
          title: 'New discount rule',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _scope,
                decoration: const InputDecoration(
                  labelText: 'Applies to',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'product', child: Text('Product name')),
                  DropdownMenuItem(value: 'category', child: Text('Category')),
                  DropdownMenuItem(value: 'customer', child: Text('Customer / party')),
                ],
                onChanged: (v) => setState(() => _scope = v ?? 'product'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _target,
                decoration: const InputDecoration(
                  labelText: 'Product / category / customer text',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _percent,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Discount %',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check),
                label: const Text('Apply rule'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _tmCard(
          palette: widget.palette,
          title: 'Active rules (${discountRules.length})',
          child: discountRules.isEmpty
              ? const Text('No rules yet — add one above.')
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: discountRules.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = discountRules[i];
                    return ListTile(
                      dense: true,
                      title: Text('${r['scope']} → ${r['target']}'),
                      subtitle: Text('${r['percent']}%'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          final id = r['id'] as int?;
                          setState(() => discountRules.removeAt(i));
                          if (id != null) {
                            unawaited(
                              deleteJsonDocById(kCollDiscountRule, id),
                            );
                          }
                          widget.onRefresh();
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SchemeOffersPanel extends StatefulWidget {
  const _SchemeOffersPanel({required this.palette, required this.onRefresh});

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_SchemeOffersPanel> createState() => _SchemeOffersPanelState();
}

class _SchemeOffersPanelState extends State<_SchemeOffersPanel> {
  final _buy = TextEditingController(text: '1');
  final _get = TextEditingController(text: '1');
  final _label = TextEditingController();
  String? _productHint;
  bool _active = true;

  @override
  void dispose() {
    _buy.dispose();
    _get.dispose();
    _label.dispose();
    super.dispose();
  }

  void _save() {
    final bx = int.tryParse(_buy.text.trim()) ?? 0;
    final gy = int.tryParse(_get.text.trim()) ?? 0;
    if (bx <= 0 || gy < 0) return;
    if (_label.text.trim().isEmpty) return;
    final row = <String, dynamic>{
      'id': _schemeOfferSeed++,
      'buyX': bx,
      'getY': gy,
      'label': _label.text.trim(),
      'productHint': _productHint ?? '',
      'active': _active,
    };
    schemeOffers.insert(0, row);
    unawaited(persistSchemeOffer(row));
    appendAppActivityLog('Scheme saved: ${_label.text}');
    widget.onRefresh();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final names = products
        .map((p) => (p['name'] ?? p['productName'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (names.isEmpty) {
      return _tmCard(
        palette: widget.palette,
        title: 'Scheme / offers',
        child: const Text(
          'Add products in Product Master to anchor combo schemes.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tmCard(
          palette: widget.palette,
          title: 'Configure offer',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _productHint ??
                    (names.isNotEmpty ? names.first : null),
                decoration: const InputDecoration(
                  labelText: 'Primary product (optional anchor)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final n in names.take(80))
                    DropdownMenuItem(value: n, child: Text(n)),
                ],
                onChanged: (v) => setState(() => _productHint = v),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _buy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Buy X',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _get,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Get Y free / extra',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _label,
                decoration: const InputDecoration(
                  labelText: 'Scheme title (counter display)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active at billing'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              FilledButton.icon(
                onPressed: names.isEmpty ? null : _save,
                icon: const Icon(Icons.save),
                label: const Text('Save scheme'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _tmCard(
          palette: widget.palette,
          title: 'Schemes (${schemeOffers.length})',
          child: schemeOffers.isEmpty
              ? const Text('No schemes — add products in Product Master first.')
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: schemeOffers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = schemeOffers[i];
                    return ListTile(
                      dense: true,
                      title: Text('${s['label']}'),
                      subtitle: Text(
                        'Buy ${s['buyX']} → Get ${s['getY']} · ${s['active'] == true ? 'ON' : 'OFF'}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          final id = s['id'] as int?;
                          setState(() => schemeOffers.removeAt(i));
                          if (id != null) {
                            unawaited(deleteJsonDocById(kCollScheme, id));
                          }
                          widget.onRefresh();
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DoctorCommissionPanel extends StatefulWidget {
  const _DoctorCommissionPanel({
    required this.palette,
    required this.onRefresh,
  });

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_DoctorCommissionPanel> createState() =>
      _DoctorCommissionPanelState();
}

class _DoctorCommissionPanelState extends State<_DoctorCommissionPanel> {
  String? _doctor;
  final _pct = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _pct.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _add() {
    final p = double.tryParse(_pct.text.trim());
    if (_doctor == null || p == null || p < 0 || p > 100) return;
    final row = <String, dynamic>{
      'id': _doctorCommissionSeed++,
      'doctor': _doctor,
      'percent': p,
      'notes': _notes.text.trim(),
    };
    doctorCommissions.insert(0, row);
    unawaited(persistDoctorCommission(row));
    appendAppActivityLog('Doctor commission: $_doctor @ $p%');
    _pct.clear();
    _notes.clear();
    widget.onRefresh();
    setState(() {});
  }

  double _linkedSales(String doctorName) {
    var t = 0.0;
    for (final inv in salesInvoiceRecords) {
      if ((inv['doctor'] ?? '').toString().trim() == doctorName) {
        t += _tmParseDouble(inv['grandTotal']);
      }
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final names = doctors
        .map((d) => (d['name'] ?? d['doctorName'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (names.isEmpty) {
      return _tmCard(
        palette: widget.palette,
        title: 'Doctor commission',
        child: const Text(
          'Add doctors in Doctor Master first, then configure commission here.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tmCard(
          palette: widget.palette,
          title: 'Referral commission',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _doctor ?? (names.isNotEmpty ? names.first : null),
                decoration: const InputDecoration(
                  labelText: 'Doctor',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final n in names)
                    DropdownMenuItem(value: n, child: Text(n)),
                ],
                onChanged: (v) => setState(() => _doctor = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pct,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Commission %',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: names.isEmpty ? null : _add,
                icon: const Icon(Icons.add),
                label: const Text('Save commission row'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _tmCard(
          palette: widget.palette,
          title: 'Doctor · linked sales · rule',
          child: doctorCommissions.isEmpty
              ? const Text('No commission rows yet.')
              : Table(
                  border: TableBorder.all(color: Colors.black12),
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                      ),
                      children: [
                        _cellH('Doctor'),
                        _cellH('Sales linked'),
                        _cellH('%'),
                        _cellH('Est. comm.'),
                      ],
                    ),
                    for (final c in doctorCommissions)
                      TableRow(
                        children: [
                          _cell('${c['doctor']}'),
                          _cell(
                            _linkedSales('${c['doctor']}').toStringAsFixed(2),
                          ),
                          _cell('${c['percent']}'),
                          _cell(
                            (_linkedSales('${c['doctor']}') *
                                    _tmParseDouble(c['percent']) /
                                    100)
                                .toStringAsFixed(2),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

Widget _cell(String t) => Padding(
      padding: const EdgeInsets.all(8),
      child: Text(t),
    );

Widget _cellH(String t) => Padding(
      padding: const EdgeInsets.all(8),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
class _OrderChitRegisterPanel extends StatefulWidget {
  const _OrderChitRegisterPanel({
    required this.palette,
    required this.onRefresh,
  });

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_OrderChitRegisterPanel> createState() =>
      _OrderChitRegisterPanelState();
}

class _OrderChitRegisterPanelState extends State<_OrderChitRegisterPanel> {
  final _party = TextEditingController();
  final _items = TextEditingController();

  @override
  void dispose() {
    _party.dispose();
    _items.dispose();
    super.dispose();
  }

  void _add() {
    if (_party.text.trim().isEmpty) return;
    orderChitRecords.insert(0, {
      'id': _orderChitSeed++,
      'party': _party.text.trim(),
      'lines': _items.text.trim(),
      'at': DateTime.now().toIso8601String(),
      'status': 'Open',
    });
    appendAppActivityLog('Order chit for ${_party.text}');
    _party.clear();
    _items.clear();
    widget.onRefresh();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tmCard(
          palette: widget.palette,
          title: 'New order chit',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _party,
                decoration: const InputDecoration(
                  labelText: 'Patient / party',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _items,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Items & notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Register chit'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _tmCard(
          palette: widget.palette,
          title: 'Register (${orderChitRecords.length})',
          child: orderChitRecords.isEmpty
              ? const Text('No chits yet.')
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orderChitRecords.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = orderChitRecords[i];
                    return ListTile(
                      title: Text('${r['party']}'),
                      subtitle: Text('${r['at']} · ${r['status']}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          setState(() => r['status'] = v);
                          widget.onRefresh();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'Open', child: Text('Open')),
                          PopupMenuItem(
                            value: 'Supplied',
                            child: Text('Supplied'),
                          ),
                          PopupMenuItem(
                            value: 'Cancelled',
                            child: Text('Cancelled'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ChallanRegisterPanel extends StatelessWidget {
  const _ChallanRegisterPanel({required this.palette});

  final _TopMenuPalette palette;

  @override
  Widget build(BuildContext context) {
    return _tmCard(
      palette: palette,
      title: 'Delivery memos / challans (${deliveryMemos.length})',
      child: deliveryMemos.isEmpty
          ? const Text('No delivery memos — create from Invoice menu.')
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: deliveryMemos.length.clamp(0, 80),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = deliveryMemos[i];
                return ListTile(
                  dense: true,
                  title: Text('${m['memoNo'] ?? m['billNo'] ?? m['id']}'),
                  subtitle: Text(
                    '${m['date'] ?? ''} · ${m['party'] ?? m['customer'] ?? ''}',
                  ),
                );
              },
            ),
    );
  }
}

class _ScheduleRegisterPanel extends StatefulWidget {
  const _ScheduleRegisterPanel({
    required this.palette,
    required this.onRefresh,
  });

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_ScheduleRegisterPanel> createState() =>
      _ScheduleRegisterPanelState();
}

class _ScheduleRegisterPanelState extends State<_ScheduleRegisterPanel> {
  final _title = TextEditingController();
  final _when = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _when.dispose();
    super.dispose();
  }

  void _add() {
    if (_title.text.trim().isEmpty) return;
    scheduleRegisterRecords.insert(0, {
      'id': _scheduleRegisterSeed++,
      'title': _title.text.trim(),
      'when': _when.text.trim(),
      'created': DateTime.now().toIso8601String(),
    });
    _title.clear();
    _when.clear();
    widget.onRefresh();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tmCard(
          palette: widget.palette,
          title: 'Schedule entry',
          child: Column(
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _when,
                decoration: const InputDecoration(
                  labelText: 'When (date / time text)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.schedule),
                label: const Text('Add to register'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _tmCard(
          palette: widget.palette,
          title: 'Rows (${scheduleRegisterRecords.length})',
          child: scheduleRegisterRecords.isEmpty
              ? const Text('No schedules logged.')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: scheduleRegisterRecords.length,
                  itemBuilder: (context, i) {
                    final r = scheduleRegisterRecords[i];
                    return ListTile(
                      title: Text('${r['title']}'),
                      subtitle: Text('${r['when']} · ${r['created']}'),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SalesMarginPanel extends StatelessWidget {
  const _SalesMarginPanel({required this.palette});

  final _TopMenuPalette palette;

  @override
  Widget build(BuildContext context) {
    final rows = <TableRow>[
      TableRow(
        decoration: const BoxDecoration(color: Color(0xFFEEF2FF)),
        children: [
          _cellH('Bill'),
          _cellH('Date'),
          _cellH('Subtotal'),
          _cellH('Discount%'),
          _cellH('Grand'),
        ],
      ),
    ];
    for (final inv in salesInvoiceRecords.take(40)) {
      rows.add(
        TableRow(
          children: [
            _cell('${inv['billNo']}'),
            _cell('${inv['date']}'),
            _cell(_tmParseDouble(inv['subTotal']).toStringAsFixed(2)),
            _cell(_tmParseDouble(inv['discountPercent']).toStringAsFixed(2)),
            _cell(_tmParseDouble(inv['grandTotal']).toStringAsFixed(2)),
          ],
        ),
      );
    }
    return _tmCard(
      palette: palette,
      title: 'Sales margin view (from saved invoices)',
      child: salesInvoiceRecords.isEmpty
          ? const Text('No sales invoices yet.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                border: TableBorder.all(color: Colors.black12),
                defaultColumnWidth: const IntrinsicColumnWidth(),
                children: rows,
              ),
            ),
    );
  }
}

class _InvoiceImportPanel extends StatefulWidget {
  const _InvoiceImportPanel({required this.palette, required this.onRefresh});

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_InvoiceImportPanel> createState() => _InvoiceImportPanelState();
}

class _InvoiceImportPanelState extends State<_InvoiceImportPanel> {
  final _json = TextEditingController();

  void _import() {
    final raw = _json.text.trim();
    if (raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      var n = 0;
      for (final e in decoded) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        m['id'] = DateTime.now().microsecondsSinceEpoch + n;
        salesInvoiceRecords.insert(0, m);
        n++;
      }
      appendAppActivityLog('Imported $n sales rows');
      _json.clear();
      widget.onRefresh();
      setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _json.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _tmCard(
      palette: widget.palette,
      title: 'Invoice JSON import (list of invoice objects)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Paste a JSON array of objects with keys like billNo, date, party, items, grandTotal.',
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _json,
            maxLines: 10,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _import,
            icon: const Icon(Icons.upload),
            label: const Text('Import into sales register'),
          ),
        ],
      ),
    );
  }
}

class _ProformaHubPanel extends StatefulWidget {
  const _ProformaHubPanel({
    required this.palette,
    required this.item,
    required this.onRefresh,
  });

  final _TopMenuPalette palette;
  final String item;
  final VoidCallback onRefresh;

  @override
  State<_ProformaHubPanel> createState() => _ProformaHubPanelState();
}

class _ProformaHubPanelState extends State<_ProformaHubPanel> {
  final _party = TextEditingController();
  final _amt = TextEditingController();

  void _save() {
    final a = double.tryParse(_amt.text.trim());
    if (_party.text.trim().isEmpty || a == null) return;
    proformaInvoiceRecords.insert(0, {
      'id': _proformaInvoiceSeed++,
      'party': _party.text.trim(),
      'amount': a,
      'context': widget.item,
      'at': DateTime.now().toIso8601String(),
    });
    _party.clear();
    _amt.clear();
    widget.onRefresh();
    setState(() {});
  }

  @override
  void dispose() {
    _party.dispose();
    _amt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tmCard(
          palette: widget.palette,
          title: widget.item,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _party,
                decoration: const InputDecoration(
                  labelText: 'Party',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amt,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Proforma amount',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save proforma row'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final txt = proformaInvoiceRecords
                          .map((e) => '${e['party']}: ${e['amount']}')
                          .join('\n');
                      await Clipboard.setData(ClipboardData(text: txt));
                      appendAppActivityLog('Proforma list copied');
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy list'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _tmCard(
          palette: widget.palette,
          title: 'Saved proformas (${proformaInvoiceRecords.length})',
          child: proformaInvoiceRecords.isEmpty
              ? const Text('No proforma rows.')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: proformaInvoiceRecords.length,
                  itemBuilder: (context, i) {
                    final p = proformaInvoiceRecords[i];
                    return ListTile(
                      title: Text('${p['party']}'),
                      subtitle: Text('${p['at']} · ${p['context']}'),
                      trailing: Text('₹ ${_tmParseDouble(p['amount']).toStringAsFixed(2)}'),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ExpiryManagementPanel extends StatefulWidget {
  const _ExpiryManagementPanel({required this.palette});

  final _TopMenuPalette palette;

  @override
  State<_ExpiryManagementPanel> createState() => _ExpiryManagementPanelState();
}

class _ExpiryManagementPanelState extends State<_ExpiryManagementPanel> {
  DateTime _cutoff = DateTime.now().add(const Duration(days: 120));

  Color _rowColor(String expiryRaw) {
    final d = _tryParseExpiryDate(expiryRaw);
    if (d == null) return Colors.white;
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return const Color(0xFFFFE4E6);
    if (days <= 30) return const Color(0xFFFFEDD5);
    if (days <= 90) return const Color(0xFFFEF9C3);
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _collectBatchExpiryRows()
        .where((r) {
          final d = _tryParseExpiryDate('${r['expiry']}');
          if (d == null) return true;
          return !d.isAfter(_cutoff);
        })
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tmCard(
          palette: widget.palette,
          title: 'Filter by latest expiry to show',
          child: Row(
            children: [
              const Text('Show batches expiring on or before:'),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _cutoff,
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now.add(const Duration(days: 3650)),
                  );
                  if (picked != null) setState(() => _cutoff = picked);
                },
                child: Text(
                  '${_cutoff.year}-${_cutoff.month.toString().padLeft(2, '0')}-${_cutoff.day.toString().padLeft(2, '0')}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _tmCard(
          palette: widget.palette,
          title: 'Product | Batch | Expiry | Qty | Bill',
          child: rows.isEmpty
              ? const Text('No batch lines match filter.')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFCCFBF1),
                    ),
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Batch')),
                      DataColumn(label: Text('Expiry')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Bill')),
                      DataColumn(label: Text('Mod')),
                    ],
                    rows: [
                      for (final r in rows.take(200))
                        DataRow(
                          color: WidgetStateProperty.all(
                            _rowColor('${r['expiry']}'),
                          ),
                          cells: [
                            DataCell(Text('${r['productName']}')),
                            DataCell(Text('${r['batch']}')),
                            DataCell(Text('${r['expiry']}')),
                            DataCell(Text('${r['qty']}')),
                            DataCell(Text('${r['bill']}')),
                            DataCell(Text('${r['module']}')),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _PhysicalVerificationPanel extends StatelessWidget {
  const _PhysicalVerificationPanel({required this.palette});

  final _TopMenuPalette palette;

  @override
  Widget build(BuildContext context) {
    return _tmCard(
      palette: palette,
      title: 'Stock on book (Product Master)',
      child: products.isEmpty
          ? const Text('No products.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Product')),
                  DataColumn(label: Text('Pack')),
                  DataColumn(label: Text('Stock')),
                  DataColumn(label: Text('Reorder')),
                ],
                rows: [
                  for (final p in products.take(150))
                    DataRow(
                      cells: [
                        DataCell(Text('${p['name'] ?? p['productName'] ?? ''}')),
                        DataCell(Text('${p['pack'] ?? ''}')),
                        DataCell(Text('${p['stock'] ?? ''}')),
                        DataCell(
                          Text('${p['reorderQty'] ?? p['minStock'] ?? '-'}'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

enum _BackupPanelMode { backupOnly, restoreOnly, both }

class _SessionBackupPanel extends StatelessWidget {
  const _SessionBackupPanel({
    required this.palette,
    required this.mode,
    required this.onRefresh,
  });

  final _TopMenuPalette palette;
  final _BackupPanelMode mode;
  final VoidCallback onRefresh;

  Future<void> _backup(BuildContext context) async {
    try {
      final json = await exportFullSystemJsonString();
      appDataBackupJson = json;
      lastAppBackupAt = DateTime.now();
      await HealthDatabase.instance.putAppKv(
        kKvLastBackupAt,
        lastAppBackupAt!.toIso8601String(),
      );
      appendAppActivityLog('Full system backup (JSON)');
      onRefresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Backup created — full export (accounts, stock, ERP, settings).',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    }
  }

  Future<void> _restore(BuildContext context) async {
    final raw = appDataBackupJson;
    if (raw == null || raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No backup available.')),
      );
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Backup root must be a JSON object');
      }
      final m = Map<String, dynamic>.from(decoded);
      if (m['version'] == 1) {
        await applyFullSystemImportFromJsonString(raw);
        appendAppActivityLog('Full system restore from last backup');
      } else {
        void rep(String k, List<Map<String, dynamic>> target) {
          final v = m[k];
          if (v is List) {
            target
              ..clear()
              ..addAll(
                v.map((e) => Map<String, dynamic>.from(e as Map)),
              );
          }
        }
        rep('products', products);
        rep('salesInvoiceRecords', salesInvoiceRecords);
        rep('purchaseBillRecords', purchaseBillRecords);
        rep('accounts', accounts);
        rep('discountRules', discountRules);
        rep('schemeOffers', schemeOffers);
        rep('doctorCommissions', doctorCommissions);
        _relinkSeedsAfterHydrate();
        await rewriteAllPersistentCollections();
        appendAppActivityLog('Legacy snapshot restore + DB rewrite');
      }
      onRefresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Restored — data reloaded and SQLite updated where applicable.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showB =
        mode == _BackupPanelMode.backupOnly || mode == _BackupPanelMode.both;
    final showR =
        mode == _BackupPanelMode.restoreOnly || mode == _BackupPanelMode.both;
    return _tmCard(
      palette: palette,
      title: 'Full system backup & restore',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lastAppBackupAt == null
                ? 'No backup yet.'
                : 'Last backup: ${lastAppBackupAt!.toLocal()}',
          ),
          if (appDataBackupJson != null)
            Text('Snapshot size: ${appDataBackupJson!.length} chars'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (showB)
                FilledButton.icon(
                  onPressed: () => unawaited(_backup(context)),
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Backup now'),
                ),
              if (showR)
                FilledButton.tonalIcon(
                  onPressed: () => unawaited(_restore(context)),
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore last'),
                ),
              OutlinedButton.icon(
                onPressed: appDataBackupJson == null
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: appDataBackupJson!),
                        );
                        appendAppActivityLog('Backup JSON copied');
                      },
                icon: const Icon(Icons.copy),
                label: const Text('Copy JSON'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyClosingPanel extends StatefulWidget {
  const _DailyClosingPanel({
    required this.palette,
    required this.onRefresh,
  });

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_DailyClosingPanel> createState() => _DailyClosingPanelState();
}

class _DailyClosingPanelState extends State<_DailyClosingPanel> {
  bool _busy = false;

  double _sumSalesDay(String day) {
    var t = 0.0;
    for (final r in salesInvoiceRecords) {
      if ('${r['date']}'.startsWith(day)) {
        t += _tmParseDouble(r['grandTotal']);
      }
    }
    return t;
  }

  double _sumPurDay(String day) {
    var t = 0.0;
    for (final r in purchaseBillRecords) {
      if ('${r['date']}'.startsWith(day)) {
        t += _tmParseDouble(r['grandTotal']);
      }
    }
    return t;
  }

  Future<void> _closeDay(BuildContext context) async {
    final day = DateTime.now().toIso8601String().split('T').first;
    final s = _sumSalesDay(day);
    final p = _sumPurDay(day);
    final totalReceipt = _tmSumAccountModuleDay('Receipt', day);
    final totalPayment = _tmSumAccountModuleDay('Payment', day);
    final cashReceipt = _tmSumAccountModuleDay('Receipt', day, cashOnly: true);
    final cashPayment = _tmSumAccountModuleDay('Payment', day, cashOnly: true);
    final closingCash = cashReceipt - cashPayment;
    final receiptPaymentNet = totalReceipt - totalPayment;
    final netTrade = s - p;

    setState(() => _busy = true);
    try {
      final row = <String, dynamic>{
        'closingId': _dailyClosingSeed++,
        'day': day,
        'totalSales': s,
        'totalPurchase': p,
        'totalReceipt': totalReceipt,
        'totalPayment': totalPayment,
        'cashReceipt': cashReceipt,
        'cashPayment': cashPayment,
        'closingCash': closingCash,
        'receiptPaymentNet': receiptPaymentNet,
        'netTrade': netTrade,
        'closedAt': DateTime.now().toIso8601String(),
      };
      dailyClosingRecords.insert(0, row);
      await persistDailyClosing(row);
      appendAppActivityLog('Daily close $day (#${row['closingId']})');
      widget.onRefresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Day closed — saved (closing cash ₹${closingCash.toStringAsFixed(2)}).',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Daily close failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().toIso8601String().split('T').first;
    final s = _sumSalesDay(day);
    final p = _sumPurDay(day);
    final totalReceipt = _tmSumAccountModuleDay('Receipt', day);
    final totalPayment = _tmSumAccountModuleDay('Payment', day);
    final cashReceipt = _tmSumAccountModuleDay('Receipt', day, cashOnly: true);
    final cashPayment = _tmSumAccountModuleDay('Payment', day, cashOnly: true);
    final closingCash = cashReceipt - cashPayment;
    final receiptPaymentNet = totalReceipt - totalPayment;
    final netTrade = s - p;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tmCard(
          palette: widget.palette,
          title: 'Today ($day)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total sales: ₹ ${s.toStringAsFixed(2)}'),
              Text('Total purchase: ₹ ${p.toStringAsFixed(2)}'),
              Text('Net trade (sales − purchase): ₹ ${netTrade.toStringAsFixed(2)}'),
              const Divider(height: 20),
              Text('Total receipts: ₹ ${totalReceipt.toStringAsFixed(2)}'),
              Text('Total payments: ₹ ${totalPayment.toStringAsFixed(2)}'),
              Text('Receipts − payments: ₹ ${receiptPaymentNet.toStringAsFixed(2)}'),
              const Divider(height: 20),
              Text('Cash receipts: ₹ ${cashReceipt.toStringAsFixed(2)}'),
              Text('Cash payments: ₹ ${cashPayment.toStringAsFixed(2)}'),
              Text(
                'Closing cash (cash in − cash out): ₹ ${closingCash.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : () => unawaited(_closeDay(context)),
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_clock),
          label: Text(_busy ? 'Saving…' : 'Close day'),
        ),
        const SizedBox(height: 14),
        _tmCard(
          palette: widget.palette,
          title: 'Closing history (${dailyClosingRecords.length})',
          child: dailyClosingRecords.isEmpty
              ? const Text('No closings yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dailyClosingRecords.length,
                  itemBuilder: (context, i) {
                    final r = dailyClosingRecords[i];
                    final sales = _tmParseDouble(
                      r['totalSales'] ?? r['sales'],
                    );
                    final pur = _tmParseDouble(
                      r['totalPurchase'] ?? r['purchase'],
                    );
                    final rc = _tmParseDouble(r['totalReceipt']);
                    final py = _tmParseDouble(r['totalPayment']);
                    final cc = _tmParseDouble(r['closingCash']);
                    return ListTile(
                      title: Text('${r['day']}  ·  #${r['closingId'] ?? '-'}'),
                      subtitle: Text(
                        'Sales ₹${sales.toStringAsFixed(2)} · Pur ₹${pur.toStringAsFixed(2)} · Rcpt ₹${rc.toStringAsFixed(2)} · Pay ₹${py.toStringAsFixed(2)} · Cash close ₹${cc.toStringAsFixed(2)}',
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CalculatorWorkspacePanel extends StatefulWidget {
  const _CalculatorWorkspacePanel({required this.palette});

  final _TopMenuPalette palette;

  @override
  State<_CalculatorWorkspacePanel> createState() =>
      _CalculatorWorkspacePanelState();
}

class _CalculatorWorkspacePanelState extends State<_CalculatorWorkspacePanel> {
  @override
  Widget build(BuildContext context) {
    return _tmCard(
      palette: widget.palette,
      title: 'Calculator',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Compact desktop keypad with history, keyboard shortcuts, and copy — matches Utility → Calculator (Ctrl+F1).',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.blueGrey.shade700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              showDialog<void>(
                context: context,
                barrierDismissible: true,
                builder: (dialogContext) => const MedicalCalculatorDialog(),
              );
            },
            icon: const Icon(Icons.calculate_rounded),
            label: const Text('Open calculator'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
class _ImportExportPanel extends StatefulWidget {
  const _ImportExportPanel({required this.palette, required this.onRefresh});

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_ImportExportPanel> createState() => _ImportExportPanelState();
}

class _ImportExportPanelState extends State<_ImportExportPanel> {
  final _paste = TextEditingController();

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  void _importProducts() {
    final raw = _paste.text.trim();
    if (raw.isEmpty) return;
    try {
      final d = jsonDecode(raw);
      if (d is! List) return;
      var n = 0;
      for (final e in d) {
        if (e is! Map) continue;
        products.insert(0, Map<String, dynamic>.from(e));
        n++;
      }
      appendAppActivityLog('Imported $n product rows');
      _paste.clear();
      widget.onRefresh();
      setState(() {});
    } catch (_) {}
  }

  Future<void> _exportSummary() async {
    final buf = StringBuffer();
    buf.writeln('PRODUCTS,${products.length}');
    buf.writeln('SALES,${salesInvoiceRecords.length}');
    buf.writeln('PURCHASES,${purchaseBillRecords.length}');
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    appendAppActivityLog('Export summary copied');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tmCard(
          palette: widget.palette,
          title: 'Import products (JSON list)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _paste,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '[{"name":"...","stock":"10",...}, ...]',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _importProducts,
                icon: const Icon(Icons.file_upload),
                label: const Text('Merge into Product Master'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _tmCard(
          palette: widget.palette,
          title: 'Export',
          child: Wrap(
            spacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: _exportSummary,
                icon: const Icon(Icons.table_chart),
                label: const Text('Copy CSV summary'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: jsonEncode(products)),
                  );
                  appendAppActivityLog('Products JSON copied');
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy all products JSON'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoreSettingsPanel extends StatefulWidget {
  const _StoreSettingsPanel({required this.palette, required this.onRefresh});

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_StoreSettingsPanel> createState() => _StoreSettingsPanelState();
}

class _StoreSettingsPanelState extends State<_StoreSettingsPanel> {
  late final _name = TextEditingController(
    text: '${globalMedicalStoreSettings['storeName'] ?? ''}',
  );
  late final _gst = TextEditingController(
    text: '${globalMedicalStoreSettings['gstNumber'] ?? ''}',
  );
  late String _currency =
      '${globalMedicalStoreSettings['currency'] ?? 'INR'}';
  late String _theme =
      '${globalMedicalStoreSettings['themeHint'] ?? 'system'}';

  @override
  void dispose() {
    _name.dispose();
    _gst.dispose();
    super.dispose();
  }

  void _save() {
    globalMedicalStoreSettings['storeName'] = _name.text.trim();
    globalMedicalStoreSettings['gstNumber'] = _gst.text.trim();
    globalMedicalStoreSettings['currency'] = _currency;
    globalMedicalStoreSettings['themeHint'] = _theme;
    unawaited(persistGlobalSettingsSnapshot());
    appendAppActivityLog('Store settings saved');
    widget.onRefresh();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _tmCard(
      palette: widget.palette,
      title: 'Store profile & GST',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Store name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _gst,
            decoration: const InputDecoration(
              labelText: 'GST number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _currency,
            decoration: const InputDecoration(
              labelText: 'Currency',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'INR', child: Text('INR')),
              DropdownMenuItem(value: 'USD', child: Text('USD')),
            ],
            onChanged: (v) => setState(() => _currency = v ?? 'INR'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _theme,
            decoration: const InputDecoration(
              labelText: 'Theme hint',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'system', child: Text('System')),
              DropdownMenuItem(value: 'light', child: Text('Light')),
              DropdownMenuItem(value: 'dark', child: Text('Dark')),
            ],
            onChanged: (v) => setState(() => _theme = v ?? 'system'),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save settings'),
          ),
        ],
      ),
    );
  }
}

class _TaskSchedulerPanel extends StatefulWidget {
  const _TaskSchedulerPanel({required this.palette, required this.onRefresh});

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_TaskSchedulerPanel> createState() => _TaskSchedulerPanelState();
}

class _TaskSchedulerPanelState extends State<_TaskSchedulerPanel> {
  final _title = TextEditingController();
  final _due = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _due.dispose();
    super.dispose();
  }

  void _add() {
    if (_title.text.trim().isEmpty) return;
    pendingWorkItems.insert(0, {
      'id': _pendingWorkSeed++,
      'title': _title.text.trim(),
      'due': _due.text.trim(),
      'status': 'Scheduled',
      'at': DateTime.now().toIso8601String(),
    });
    _title.clear();
    _due.clear();
    widget.onRefresh();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _tmCard(
      palette: widget.palette,
      title: 'Scheduled store tasks',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Task',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _due,
            decoration: const InputDecoration(
              labelText: 'Due (text)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add_alarm),
            label: const Text('Schedule'),
          ),
          const Divider(height: 24),
          if (pendingWorkItems.isEmpty)
            const Text('No scheduled rows.')
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingWorkItems.length.clamp(0, 30),
              itemBuilder: (context, i) {
                final t = pendingWorkItems[i];
                return ListTile(
                  title: Text('${t['title']}'),
                  subtitle: Text('${t['due']} · ${t['status']}'),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ReportPrintPanel extends StatefulWidget {
  const _ReportPrintPanel({required this.palette});

  final _TopMenuPalette palette;

  @override
  State<_ReportPrintPanel> createState() => _ReportPrintPanelState();
}

class _ReportPrintPanelState extends State<_ReportPrintPanel> {
  String _type = 'Sales summary';

  @override
  Widget build(BuildContext context) {
    return _tmCard(
      palette: widget.palette,
      title: 'Report → clipboard (PDF-ready text)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Sales summary',
                child: Text('Sales summary'),
              ),
              DropdownMenuItem(
                value: 'Purchase summary',
                child: Text('Purchase summary'),
              ),
              DropdownMenuItem(
                value: 'Stock valuation',
                child: Text('Stock valuation'),
              ),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'Sales summary'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final b = StringBuffer('$_type\n');
              if (_type == 'Sales summary') {
                for (final r in salesInvoiceRecords.take(40)) {
                  b.writeln('${r['billNo']},${r['date']},${r['grandTotal']}');
                }
              } else if (_type == 'Purchase summary') {
                for (final r in purchaseBillRecords.take(40)) {
                  b.writeln('${r['billNo']},${r['date']},${r['grandTotal']}');
                }
              } else {
                for (final p in products.take(80)) {
                  b.writeln(
                    '${p['name'] ?? p['productName']},${p['stock']},${p['rate'] ?? ''}',
                  );
                }
              }
              await Clipboard.setData(ClipboardData(text: b.toString()));
              lastPrintJobSummary = '$_type ${DateTime.now()}';
              appendAppActivityLog('Report prepared: $_type');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report text copied to clipboard.')),
                );
              }
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Generate & copy'),
          ),
        ],
      ),
    );
  }
}

class _PrintSetupPanel extends StatefulWidget {
  const _PrintSetupPanel({required this.palette, required this.onRefresh});

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_PrintSetupPanel> createState() => _PrintSetupPanelState();
}

class _PrintSetupPanelState extends State<_PrintSetupPanel> {
  bool _a4 = true;
  bool _thermal = true;

  @override
  Widget build(BuildContext context) {
    return _tmCard(
      palette: widget.palette,
      title: 'Print layout',
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Enable A4 invoice layout'),
            value: _a4,
            onChanged: (v) => setState(() => _a4 = v),
          ),
          SwitchListTile(
            title: const Text('Enable thermal 3" layout'),
            value: _thermal,
            onChanged: (v) => setState(() => _thermal = v),
          ),
          FilledButton(
            onPressed: () {
              lastPrintJobSummary = 'Setup A4=$_a4 thermal=$_thermal';
              appendAppActivityLog('Print setup saved');
              widget.onRefresh();
            },
            child: const Text('Save setup'),
          ),
        ],
      ),
    );
  }
}

class _DefaultPrinterPanel extends StatefulWidget {
  const _DefaultPrinterPanel({required this.palette, required this.onRefresh});

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_DefaultPrinterPanel> createState() => _DefaultPrinterPanelState();
}

class _DefaultPrinterPanelState extends State<_DefaultPrinterPanel> {
  String _printer = 'System default';

  @override
  Widget build(BuildContext context) {
    return _tmCard(
      palette: widget.palette,
      title: 'Default output',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _printer,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'System default',
                child: Text('System default'),
              ),
              DropdownMenuItem(
                value: 'USB thermal',
                child: Text('USB thermal'),
              ),
              DropdownMenuItem(
                value: 'Network A4',
                child: Text('Network A4'),
              ),
            ],
            onChanged: (v) => setState(() => _printer = v ?? 'System default'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              lastPrintJobSummary = 'Default printer: $_printer';
              appendAppActivityLog('Default printer $_printer');
              widget.onRefresh();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _LabelPrintPanel extends StatefulWidget {
  const _LabelPrintPanel({required this.palette, required this.onRefresh});

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_LabelPrintPanel> createState() => _LabelPrintPanelState();
}

class _LabelPrintPanelState extends State<_LabelPrintPanel> {
  String? _pid;

  @override
  Widget build(BuildContext context) {
    final opts = products.take(60).toList();
    return _tmCard(
      palette: widget.palette,
      title: 'Shelf label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (opts.isEmpty)
            const Text('Add products first.')
          else
            DropdownButtonFormField<String>(
              value: _pid ?? '${opts.first['id']}',
              decoration: const InputDecoration(
                labelText: 'Product',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final p in opts)
                  DropdownMenuItem(
                    value: '${p['id']}',
                    child: Text(
                      '${p['name'] ?? p['productName'] ?? p['id']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _pid = v),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: opts.isEmpty
                ? null
                : () async {
                    final id = _pid ?? '${opts.first['id']}';
                    final p = opts.firstWhere(
                      (e) => '${e['id']}' == id,
                      orElse: () => opts.first,
                    );
                    final line =
                        '${p['name'] ?? ''} | MRP ${p['mrp'] ?? p['rate'] ?? ''} | Batch ______';
                    await Clipboard.setData(ClipboardData(text: line));
                    lastPrintJobSummary = 'Label $line';
                    appendAppActivityLog('Label copied');
                    widget.onRefresh();
                  },
            icon: const Icon(Icons.label),
            label: const Text('Build label → clipboard'),
          ),
        ],
      ),
    );
  }
}

class _BarcodePrintPanel extends StatefulWidget {
  const _BarcodePrintPanel({required this.palette, required this.onRefresh});

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_BarcodePrintPanel> createState() => _BarcodePrintPanelState();
}

class _BarcodePrintPanelState extends State<_BarcodePrintPanel> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _tmCard(
      palette: widget.palette,
      title: 'Barcode text (Code128 via external tool)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _code,
            decoration: const InputDecoration(
              labelText: 'SKU / barcode text',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final t = _code.text.trim();
              if (t.isEmpty) return;
              await Clipboard.setData(ClipboardData(text: 'BARCODE|$t|'));
              lastPrintJobSummary = 'Barcode $t';
              appendAppActivityLog('Barcode payload copied');
              widget.onRefresh();
            },
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Copy barcode job'),
          ),
        ],
      ),
    );
  }
}

class _ActiveWorkListPanel extends StatefulWidget {
  const _ActiveWorkListPanel({required this.palette, required this.onRefresh});

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_ActiveWorkListPanel> createState() => _ActiveWorkListPanelState();
}

class _ActiveWorkListPanelState extends State<_ActiveWorkListPanel> {
  final _line = TextEditingController();

  @override
  void dispose() {
    _line.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _tmCard(
      palette: widget.palette,
      title: 'Counter work queue',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _line,
            decoration: const InputDecoration(
              labelText: 'New work item',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () {
              if (_line.text.trim().isEmpty) return;
              pendingWorkItems.insert(0, {
                'id': _pendingWorkSeed++,
                'title': _line.text.trim(),
                'due': '',
                'status': 'Active',
                'at': DateTime.now().toIso8601String(),
              });
              _line.clear();
              widget.onRefresh();
              setState(() {});
            },
            icon: const Icon(Icons.add),
            label: const Text('Push to list'),
          ),
          const Divider(height: 20),
          if (pendingWorkItems.isEmpty)
            const Text('Queue empty.')
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingWorkItems.length.clamp(0, 40),
              itemBuilder: (context, i) {
                final w = pendingWorkItems[i];
                return ListTile(
                  title: Text('${w['title']}'),
                  subtitle: Text('${w['status']} · ${w['at']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.done),
                    onPressed: () {
                      setState(() => w['status'] = 'Done');
                      widget.onRefresh();
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PendingTasksPanel extends StatelessWidget {
  const _PendingTasksPanel({required this.palette, required this.onRefresh});

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final open = pendingWorkItems
        .where((e) => '${e['status']}' != 'Done')
        .toList();
    return _tmCard(
      palette: palette,
      title: 'Pending (${open.length})',
      child: open.isEmpty
          ? const Text('No pending tasks.')
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: open.length,
              itemBuilder: (context, i) {
                final t = open[i];
                return ListTile(
                  title: Text('${t['title']}'),
                  subtitle: Text('${t['due']}'),
                  trailing: TextButton(
                    onPressed: () {
                      t['status'] = 'Done';
                      onRefresh();
                    },
                    child: const Text('Complete'),
                  ),
                );
              },
            ),
    );
  }
}

class _CurrentSalesActivityPanel extends StatelessWidget {
  const _CurrentSalesActivityPanel({required this.palette});

  final _TopMenuPalette palette;

  @override
  Widget build(BuildContext context) {
    return _tmCard(
      palette: palette,
      title: 'Recent sales (live list)',
      child: salesInvoiceRecords.isEmpty
          ? const Text('No sales yet.')
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: salesInvoiceRecords.length.clamp(0, 50),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = salesInvoiceRecords[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.receipt_long, size: 20),
                  title: Text('${r['billNo']} · ${r['party']}'),
                  subtitle: Text('${r['date']}'),
                  trailing: Text(
                    '₹ ${_tmParseDouble(r['grandTotal']).toStringAsFixed(2)}',
                  ),
                );
              },
            ),
    );
  }
}

class _UserActivityLogPanel extends StatelessWidget {
  const _UserActivityLogPanel({required this.palette});

  final _TopMenuPalette palette;

  @override
  Widget build(BuildContext context) {
    return _tmCard(
      palette: palette,
      title: 'User log (login | action | time)',
      child: appActivityLog.isEmpty
          ? const Text('No activity yet — open modules to populate.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('User')),
                  DataColumn(label: Text('Action')),
                  DataColumn(label: Text('Time')),
                ],
                rows: [
                  for (final r in appActivityLog.take(80))
                    DataRow(
                      cells: [
                        DataCell(Text('${r['user']}')),
                        DataCell(Text('${r['action']}')),
                        DataCell(Text('${r['at']}')),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _InfoserverSyncPanel extends StatelessWidget {
  const _InfoserverSyncPanel({required this.palette, required this.onRefresh});

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _tmCard(
      palette: palette,
      title: 'Head-office sync (simulated)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lastInfoserverSyncAt == null
                ? 'Never synced.'
                : 'Last: ${lastInfoserverSyncAt!.toLocal()} — ${lastInfoserverSyncMessage ?? ''}',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              lastInfoserverSyncAt = DateTime.now();
              lastInfoserverSyncMessage =
                  'Pushed ${products.length} products, ${salesInvoiceRecords.length} sales';
              appendAppActivityLog('InfoServer sync');
              onRefresh();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync completed (demo).')),
              );
            },
            icon: const Icon(Icons.sync),
            label: const Text('Run sync now'),
          ),
        ],
      ),
    );
  }
}

class _InfoserverTransferPanel extends StatefulWidget {
  const _InfoserverTransferPanel({
    required this.palette,
    required this.onRefresh,
  });

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_InfoserverTransferPanel> createState() =>
      _InfoserverTransferPanelState();
}

class _InfoserverTransferPanelState extends State<_InfoserverTransferPanel> {
  final _payload = TextEditingController();

  @override
  void dispose() {
    _payload.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _tmCard(
      palette: widget.palette,
      title: 'Upload / download payload',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Paste server JSON response or local payload.'),
          TextField(
            controller: _payload,
            maxLines: 6,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.tonal(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: jsonEncode(_snapshotLite())),
                  );
                  appendAppActivityLog('Upload payload copied');
                  widget.onRefresh();
                },
                child: const Text('Prepare upload (copy)'),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () {
                  appendAppActivityLog('Download applied (demo)');
                  widget.onRefresh();
                },
                child: const Text('Apply download (demo)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _snapshotLite() {
    return {
      'products': products.length,
      'sales': salesInvoiceRecords.length,
      'at': DateTime.now().toIso8601String(),
    };
  }
}

class _InfoserverServerSettingsPanel extends StatefulWidget {
  const _InfoserverServerSettingsPanel({
    required this.palette,
    required this.onRefresh,
  });

  final _TopMenuPalette palette;
  final VoidCallback onRefresh;

  @override
  State<_InfoserverServerSettingsPanel> createState() =>
      _InfoserverServerSettingsPanelState();
}

class _InfoserverServerSettingsPanelState
    extends State<_InfoserverServerSettingsPanel> {
  final _url = TextEditingController(text: 'https://hq.example.invalid');
  final _key = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _tmCard(
      palette: widget.palette,
      title: 'Server endpoint',
      child: Column(
        children: [
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _key,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API key (stored in session only)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              appendAppActivityLog('InfoServer URL saved');
              widget.onRefresh();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _InfoserverAnalyticsPanel extends StatelessWidget {
  const _InfoserverAnalyticsPanel({required this.palette});

  final _TopMenuPalette palette;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().split('T').first;
    double todayS = 0;
    for (final r in salesInvoiceRecords) {
      if ('${r['date']}'.startsWith(today)) {
        todayS += _tmParseDouble(r['grandTotal']);
      }
    }
    double monthS = 0;
    final ym = today.substring(0, 7);
    for (final r in salesInvoiceRecords) {
      if ('${r['date']}'.startsWith(ym)) {
        monthS += _tmParseDouble(r['grandTotal']);
      }
    }
    final profitish = monthS * 0.12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                palette,
                'Today sales',
                '₹ ${todayS.toStringAsFixed(2)}',
                Icons.today,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                palette,
                'Month sales',
                '₹ ${monthS.toStringAsFixed(2)}',
                Icons.calendar_view_month,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                palette,
                'Est. margin',
                '₹ ${profitish.toStringAsFixed(2)}',
                Icons.trending_up,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Margin uses a flat 12% estimate on monthly sales until cost sheets are wired.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

Widget _statCard(
  _TopMenuPalette p,
  String title,
  String value,
  IconData icon,
) {
  return Card(
    elevation: 0,
    color: p.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: p.primary.withValues(alpha: 0.25)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: p.primary, size: 20),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 11)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

class _InfoserverNotificationsPanel extends StatelessWidget {
  const _InfoserverNotificationsPanel({required this.palette});

  final _TopMenuPalette palette;

  @override
  Widget build(BuildContext context) {
    final low = <String>[];
    for (final p in products) {
      final stock = _tmParseDouble(p['stock']);
      final reorder = _tmParseDouble(p['reorderQty'] ?? p['minStock']);
      if (reorder > 0 && stock <= reorder) {
        low.add('${p['name'] ?? p['productName']} (stock $stock)');
      }
    }
    final near = <String>[];
    for (final r in _collectBatchExpiryRows().take(200)) {
      final d = _tryParseExpiryDate('${r['expiry']}');
      if (d == null) continue;
      if (d.difference(DateTime.now()).inDays <= 45) {
        near.add('${r['productName']} exp ${r['expiry']}');
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tmCard(
          palette: palette,
          title: 'Low stock',
          child: low.isEmpty
              ? const Text('No low-stock alerts.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final l in low.take(20)) Text('• $l')],
                ),
        ),
        const SizedBox(height: 12),
        _tmCard(
          palette: palette,
          title: 'Near expiry (from invoice lines)',
          child: near.isEmpty
              ? const Text('No near-expiry batches found.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final l in near.take(25)) Text('• $l')],
                ),
        ),
      ],
    );
  }
}

class _SchemeDiscountReportPanel extends StatelessWidget {
  const _SchemeDiscountReportPanel({required this.palette});

  final _TopMenuPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tmCard(
          palette: palette,
          title: 'Discount rules (${discountRules.length})',
          child: discountRules.isEmpty
              ? const Text('No discount rules.')
              : Text(discountRules.map((e) => '${e['scope']}:${e['target']}').join('\n')),
        ),
        const SizedBox(height: 12),
        _tmCard(
          palette: palette,
          title: 'Schemes (${schemeOffers.length})',
          child: schemeOffers.isEmpty
              ? const Text('No schemes.')
              : Text(
                  schemeOffers
                      .map((e) => '${e['label']} (${e['active'] == true ? 'ON' : 'OFF'})')
                      .join('\n'),
                ),
        ),
      ],
    );
  }
}

class _DoctorSalesAnalysisPanel extends StatelessWidget {
  const _DoctorSalesAnalysisPanel({required this.palette});

  final _TopMenuPalette palette;

  @override
  Widget build(BuildContext context) {
    final map = <String, double>{};
    for (final inv in salesInvoiceRecords) {
      final d = (inv['doctor'] ?? '').toString().trim();
      if (d.isEmpty) continue;
      map[d] = (map[d] ?? 0) + _tmParseDouble(inv['grandTotal']);
    }
    final keys = map.keys.toList()..sort((a, b) => map[b]!.compareTo(map[a]!));
    return _tmCard(
      palette: palette,
      title: 'Sales by doctor',
      child: keys.isEmpty
          ? const Text('No doctor tagged on invoices.')
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: keys.length.clamp(0, 40),
              itemBuilder: (context, i) {
                final k = keys[i];
                return ListTile(
                  title: Text(k),
                  trailing: Text('₹ ${map[k]!.toStringAsFixed(2)}'),
                );
              },
            ),
    );
  }
}

class _PartySalesAnalysisPanel extends StatelessWidget {
  const _PartySalesAnalysisPanel({required this.palette});

  final _TopMenuPalette palette;

  @override
  Widget build(BuildContext context) {
    final map = <String, double>{};
    for (final inv in salesInvoiceRecords) {
      final d = (inv['party'] ?? '').toString().trim();
      if (d.isEmpty) continue;
      map[d] = (map[d] ?? 0) + _tmParseDouble(inv['grandTotal']);
    }
    final keys = map.keys.toList()..sort((a, b) => map[b]!.compareTo(map[a]!));
    return _tmCard(
      palette: palette,
      title: 'Sales by party',
      child: keys.isEmpty
          ? const Text('No party on invoices.')
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: keys.length.clamp(0, 40),
              itemBuilder: (context, i) {
                final k = keys[i];
                return ListTile(
                  title: Text(k),
                  trailing: Text('₹ ${map[k]!.toStringAsFixed(2)}'),
                );
              },
            ),
    );
  }
}

class _PatientSalesAnalysisPanel extends StatelessWidget {
  const _PatientSalesAnalysisPanel({required this.palette});

  final _TopMenuPalette palette;

  @override
  Widget build(BuildContext context) {
    final map = <String, double>{};
    for (final inv in salesInvoiceRecords) {
      final d = (inv['patient'] ?? '').toString().trim();
      if (d.isEmpty) continue;
      map[d] = (map[d] ?? 0) + _tmParseDouble(inv['grandTotal']);
    }
    final keys = map.keys.toList()..sort((a, b) => map[b]!.compareTo(map[a]!));
    return _tmCard(
      palette: palette,
      title: 'Sales by patient',
      child: keys.isEmpty
          ? const Text('No patient on invoices.')
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: keys.length.clamp(0, 40),
              itemBuilder: (context, i) {
                final k = keys[i];
                return ListTile(
                  title: Text(k),
                  trailing: Text('₹ ${map[k]!.toStringAsFixed(2)}'),
                );
              },
            ),
    );
  }
}

class _AccountReceivablePanel extends StatelessWidget {
  const _AccountReceivablePanel({required this.palette});

  final _TopMenuPalette palette;

  @override
  Widget build(BuildContext context) {
    final map = <String, double>{};
    for (final inv in salesInvoiceRecords) {
      final party = (inv['party'] ?? '').toString().trim();
      if (party.isEmpty) continue;
      map[party] = (map[party] ?? 0) + _tmParseDouble(inv['grandTotal']);
    }
    final keys = map.keys.toList()..sort((a, b) => map[b]!.compareTo(map[a]!));
    return _tmCard(
      palette: palette,
      title: 'Outstanding by party (sales total as AR proxy)',
      child: keys.isEmpty
          ? const Text('No receivable data — record sales with party name.')
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: keys.length.clamp(0, 60),
              itemBuilder: (context, i) {
                final k = keys[i];
                return ListTile(
                  title: Text(k),
                  trailing: Text('₹ ${map[k]!.toStringAsFixed(2)}'),
                );
              },
            ),
    );
  }
}

class _AccountPayablePanel extends StatelessWidget {
  const _AccountPayablePanel({required this.palette});

  final _TopMenuPalette palette;

  @override
  Widget build(BuildContext context) {
    final map = <String, double>{};
    for (final inv in purchaseBillRecords) {
      final party = (inv['party'] ?? '').toString().trim();
      if (party.isEmpty) continue;
      map[party] = (map[party] ?? 0) + _tmParseDouble(inv['grandTotal']);
    }
    final keys = map.keys.toList()..sort((a, b) => map[b]!.compareTo(map[a]!));
    return _tmCard(
      palette: palette,
      title: 'Payables by supplier (purchase total as AP proxy)',
      child: keys.isEmpty
          ? const Text('No payable data — record purchases with party name.')
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: keys.length.clamp(0, 60),
              itemBuilder: (context, i) {
                final k = keys[i];
                return ListTile(
                  title: Text(k),
                  trailing: Text('₹ ${map[k]!.toStringAsFixed(2)}'),
                );
              },
            ),
    );
  }
}

class _DynamicOperationsDeck extends StatelessWidget {
  const _DynamicOperationsDeck({
    required this.group,
    required this.item,
    required this.palette,
    required this.onNavigate,
    required this.onRefresh,
  });

  final String group;
  final String item;
  final _TopMenuPalette palette;
  final void Function(String screen, {String? placeholderTitle}) onNavigate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final h = item.hashCode.abs() % 4;
    if (h == 0) {
      return _tmCard(
        palette: palette,
        title: '$item — register strip',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Shortcut: jump to a master screen when data is needed.'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => onNavigate('product'),
                  child: const Text('Product Master'),
                ),
                OutlinedButton(
                  onPressed: () => onNavigate('sales-invoice'),
                  child: const Text('Sales Invoice'),
                ),
                OutlinedButton(
                  onPressed: () => onNavigate('purchase-bill'),
                  child: const Text('Purchase Bill'),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Live counts: ${products.length} products · '
              '${salesInvoiceRecords.length} sales · '
              '${purchaseBillRecords.length} purchases',
            ),
          ],
        ),
      );
    }
    if (h == 1) {
      return _tmCard(
        palette: palette,
        title: '$item — timeline',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in salesInvoiceRecords.take(6))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${r['date']} · ${r['billNo']} · ${r['party']}'),
                    ),
                    Text('₹ ${_tmParseDouble(r['grandTotal']).toStringAsFixed(0)}'),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    if (h == 2) {
      return _tmCard(
        palette: palette,
        title: '$item — two-column desk',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Accounts snapshot', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('${accounts.length} ledgers'),
                ],
              ),
            ),
            const VerticalDivider(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Doctors', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('${doctors.length} records'),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return _tmCard(
      palette: palette,
      title: '$item — KPI tiles',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _miniTile('Products', '${products.length}'),
          _miniTile('Sales bills', '${salesInvoiceRecords.length}'),
          _miniTile('Schemes', '${schemeOffers.length}'),
          _miniTile('Discount rules', '${discountRules.length}'),
        ],
      ),
    );
  }
}

Widget _miniTile(String k, String v) {
  return Container(
    width: 140,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 11)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ],
    ),
  );
}
