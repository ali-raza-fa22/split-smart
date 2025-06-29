import 'package:flutter/material.dart';

class BrandTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final int? maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool readOnly;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final Color? errorBorderColor;
  final Color? prefixIconColor;
  final Color? suffixIconColor;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final bool filled;
  final Color? fillColor;

  const BrandTextFormField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.textInputAction,
    this.autofocus = false,
    this.readOnly = false,
    this.onTap,
    this.borderColor,
    this.focusedBorderColor,
    this.errorBorderColor,
    this.prefixIconColor,
    this.suffixIconColor,
    this.borderRadius = 12.0,
    this.contentPadding,
    this.filled = true,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Determine colors based on error state and theme
    final effectiveBorderColor =
        errorText != null
            ? (errorBorderColor ?? colorScheme.error)
            : (borderColor ?? colorScheme.outline);

    final effectiveFocusedBorderColor =
        errorText != null
            ? (errorBorderColor ?? colorScheme.error)
            : (focusedBorderColor ?? colorScheme.primary);

    final effectivePrefixIconColor =
        errorText != null
            ? (errorBorderColor ?? colorScheme.error)
            : (prefixIconColor ?? colorScheme.primary);

    final effectiveSuffixIconColor =
        suffixIconColor ?? colorScheme.onSurfaceVariant;
    final effectiveFillColor = fillColor ?? colorScheme.surface;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      textInputAction: textInputAction,
      autofocus: autofocus,
      readOnly: readOnly,
      onTap: onTap,
      style: textTheme.bodyLarge?.copyWith(
        color: enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        errorText: errorText,
        prefixIcon:
            prefixIcon != null
                ? Icon(prefixIcon, color: effectivePrefixIconColor)
                : null,
        suffixIcon:
            suffixIcon != null
                ? IconButton(
                  icon: Icon(suffixIcon, color: effectiveSuffixIconColor),
                  onPressed: onSuffixIconPressed,
                )
                : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: effectiveBorderColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: effectiveBorderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(
            color: effectiveFocusedBorderColor,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(
            color: errorBorderColor ?? colorScheme.error,
            width: 2.0,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(
            color: errorBorderColor ?? colorScheme.error,
            width: 2.0,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        filled: filled,
        fillColor: effectiveFillColor,
        contentPadding:
            contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color:
              errorText != null
                  ? (errorBorderColor ?? colorScheme.error)
                  : colorScheme.onSurfaceVariant,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: colorScheme.error),
        counterStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
