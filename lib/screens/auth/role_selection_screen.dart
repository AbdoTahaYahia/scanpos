import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_styles.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/rounded_card.dart';
import '../../widgets/pill_input.dart';
import 'enter_invite_code_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppStyles.paddingScreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppStyles.gap32,

              Text('Welcome!', style: AppTheme.display),
              AppStyles.gap8,
              Text(
                'How would you like to use ScanPos?',
                style: AppTheme.bodyLg.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
              ),

              AppStyles.gap48,

              // Manager Option
              RoundedCard(
                onTap: () => _showManagerDialog(context),
                padding: const EdgeInsets.all(28),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppTheme.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.store_rounded,
                        color: AppTheme.white,
                        size: 32,
                      ),
                    ),
                    AppStyles.gapW16,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "I'm a Manager",
                            style: AppTheme.headlineMd,
                          ),
                          AppStyles.gap4,
                          Text(
                            'Create a new store',
                            style: AppTheme.bodySm.copyWith(
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppTheme.black,
                      size: 20,
                    ),
                  ],
                ),
              ),

              AppStyles.gap16,

              // Employee Option
              RoundedCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EnterInviteCodeScreen(),
                  ),
                ),
                padding: const EdgeInsets.all(28),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.black,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.badge_rounded,
                        color: AppTheme.black,
                        size: 32,
                      ),
                    ),
                    AppStyles.gapW16,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "I'm an Employee",
                            style: AppTheme.headlineMd,
                          ),
                          AppStyles.gap4,
                          Text(
                            'Join an existing store',
                            style: AppTheme.bodySm.copyWith(
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppTheme.black,
                      size: 20,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Sign out option
              Center(
                child: PillButton(
                  label: 'Sign out',
                  variant: PillButtonVariant.ghost,
                  onPressed: () =>
                      context.read<AuthProvider>().signOut(),
                ),
              ),

              AppStyles.gap16,
            ],
          ),
        ),
      ),
    );
  }

  void _showManagerDialog(BuildContext context) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create Your Store', style: AppTheme.headlineMd),
                AppStyles.gap8,
                Text(
                  'Enter your store name to get started.',
                  style: AppTheme.bodySm.copyWith(
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                AppStyles.gap24,
                PillInput(
                  hint: 'Store name',
                  controller: controller,
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a store name';
                    }
                    return null;
                  },
                ),
                AppStyles.gap24,
                SizedBox(
                  width: double.infinity,
                  child: PillButton(
                    label: 'Create Store',
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.of(ctx).pop();
                        context
                            .read<AuthProvider>()
                            .registerAsManager(controller.text.trim());
                      }
                    },
                  ),
                ),
                AppStyles.gap12,
                SizedBox(
                  width: double.infinity,
                  child: PillButton(
                    label: 'Cancel',
                    variant: PillButtonVariant.secondary,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
