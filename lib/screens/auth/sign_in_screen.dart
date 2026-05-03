import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_styles.dart';
import '../../widgets/pill_button.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppStyles.paddingScreen,
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo / Brand
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.black,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.black, width: 3),
                ),
                child: const Center(
                  child: Text(
                    'S',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2,
                    ),
                  ),
                ),
              ),

              AppStyles.gap32,

              // App Name
              Text(
                'ScanPos',
                style: AppTheme.display,
              ),

              AppStyles.gap12,

              // Tagline
              Text(
                'Supermarket POS & Inventory',
                style: AppTheme.bodyLg.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              // Error message
              if (authProvider.error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.error, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error),
                      AppStyles.gapW12,
                      Expanded(
                        child: Text(
                          authProvider.error!,
                          style: AppTheme.bodySm.copyWith(
                            color: AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AppStyles.gap24,
              ],

              // Sign In Button
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: 'Sign in with Google',
                  icon: Icons.login_rounded,
                  onPressed: authProvider.isLoading
                      ? null
                      : () => authProvider.signInWithGoogle(),
                  isLoading: authProvider.isLoading,
                  height: 64,
                ),
              ),

              AppStyles.gap16,

              // Footer text
              Text(
                'Scan. Sell. Manage.',
                style: AppTheme.labelBold.copyWith(
                  color: AppTheme.outline,
                  letterSpacing: 3,
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
