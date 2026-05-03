import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_styles.dart';
import '../../widgets/pill_button.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

/// Shown to employees who joined a store but haven't been assigned a role yet.
class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppStyles.paddingScreen,
          child: Column(
            children: [
              const Spacer(),

              // Waiting animation
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.black, width: 3),
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: AppTheme.black,
                  size: 56,
                ),
              ),

              AppStyles.gap32,

              Text(
                'Waiting for Approval',
                style: AppTheme.headlineLg,
                textAlign: TextAlign.center,
              ),

              AppStyles.gap12,

              Text(
                'Your manager needs to assign you a role before you can start using ScanPos.',
                style: AppTheme.bodyLg.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              AppStyles.gap16,

              Text(
                'This page will update automatically.',
                style: AppTheme.bodySm.copyWith(
                  color: AppTheme.outline,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 2),

              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: 'Sign Out',
                  variant: PillButtonVariant.secondary,
                  onPressed: () => context.read<AuthProvider>().signOut(),
                ),
              ),

              AppStyles.gap24,
            ],
          ),
        ),
      ),
    );
  }
}
