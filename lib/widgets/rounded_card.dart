import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Rounded-rectangle container card with 2px black border
/// and 24px+ corner radius. Used for product items, cart entries, etc.
class RoundedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool filled;

  const RoundedCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: filled
            ? AppTheme.black
            : (backgroundColor ?? AppTheme.white),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: filled
            ? null
            : Border.all(
                color: AppTheme.black,
                width: AppTheme.borderLevel1,
              ),
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: card,
      );
    }

    return card;
  }
}
