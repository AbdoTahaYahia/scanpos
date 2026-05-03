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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.appUser;
    final store = authProvider.store;

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppStyles.paddingScreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
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
                              user.role.toUpperCase(),
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
      child: Row(
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
                Text(employee.isPending ? 'Pending approval' : employee.role.toUpperCase(),
                    style: AppTheme.labelBold.copyWith(
                      color: employee.isPending ? AppTheme.error : AppTheme.onSurfaceVariant,
                    )),
              ],
            ),
          ),

          if (employee.isPending) ...[
            // Assign role buttons for pending employees
            _RoleButton(label: 'Cashier', onTap: () => storeService.updateEmployeeRole(employee.uid, 'cashier')),
            AppStyles.gapW8,
            _RoleButton(label: 'Warehouse', filled: true, onTap: () => storeService.updateEmployeeRole(employee.uid, 'warehouse')),
          ] else ...[
            // Toggle role
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.black),
              onSelected: (value) {
                if (value == 'toggle') {
                  final newRole = employee.isCashier ? 'warehouse' : 'cashier';
                  storeService.updateEmployeeRole(employee.uid, newRole);
                } else if (value == 'remove') {
                  _confirmRemove(context);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'toggle', child: Text('Switch to ${employee.isCashier ? "Warehouse" : "Cashier"}')),
                const PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: AppTheme.error))),
              ],
            ),
          ],
        ],
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

class _RoleButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _RoleButton({required this.label, this.filled = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? AppTheme.black : AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(color: AppTheme.black, width: 2),
        ),
        child: Text(label, style: AppTheme.labelBold.copyWith(color: filled ? AppTheme.white : AppTheme.black)),
      ),
    );
  }
}
