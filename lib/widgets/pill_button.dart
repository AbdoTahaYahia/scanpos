import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pill-shaped button following the organic minimalist design system.
///
/// - **Primary**: Solid black background, white text (default)
/// - **Secondary**: White background with 2px black border, black text
/// - **Ghost**: No background, bold underlined text
enum PillButtonVariant { primary, secondary, ghost }

class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PillButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double height;

  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PillButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;

    return SizedBox(
      width: width,
      height: height,
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: _buildButton(isDisabled),
      ),
    );
  }

  Widget _buildButton(bool isDisabled) {
    switch (variant) {
      case PillButtonVariant.primary:
        return ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.black,
            foregroundColor: AppTheme.white,
            elevation: 0,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 32),
            textStyle: AppTheme.bodyLg.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.white,
            ),
          ),
          child: _buildContent(AppTheme.white),
        );

      case PillButtonVariant.secondary:
        return OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.black,
            backgroundColor: AppTheme.white,
            elevation: 0,
            shape: const StadiumBorder(),
            side: AppTheme.borderDefault,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            textStyle: AppTheme.bodyLg.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.black,
            ),
          ),
          child: _buildContent(AppTheme.black),
        );

      case PillButtonVariant.ghost:
        return TextButton(
          onPressed: isDisabled ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.black,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            textStyle: AppTheme.bodyLg.copyWith(
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              color: AppTheme.black,
            ),
          ),
          child: _buildContent(AppTheme.black, underline: true),
        );
    }
  }

  Widget _buildContent(Color color, {bool underline = false}) {
    if (isLoading) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: color,
        ),
      );
    }

    final textWidget = Text(
      label,
      style: TextStyle(
        decoration: underline ? TextDecoration.underline : null,
        decorationColor: color,
      ),
    );

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          textWidget,
        ],
      );
    }

    return textWidget;
  }
}
