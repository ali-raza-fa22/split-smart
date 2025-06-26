import 'package:flutter/material.dart';

class UnreadBadge extends StatelessWidget {
  final int count;
  final double size;
  final Color? color;
  final Color? textColor;

  const UnreadBadge({
    super.key,
    required this.count,
    this.size = 20,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      height: size,
      constraints: BoxConstraints(minWidth: size),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.error,
        borderRadius: BorderRadius.circular(size / 2),
        boxShadow: [
          BoxShadow(
            color: (color ?? theme.colorScheme.error).withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: size * 0.65,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
