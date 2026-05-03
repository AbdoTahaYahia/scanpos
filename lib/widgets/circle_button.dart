import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Perfect circle button for quantity +/- controls and keypad digits.
class CircleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double size;
  final bool filled;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const CircleButton({
    super.key,
    required this.child,
    this.onPressed,
    this.size = 56,
    this.filled = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  /// Convenience constructor for icon buttons
  factory CircleButton.icon({
    Key? key,
    required IconData icon,
    VoidCallback? onPressed,
    double size = 56,
    bool filled = false,
    double iconSize = 24,
  }) {
    return CircleButton(
      key: key,
      onPressed: onPressed,
      size: size,
      filled: filled,
      child: Icon(
        icon,
        size: iconSize,
        color: filled ? AppTheme.white : AppTheme.black,
      ),
    );
  }

  /// Convenience constructor for text/number buttons
  factory CircleButton.text({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    double size = 64,
    bool filled = false,
  }) {
    return CircleButton(
      key: key,
      onPressed: onPressed,
      size: size,
      filled: filled,
      child: Text(
        text,
        style: AppTheme.headlineMd.copyWith(
          color: filled ? AppTheme.white : AppTheme.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ??
        (filled ? AppTheme.black : AppTheme.white);
    final fgColor = foregroundColor ??
        (filled ? AppTheme.white : AppTheme.black);

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: filled
              ? null
              : Border.all(
                  color: AppTheme.black,
                  width: AppTheme.borderLevel1,
                ),
        ),
        child: Center(
          child: IconTheme(
            data: IconThemeData(color: fgColor),
            child: DefaultTextStyle(
              style: TextStyle(color: fgColor),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
