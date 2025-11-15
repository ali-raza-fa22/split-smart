import 'package:SPLITSMART/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:SPLITSMART/theme/theme.dart';

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
    return SizedBox(
      width: width,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onPrimary.withAlpha(180),
          foregroundColor:
              isActive
                  ? Theme.of(context).colorScheme.onPrimary
                  : AppColors.text,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
          ),
          side:
              isActive
                  ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1,
                  )
                  : BorderSide(color: Colors.grey.shade400, width: 1),
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
