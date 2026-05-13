import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/store_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_styles.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/rounded_card.dart';
import '../sales/sales_history_screen.dart';
import '../sales/cashier_transactions_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.appUser;
    final store = authProvider.store;

    if (user == null) return const SizedBox.shrink();

    return Drawer(
      backgroundColor: AppTheme.white,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: AppStyles.paddingScreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  AppStyles.gapW8,
                  Text('Profile', style: AppTheme.headlineLg),
                ],
              ),

              AppStyles.gap24,

              // User card
              RoundedCard(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppTheme.black,
                      backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                      child: user.photoUrl == null
                          ? Text(user.displayName[0].toUpperCase(), style: const TextStyle(color: AppTheme.white, fontSize: 24, fontWeight: FontWeight.w700))
                          : null,
                    ),
                    AppStyles.gapW16,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.displayName, style: AppTheme.headlineMd),
                          AppStyles.gap4,
                          Text(user.email, style: AppTheme.bodySm.copyWith(color: AppTheme.onSurfaceVariant)),
                          AppStyles.gap8,
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.black,
                              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: Text(
                              user.rolesDisplay,
                              style: AppTheme.labelBold.copyWith(color: AppTheme.white, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              AppStyles.gap24,

              // Store info (Manager only)
              if (user.isManager && store != null) ...[
                Text('STORE', style: AppTheme.labelBold.copyWith(color: AppTheme.onSurfaceVariant)),
                AppStyles.gap12,
                RoundedCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.name, style: AppTheme.headlineMd),
                      AppStyles.gap16,
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('INVITE CODE', style: AppTheme.labelBold.copyWith(color: AppTheme.onSurfaceVariant)),
                              AppStyles.gap4,
                              Text(store.inviteCode, style: AppTheme.headlineMd.copyWith(letterSpacing: 4)),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: store.inviteCode));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied!')));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded),
                            onPressed: () async {
                              final storeService = StoreService();
                              await storeService.regenerateInviteCode(store.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code regenerated!')));
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AppStyles.gap24,
              ],

              // Sales History (Manager only)
              if (user.isManager) ...[
                SizedBox(
                  width: double.infinity,
                  child: PillButton(
                    label: 'Sales History',
                    icon: Icons.receipt_long_rounded,
                    variant: PillButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
                    ),
                  ),
                ),
                AppStyles.gap16,
              ],

              // My Transactions (Cashier — edit invoices)
              if (user.isCashier) ...[
                SizedBox(
                  width: double.infinity,
                  child: PillButton(
                    label: 'My Transactions',
                    icon: Icons.edit_note_rounded,
                    variant: PillButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CashierTransactionsScreen()),
                    ),
                  ),
                ),
                AppStyles.gap16,
              ],

              // Team Management (Manager only)
              if (user.isManager) ...[
                AppStyles.gap8,
                Text('TEAM', style: AppTheme.labelBold.copyWith(color: AppTheme.onSurfaceVariant)),
                AppStyles.gap12,
                _TeamSection(storeId: store!.id),
                AppStyles.gap24,
              ],

              // Sign Out
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: 'Sign Out',
                  icon: Icons.logout_rounded,
                  variant: PillButtonVariant.secondary,
                  onPressed: () {
                    authProvider.signOut();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ),
              AppStyles.gap32,
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamSection extends StatelessWidget {
  final String storeId;
  const _TeamSection({required this.storeId});

  @override
  Widget build(BuildContext context) {
    final storeService = StoreService();

    return StreamBuilder<List<AppUser>>(
      stream: storeService.getStoreEmployees(storeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.black));
        }

        final employees = (snapshot.data ?? []).where((u) => !u.isManager).toList();

        if (employees.isEmpty) {
          return RoundedCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('No employees yet. Share your invite code!',
                  style: AppTheme.bodySm.copyWith(color: AppTheme.onSurfaceVariant)),
            ),
          );
        }

        return Column(
          children: employees.map((employee) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _EmployeeCard(employee: employee, storeService: storeService),
          )).toList(),
        );
      },
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final AppUser employee;
  final StoreService storeService;

  const _EmployeeCard({required this.employee, required this.storeService});

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.surfaceContainer,
                backgroundImage: employee.photoUrl != null ? NetworkImage(employee.photoUrl!) : null,
                child: employee.photoUrl == null
                    ? Text(employee.displayName[0].toUpperCase(), style: const TextStyle(color: AppTheme.black, fontWeight: FontWeight.w700))
                    : null,
              ),
              AppStyles.gapW12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.displayName, style: AppTheme.bodyLg.copyWith(fontWeight: FontWeight.w600)),
                    AppStyles.gap4,
                    Text(
                      employee.isPending ? 'Pending approval' : employee.rolesDisplay,
                      style: AppTheme.labelBold.copyWith(
                        color: employee.isPending ? AppTheme.error : AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              if (!employee.isPending)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppTheme.black),
                  onSelected: (value) {
                    if (value == 'edit_roles') {
                      _showRoleDialog(context);
                    } else if (value == 'remove') {
                      _confirmRemove(context);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit_roles', child: Text('Edit Roles')),
                    const PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: AppTheme.error))),
                  ],
                ),
            ],
          ),

          // Pending employees — show role toggle chips
          if (employee.isPending) ...[
            AppStyles.gap12,
            _RoleToggleRow(
              employee: employee,
              storeService: storeService,
              isPendingApproval: true,
            ),
          ],
        ],
      ),
    );
  }

  void _showRoleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _RoleEditDialog(
        employee: employee,
        storeService: storeService,
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Remove Employee?', style: AppTheme.headlineMd),
            AppStyles.gap8,
            Text('${employee.displayName} will be removed from the store.',
                style: AppTheme.bodySm.copyWith(color: AppTheme.onSurfaceVariant), textAlign: TextAlign.center),
            AppStyles.gap24,
            SizedBox(width: double.infinity, child: PillButton(label: 'Remove', onPressed: () { Navigator.pop(ctx); storeService.removeEmployee(employee.uid); })),
            AppStyles.gap12,
            SizedBox(width: double.infinity, child: PillButton(label: 'Cancel', variant: PillButtonVariant.secondary, onPressed: () => Navigator.pop(ctx))),
          ]),
        ),
      ),
    );
  }
}

/// Row of toggle-able role chips for assigning cashier/warehouse roles
class _RoleToggleRow extends StatefulWidget {
  final AppUser employee;
  final StoreService storeService;
  final bool isPendingApproval;

  const _RoleToggleRow({
    required this.employee,
    required this.storeService,
    this.isPendingApproval = false,
  });

  @override
  State<_RoleToggleRow> createState() => _RoleToggleRowState();
}

class _RoleToggleRowState extends State<_RoleToggleRow> {
  late Set<String> _selectedRoles;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedRoles = widget.employee.roles.toSet();
  }

  void _toggle(String role) {
    setState(() {
      if (_selectedRoles.contains(role)) {
        _selectedRoles.remove(role);
      } else {
        _selectedRoles.add(role);
      }
    });
  }

  Future<void> _save() async {
    if (_selectedRoles.isEmpty) return;
    setState(() => _saving = true);
    await widget.storeService.updateEmployeeRoles(
      widget.employee.uid,
      _selectedRoles.toList(),
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoleChip(
          label: 'Cashier',
          icon: Icons.point_of_sale_rounded,
          isSelected: _selectedRoles.contains('cashier'),
          onTap: () => _toggle('cashier'),
        ),
        AppStyles.gapW8,
        _RoleChip(
          label: 'Warehouse',
          icon: Icons.warehouse_rounded,
          isSelected: _selectedRoles.contains('warehouse'),
          onTap: () => _toggle('warehouse'),
        ),
        const Spacer(),
        if (_saving)
          const SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(color: AppTheme.black, strokeWidth: 2),
          )
        else
          GestureDetector(
            onTap: _selectedRoles.isEmpty ? null : _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedRoles.isEmpty ? AppTheme.surfaceContainer : AppTheme.black,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(
                widget.isPendingApproval ? 'Approve' : 'Save',
                style: AppTheme.labelBold.copyWith(
                  color: _selectedRoles.isEmpty ? AppTheme.outline : AppTheme.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Selectable role chip with icon
class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.black : AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isSelected ? AppTheme.black : AppTheme.outlineVariant,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppTheme.white : AppTheme.black),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTheme.labelBold.copyWith(
                color: isSelected ? AppTheme.white : AppTheme.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for editing roles of an existing employee
class _RoleEditDialog extends StatefulWidget {
  final AppUser employee;
  final StoreService storeService;

  const _RoleEditDialog({required this.employee, required this.storeService});

  @override
  State<_RoleEditDialog> createState() => _RoleEditDialogState();
}

class _RoleEditDialogState extends State<_RoleEditDialog> {
  late bool _cashier;
  late bool _warehouse;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cashier = widget.employee.roles.contains('cashier');
    _warehouse = widget.employee.roles.contains('warehouse');
  }

  Future<void> _save() async {
    final roles = <String>[];
    if (_cashier) roles.add('cashier');
    if (_warehouse) roles.add('warehouse');

    if (roles.isEmpty) return; // Must have at least one role

    setState(() => _saving = true);
    await widget.storeService.updateEmployeeRoles(widget.employee.uid, roles);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasRole = _cashier || _warehouse;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Edit Roles', style: AppTheme.headlineMd),
            AppStyles.gap4,
            Text(
              widget.employee.displayName,
              style: AppTheme.bodySm.copyWith(color: AppTheme.onSurfaceVariant),
            ),
            AppStyles.gap24,

            // Cashier toggle
            _RoleToggleTile(
              icon: Icons.point_of_sale_rounded,
              label: 'Cashier',
              description: 'Can scan products and process sales',
              value: _cashier,
              onChanged: (v) => setState(() => _cashier = v),
            ),
            AppStyles.gap12,

            // Warehouse toggle
            _RoleToggleTile(
              icon: Icons.warehouse_rounded,
              label: 'Warehouse',
              description: 'Can manage inventory and products',
              value: _warehouse,
              onChanged: (v) => setState(() => _warehouse = v),
            ),

            AppStyles.gap24,
            SizedBox(
              width: double.infinity,
              child: PillButton(
                label: _saving ? 'Saving...' : 'Save Roles',
                onPressed: (!hasRole || _saving) ? null : _save,
                isLoading: _saving,
              ),
            ),
            AppStyles.gap12,
            SizedBox(
              width: double.infinity,
              child: PillButton(
                label: 'Cancel',
                variant: PillButtonVariant.secondary,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A toggle tile for role selection in the dialog
class _RoleToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RoleToggleTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value ? AppTheme.black : AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: value ? AppTheme.black : AppTheme.outlineVariant,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: value ? AppTheme.white : AppTheme.black, size: 24),
            AppStyles.gapW12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTheme.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                    color: value ? AppTheme.white : AppTheme.black,
                  )),
                  Text(description, style: AppTheme.bodySm.copyWith(
                    color: value ? AppTheme.white.withValues(alpha: 0.7) : AppTheme.onSurfaceVariant,
                    fontSize: 11,
                  )),
                ],
              ),
            ),
            Icon(
              value ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: value ? AppTheme.white : AppTheme.outline,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

