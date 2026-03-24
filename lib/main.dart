import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health+',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF6F2C2),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isMenuHovered = false;
  bool isDropdownHovered = false;
  String? activeMenu;
  late Timer closeTimer;
  final Map<String, double> _menuPositions = {};

  @override
  void initState() {
    super.initState();
    closeTimer = Timer(Duration.zero, () {});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              const TitleBar(),
              MenuBar(
                activeMenu: activeMenu,
                onMenuHoverEnter: _onMenuHoverEnter,
                onMenuHoverExit: _onMenuHoverExit,
                onMenuPositionChanged: _onMenuPositionChanged,
              ),
              const ShortcutBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Row(
                          children: [
                            Expanded(flex: 1, child: Container()),
                            Expanded(
                              flex: 2,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 200,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Health+',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(flex: 1, child: Container()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const StatusBar(),
            ],
          ),
          // Dropdown overlay
          if (activeMenu != null && _menuPositions.containsKey(activeMenu))
            Positioned(
              top: 30 + 28, // TitleBar height + MenuBar height
              left: _menuPositions[activeMenu]!,
              child: _buildDropdownMenu(activeMenu!),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownMenu(String menuName) {
    switch (menuName) {
      case 'Master':
        return MasterDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
        );
      case 'Invoice':
        return InvoiceDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
        );
      case 'Account':
        return AccountDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
        );
      case 'Special':
        return SpecialDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
        );
      case 'Periodical':
        return PeriodicalDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
        );
      case 'Utility':
        return UtilityDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
        );
      case 'Printers':
        return PrintersDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
        );
      case 'ActiveWork':
        return ActiveWorkDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
        );
      case 'Infoserver':
        return InfoserverDropdownMenu(
          onHoverEnter: _onDropdownHoverEnter,
          onHoverExit: _onDropdownHoverExit,
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
      color: Colors.grey[300],
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: const Text(
        'Health+ MEDICAL STORE (2025-26) - Home',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
      color: Colors.grey[220],
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[400]!, width: 1)),
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
        onPositionChanged: (position) => widget.onMenuPositionChanged(text, position),
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

  const MasterDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
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
            width: 240,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[350]!, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
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
            color: Colors.black.withOpacity(0.15),
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
      onEnter: (_) => setState(() => hoveredIndex = -1), // Special index for submenu
      onExit: (_) => setState(() => hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          print('Clicked submenu: $label');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: hoveredIndex == -1 ? Colors.grey[100] : Colors.transparent,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black,
            ),
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
          // Menu item clicked - can add navigation logic here
          print('Clicked: $label');
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
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  if (hasSubmenu)
                    const Icon(
                      Icons.arrow_right,
                      size: 14,
                      color: Colors.grey,
                    ),
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
      child: Container(
        height: 1,
        color: Colors.grey[250],
      ),
    );
  }
}

class InvoiceDropdownMenu extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;

  const InvoiceDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
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
                  color: Colors.black.withOpacity(0.15),
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
                _buildMenuItemRow(4, 'Other Inputs/RCM', ''),
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
        submenuItems = ['New Order', 'Order List', 'Pending Orders', 'Order History'];
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
            color: Colors.black.withOpacity(0.15),
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
      onEnter: (_) => setState(() => hoveredIndex = -1), // Special index for submenu
      onExit: (_) => setState(() => hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          print('Clicked submenu: $label');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: hoveredIndex == -1 ? const Color(0xFFF2F2F2) : Colors.transparent,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black,
            ),
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
          print('Clicked: $label');
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
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
      child: Container(
        height: 1,
        color: Colors.grey[250],
      ),
    );
  }
}

class AccountDropdownMenu extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;

  const AccountDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
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
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMenuItemRow(0, 'Receipt >', ''),
                _buildMenuItemRow(1, 'Payment >', ''),
                _divider(),
                _buildMenuItemRow(2, 'Journal Voucher', ''),
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
        submenuItems = ['Daily Register', 'Monthly Register', 'Yearly Register'];
        break;
      case 'Bank Reconciliation >':
        submenuItems = ['Bank Statement', 'Reconcile Transactions', 'Bank Balance'];
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
            color: Colors.black.withOpacity(0.15),
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
      onEnter: (_) => setState(() => hoveredIndex = -1), // Special index for submenu
      onExit: (_) => setState(() => hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          print('Clicked submenu: $label');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: hoveredIndex == -1 ? const Color(0xFFF2F2F2) : Colors.transparent,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black,
            ),
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
          print('Clicked: $label');
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
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  if (hasSubmenu)
                    const Icon(
                      Icons.arrow_right,
                      size: 14,
                      color: Colors.grey,
                    ),
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
      child: Container(
        height: 1,
        color: Colors.grey[250],
      ),
    );
  }
}

class SpecialDropdownMenu extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;

  const SpecialDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
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
              color: Colors.black.withOpacity(0.15),
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
          print('Clicked: $label');
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
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
      child: Container(
        height: 1,
        color: Colors.grey[250],
      ),
    );
  }
}

class PeriodicalDropdownMenu extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;

  const PeriodicalDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
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
              color: Colors.black.withOpacity(0.15),
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
          print('Clicked: $label');
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
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
      child: Container(
        height: 1,
        color: Colors.grey[250],
      ),
    );
  }
}

class UtilityDropdownMenu extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;

  const UtilityDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
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
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[350]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
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
          print('Clicked: $label');
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
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
      child: Container(
        height: 1,
        color: Colors.grey[250],
      ),
    );
  }
}

class PrintersDropdownMenu extends StatefulWidget {
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;

  const PrintersDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
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
              color: Colors.black.withOpacity(0.15),
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
          print('Clicked: $label');
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
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

  const ActiveWorkDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
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
              color: Colors.black.withOpacity(0.15),
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
          print('Clicked: $label');
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
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

  const InfoserverDropdownMenu({
    super.key,
    required this.onHoverEnter,
    required this.onHoverExit,
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
              color: Colors.black.withOpacity(0.15),
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
          print('Clicked: $label');
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
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
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMenuItemRow(0, 'Exit Application', ''),
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
          print('Clicked: $label');
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
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
    final RenderBox? renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
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
        color: widget.isActive ? Colors.grey[300] : Colors.transparent,
        child: InkWell(
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Align(
              alignment: Alignment.center,
              child: Text(
                widget.text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
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
  const ShortcutBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 0.5),
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
        child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
          border: Border(right: BorderSide(color: Colors.black, width: 1), bottom: BorderSide(color: Colors.black, width: 1)),
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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
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

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      color: Colors.grey[400],
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: const Text(
        'Status: Ready',
        style: TextStyle(fontSize: 10),
      ),
    );
  }
}
