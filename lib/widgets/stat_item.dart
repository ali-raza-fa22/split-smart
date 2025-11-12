import 'package:SPLITSMART/theme/theme.dart';
import 'package:flutter/material.dart';

class StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final Widget? avatar;

  const StatItem({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
    this.margin,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTappable = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: margin ?? const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            width: 1,
            color: theme.colorScheme.onSurface.withAlpha(180),
          ),
        ),
        child: Row(
          children: [
            if (avatar != null) ...[avatar!, const SizedBox(width: 10)],
            if (icon != null) ...[
              Container(
                child: Icon(icon, color: theme.colorScheme.onSurface, size: 24),
              ),
              const SizedBox(width: 14),
            ] else ...[
              const SizedBox(width: 0),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isTappable)
              Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.primary,
                size: 14,
              ),
          ],
        ),
      ),
    );
  }
}
