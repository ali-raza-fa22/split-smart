import 'package:flutter/material.dart';

class BrandButton2 extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;
  final double? width;
  const BrandButton2({
    super.key,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onPressed,
    this.width,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceVariant,
          foregroundColor: theme.colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side:
              isActive
                  ? BorderSide(color: theme.colorScheme.primary, width: 2)
                  : BorderSide(color: Colors.grey.shade400, width: 1),
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
