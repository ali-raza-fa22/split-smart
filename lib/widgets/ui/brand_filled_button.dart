import 'package:flutter/material.dart';

class BrandFilledButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;
  final double height;
  final double borderRadius;
  final double elevation;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final Widget? child;
  final bool enabled;

  const BrandFilledButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.height = 50.0,
    this.borderRadius = 12.0,
    this.elevation = 2.0,
    this.padding,
    this.textStyle,
    this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Determine effective colors
    final effectiveBackgroundColor = backgroundColor ?? colorScheme.primary;
    final effectiveForegroundColor = foregroundColor ?? colorScheme.onPrimary;
    final effectiveTextStyle =
        textStyle ??
        textTheme.titleMedium?.copyWith(
          color: effectiveForegroundColor,
          fontWeight: FontWeight.w600,
        );

    // Determine if button should be disabled
    final isDisabled = !enabled || isLoading || onPressed == null;

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveBackgroundColor,
          foregroundColor: effectiveForegroundColor,
          disabledBackgroundColor: colorScheme.onSurface.withOpacity(0.12),
          disabledForegroundColor: colorScheme.onSurface.withOpacity(0.38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: elevation,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16.0),
          shadowColor: effectiveBackgroundColor.withOpacity(0.3),
        ),
        child: _buildButtonContent(effectiveTextStyle),
      ),
    );
  }

  Widget _buildButtonContent(TextStyle? textStyle) {
    if (isLoading) {
      return SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            foregroundColor ?? Colors.white,
          ),
        ),
      );
    }

    if (child != null) {
      return child!;
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(text, style: textStyle),
        ],
      );
    }

    return Text(text, style: textStyle);
  }

  // Convenience constructors for common button types

  // Secondary button
  static Widget secondary({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
    double? width,
    double height = 50.0,
    bool enabled = true,
  }) {
    return BrandFilledButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      backgroundColor: Colors.grey[600],
      foregroundColor: Colors.white,
      width: width,
      height: height,
      enabled: enabled,
    );
  }

  // Success button
  static Widget success({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
    double? width,
    double height = 50.0,
    bool enabled = true,
  }) {
    return BrandFilledButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      backgroundColor: Colors.green[600],
      foregroundColor: Colors.white,
      width: width,
      height: height,
      enabled: enabled,
    );
  }

  // Danger button
  static Widget danger({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
    double? width,
    double height = 50.0,
    bool enabled = true,
  }) {
    return BrandFilledButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      backgroundColor: Colors.red[600],
      foregroundColor: Colors.white,
      width: width,
      height: height,
      enabled: enabled,
    );
  }

  // Small button
  static Widget small({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
    double? width,
    bool enabled = true,
  }) {
    return BrandFilledButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      width: width,
      height: 40.0,
      borderRadius: 8.0,
      enabled: enabled,
    );
  }

  // Large button
  static Widget large({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
    double? width,
    bool enabled = true,
  }) {
    return BrandFilledButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      width: width,
      height: 56.0,
      borderRadius: 16.0,
      enabled: enabled,
    );
  }
}
