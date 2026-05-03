import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Reusable style constants for the ScanPos design system.
class AppStyles {
  AppStyles._();

  // ─── Box Decorations ───────────────────────────────────────────────

  /// Level 1 container: white background, 2px black border, rounded
  static BoxDecoration get containerLevel1 => BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.black, width: AppTheme.borderLevel1),
      );

  /// Level 2 container: solid black, used for active/floating elements
  static BoxDecoration get containerLevel2 => BoxDecoration(
        color: AppTheme.black,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      );

  /// Soft container without border (surface tint)
  static BoxDecoration get containerSoft => BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      );

  /// Pill container decoration
  static BoxDecoration get pillContainer => BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: AppTheme.black, width: AppTheme.borderLevel1),
      );

  /// Pill container - filled (active state)
  static BoxDecoration get pillContainerFilled => BoxDecoration(
        color: AppTheme.black,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      );

  // ─── Padding Shortcuts ─────────────────────────────────────────────

  static const EdgeInsets paddingScreen = EdgeInsets.all(AppTheme.containerPadding);

  static const EdgeInsets paddingCard = EdgeInsets.all(20.0);

  static const EdgeInsets paddingHorizontal = EdgeInsets.symmetric(
    horizontal: AppTheme.containerPadding,
  );

  static const EdgeInsets paddingVertical = EdgeInsets.symmetric(
    vertical: AppTheme.containerPadding,
  );

  // ─── Gaps (SizedBox shortcuts) ─────────────────────────────────────

  static const SizedBox gap4 = SizedBox(height: 4);
  static const SizedBox gap8 = SizedBox(height: 8);
  static const SizedBox gap12 = SizedBox(height: 12);
  static const SizedBox gap16 = SizedBox(height: 16);
  static const SizedBox gap24 = SizedBox(height: 24);
  static const SizedBox gap32 = SizedBox(height: 32);
  static const SizedBox gap48 = SizedBox(height: 48);

  static const SizedBox gapW4 = SizedBox(width: 4);
  static const SizedBox gapW8 = SizedBox(width: 8);
  static const SizedBox gapW12 = SizedBox(width: 12);
  static const SizedBox gapW16 = SizedBox(width: 16);
  static const SizedBox gapW24 = SizedBox(width: 24);

  // ─── Shadows (none — design rejects shadows) ──────────────────────
  // Depth is achieved through borders and tonal inversion only.

  // ─── Animations ────────────────────────────────────────────────────

  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Curve animCurve = Curves.easeInOut;
}
