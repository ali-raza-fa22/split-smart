import 'package:SPLITSMART/utils/app_utils.dart';
import 'package:SPLITSMART/utils/constants.dart';
import 'package:flutter/material.dart';

import '../utils/date_formatter.dart';

class BalanceTransactionDetailCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  const BalanceTransactionDetailCard({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = transaction;
    final type = tx['transaction_type'] as String?;
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final title = tx['title'] as String? ?? '';
    final date = tx['created_at'] as String?;
    final expenseTitle = tx['expense_shares']?['expenses']?['title'] as String?;
    final groupName = tx['expense_shares']?['groups']?['name'] as String?;
    final description = tx['description'] as String?;
    final id = tx['id']?.toString();

    // Icon and color for type
    Color _colorForType(BuildContext context, String type) {
      switch (type) {
        case 'add':
          return Theme.of(context).colorScheme.tertiary;
        case 'spend':
          return Colors.red;
        default:
          return Colors.red;
      }
    }

    IconData _iconForType(String type) {
      switch (type) {
        case 'add':
          return Icons.south_west;
        case 'spend':
          return Icons.north_east;
        default:
          // Treat unknown types as 'spend' visually
          return Icons.north_east;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Card (amount, type, group/expense)
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _colorForType(context, type!),
                  child: Icon(
                    _iconForType(type),
                    color: theme.colorScheme.onPrimary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppUtils.formatCurrency(amount),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: _colorForType(context, type),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppConstants.getTransactionTypeLabel(type),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _colorForType(context, type),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (groupName != null || expenseTitle != null) ...[
                  const SizedBox(height: 8),
                  if (groupName != null)
                    Text(
                      groupName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (expenseTitle != null)
                    Text(
                      expenseTitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        // Transaction Details Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TRANSACTION DETAILS',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _detailRow('Transaction ID', id ?? '-'),
              const SizedBox(height: 12),
              _detailRow(
                'Transaction Time',
                DateFormatter.formatFullDateTime(date),
              ),
              const SizedBox(height: 12),
              if (title.isNotEmpty) _detailRow('Title', title),
              const SizedBox(height: 12),
              if (description != null && description.isNotEmpty)
                _detailRow('Description', description),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(flex: 3, child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
