import 'package:flutter/material.dart';

class BalanceDisplay extends StatelessWidget {
  final double? amount;
  final Color? color;
  final double fontSize;
  final FontWeight fontWeight;
  final bool showCurrency;

  const BalanceDisplay({
    super.key,
    required this.amount,
    this.color,
    this.fontSize = 28,
    this.fontWeight = FontWeight.bold,
    this.showCurrency = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayAmount = (amount ?? 0.0) < 0 ? 0.0 : (amount ?? 0.0);
    final parts = displayAmount.toStringAsFixed(2).split('.');
    final themeColor = color ?? Theme.of(context).colorScheme.primary;
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontWeight: fontWeight,
          color: themeColor,
          fontSize: fontSize,
        ),
        children: [
          if (showCurrency)
            TextSpan(
              text: 'Rs. ',
              style: TextStyle(
                fontSize: fontSize * 0.6,
                fontWeight: fontWeight,
              ),
            ),
          TextSpan(text: parts[0]),
          TextSpan(
            text: '.${parts[1]}',
            style: TextStyle(
              fontSize: fontSize * 0.7,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
