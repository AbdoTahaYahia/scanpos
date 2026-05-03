import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Large pill-shaped category chip for quick-add categories.
/// Min height 64px, 18px bold text per DESIGN.md spec.
class ProductChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;

  const ProductChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.black : AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: AppTheme.black,
            width: AppTheme.borderLevel1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppTheme.white : AppTheme.black,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: AppTheme.bodyLg.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected ? AppTheme.white : AppTheme.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
