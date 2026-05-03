import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_styles.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/pill_input.dart';

class EnterInviteCodeScreen extends StatefulWidget {
  const EnterInviteCodeScreen({super.key});

  @override
  State<EnterInviteCodeScreen> createState() => _EnterInviteCodeScreenState();
}

class _EnterInviteCodeScreenState extends State<EnterInviteCodeScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await context
        .read<AuthProvider>()
        .joinStoreWithCode(_controller.text.trim());

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppStyles.paddingScreen,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppStyles.gap16,

                // Back button
                CircleAvatar(
                  backgroundColor: AppTheme.white,
                  foregroundColor: AppTheme.black,
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),

                AppStyles.gap32,

                Text('Join a Store', style: AppTheme.display),
                AppStyles.gap8,
                Text(
                  'Enter the 6-digit invite code from your manager.',
                  style: AppTheme.bodyLg.copyWith(
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),

                AppStyles.gap48,

                // Invite code input
                PillInput(
                  hint: 'Invite Code (e.g. ABC123)',
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitCode(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an invite code';
                    }
                    if (value.trim().length != 6) {
                      return 'Invite code must be 6 characters';
                    }
                    return null;
                  },
                ),

                AppStyles.gap16,

                // Error
                if (authProvider.error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.errorContainer,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusFull),
                      border: Border.all(color: AppTheme.error, width: 2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.error, size: 20),
                        AppStyles.gapW8,
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
                  AppStyles.gap16,
                ],

                AppStyles.gap8,

                SizedBox(
                  width: double.infinity,
                  child: PillButton(
                    label: 'Join Store',
                    onPressed: _isLoading ? null : _submitCode,
                    isLoading: _isLoading,
                    height: 64,
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
