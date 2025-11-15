import 'package:flutter/material.dart';
import '../utils/app_utils.dart';
import '../utils/date_formatter.dart';

class ExpenseListItem extends StatelessWidget {
  final String title;
  final String groupName;
  final String paidByName;
  final double amount;
  final DateTime createdAt;
  final String? description;
  final bool isPaid;
  final VoidCallback? onTap;
  final VoidCallback? onMarkPaid;
  final String? expenseShareId;
  final bool showDivider;

  const ExpenseListItem({
    super.key,
    required this.title,
    required this.groupName,
    required this.paidByName,
    required this.amount,
    required this.createdAt,
    this.description,
    this.isPaid = false,
    this.onTap,
    this.onMarkPaid,
    this.expenseShareId,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (showDivider) const Divider(height: 0),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.surface,
            child: Icon(
              size: 28,
              isPaid ? Icons.check_outlined : Icons.watch_later_outlined,
              color:
                  isPaid
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.primary,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    DateFormatter.formatDate(createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(AppUtils.formatCurrency(amount)),
              const SizedBox(height: 2),
              Text(
                'Group: $groupName',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              if (onMarkPaid != null && !isPaid) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 24,
                  child: ElevatedButton(
                    onPressed: onMarkPaid,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Mark Paid',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
              if (description != null && description!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  description!,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
