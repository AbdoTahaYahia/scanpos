import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_styles.dart';
import '../../widgets/pill_button.dart';

class InviteCodeDisplayScreen extends StatelessWidget {
  final String inviteCode;
  final VoidCallback? onDone;

  const InviteCodeDisplayScreen({
    super.key,
    required this.inviteCode,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppStyles.paddingScreen,
          child: Column(
            children: [
              const Spacer(),

              // Success icon
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: AppTheme.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppTheme.white,
                  size: 56,
                ),
              ),

              AppStyles.gap32,

              Text(
                'Store Created!',
                style: AppTheme.headlineLg,
                textAlign: TextAlign.center,
              ),

              AppStyles.gap12,

              Text(
                'Share this invite code with your employees so they can join your store.',
                style: AppTheme.bodyLg.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              AppStyles.gap48,

              // Invite code display
              GestureDetector(
                onTap: () => _copyCode(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                      color: AppTheme.black,
                      width: 3,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        inviteCode,
                        style: AppTheme.display.copyWith(
                          letterSpacing: 8,
                        ),
                      ),
                      AppStyles.gapW16,
                      const Icon(
                        Icons.copy_rounded,
                        color: AppTheme.black,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),

              AppStyles.gap16,

              Text(
                'Tap to copy',
                style: AppTheme.labelBold.copyWith(
                  color: AppTheme.outline,
                ),
              ),

              const Spacer(flex: 2),

              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: 'Get Started',
                  onPressed: onDone,
                  height: 64,
                ),
              ),

              AppStyles.gap24,
            ],
          ),
        ),
      ),
    );
  }

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite code copied!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
