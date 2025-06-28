import 'package:flutter/material.dart';
import 'package:split_smart_supabase/utils/constants.dart';
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
    IconData icon;
    Color color;
    switch (type) {
      case 'add':
        icon = Icons.add_circle_outline;
        color = Colors.green;
        break;
      case 'spend':
        icon = Icons.remove_circle_outline;
        color = Colors.red;
        break;
      case 'loan':
        icon = Icons.credit_card;
        color = theme.colorScheme.error;
        break;
      case 'repay':
        icon = Icons.check_circle_outline;
        color = Colors.blue;
        break;
      default:
        icon = Icons.swap_horiz;
        color = theme.colorScheme.primary;
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
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  'Rs ${amount.toStringAsFixed(2)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppConstants.getTransactionTypeLabel(type),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
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
