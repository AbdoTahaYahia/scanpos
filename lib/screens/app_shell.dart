import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../theme/app_theme.dart';
import 'scanner/scanner_screen.dart';
import 'inventory/inventory_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthProvider>().appUser;
    final canManage = user?.canManageInventory ?? false;
    if (!canManage && _currentIndex >= 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _currentIndex = 0);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Fetch initial products
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.appUser?.storeId != null) {
        context
            .read<InventoryProvider>()
            .fetchInitialPage(authProvider.appUser!.storeId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().appUser;
    final canManageInventory = user?.canManageInventory ?? false;

    final screens = <Widget>[
      ScannerScreen(isActive: _currentIndex == 0),
      if (canManageInventory) const InventoryScreen(),
      if (canManageInventory) const ReportsScreen(),
    ];

    final safeIndex = _currentIndex >= screens.length ? 0 : _currentIndex;

    return Scaffold(
      drawer: const SettingsScreen(),
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.white,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Scanner Tab
                _NavItem(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scanner',
                  isSelected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),

                // Inventory Tab (only for manager/warehouse)
                if (canManageInventory)
                  _NavItem(
                    icon: Icons.inventory_2_rounded,
                    label: 'Inventory',
                    isSelected: _currentIndex == 1,
                    onTap: () => setState(() => _currentIndex = 1),
                  ),

                // Reports Tab (only for manager/warehouse)
                if (canManageInventory)
                  _NavItem(
                    icon: Icons.assessment_rounded,
                    label: 'Reports',
                    isSelected: _currentIndex == 2,
                    onTap: () => setState(() => _currentIndex = 2),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.black : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Icon(
          icon,
          color: isSelected ? AppTheme.white : AppTheme.outline,
          size: 26,
        ),
      ),
    );
  }
}

