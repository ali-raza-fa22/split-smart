import 'package:flutter/material.dart';

class UnreadBadge extends StatelessWidget {
  final int count;
  final double size;
  final Color? color;
  final Color? textColor;
  final bool showCount;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;
  final bool showShadow;

  const UnreadBadge({
    super.key,
    required this.count,
    this.size = 20,
    this.color,
    this.textColor,
    this.showCount = true,
    this.fontSize,
    this.padding,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.error;
    final effectiveTextColor = textColor ?? Colors.white;
    final effectiveFontSize = fontSize ?? (size * 0.65);
    final effectivePadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 6);

    return Container(
      height: size,
      constraints: BoxConstraints(minWidth: size),
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(size / 2),
        boxShadow:
            showShadow
                ? [
                  BoxShadow(
                    color: effectiveColor.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
      alignment: Alignment.center,
      child:
          showCount
              ? Text(
                count > 99 ? '99+' : count.toString(),
                style: TextStyle(
                  color: effectiveTextColor,
                  fontSize: effectiveFontSize,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
              : null,
    );
  }

  // Convenience constructors for common use cases

  // Small dot badge (no count)
  static Widget dot({
    Key? key,
    double size = 8,
    Color? color,
    bool showShadow = false,
  }) {
    return UnreadBadge(
      key: key,
      count: 1,
      size: size,
      color: color,
      showCount: false,
      showShadow: showShadow,
    );
  }

  // Small badge for notifications
  static Widget small({
    Key? key,
    required int count,
    Color? color,
    Color? textColor,
  }) {
    return UnreadBadge(
      key: key,
      count: count,
      size: 16,
      color: color,
      textColor: textColor,
      fontSize: 10,
    );
  }

  // Medium badge for chat lists
  static Widget medium({
    Key? key,
    required int count,
    Color? color,
    Color? textColor,
  }) {
    return UnreadBadge(
      key: key,
      count: count,
      size: 20,
      color: color,
      textColor: textColor,
    );
  }

  // Large badge for important notifications
  static Widget large({
    Key? key,
    required int count,
    Color? color,
    Color? textColor,
  }) {
    return UnreadBadge(
      key: key,
      count: count,
      size: 24,
      color: color,
      textColor: textColor,
      fontSize: 14,
    );
  }

  // Primary theme badge
  static Widget primary({
    Key? key,
    required int count,
    double size = 20,
    Color? textColor,
  }) {
    return UnreadBadge(
      key: key,
      count: count,
      size: size,
      textColor: textColor,
    );
  }

  // Secondary theme badge
  static Widget secondary({
    Key? key,
    required int count,
    double size = 20,
    Color? textColor,
  }) {
    return UnreadBadge(
      key: key,
      count: count,
      size: size,
      color: Colors.grey[600],
      textColor: textColor,
    );
  }

  // Success badge
  static Widget success({
    Key? key,
    required int count,
    double size = 20,
    Color? textColor,
  }) {
    return UnreadBadge(
      key: key,
      count: count,
      size: size,
      color: Colors.green[600],
      textColor: textColor,
    );
  }

  // Warning badge
  static Widget warning({
    Key? key,
    required int count,
    double size = 20,
    Color? textColor,
  }) {
    return UnreadBadge(
      key: key,
      count: count,
      size: size,
      color: Colors.orange[600],
      textColor: textColor,
    );
  }
}
