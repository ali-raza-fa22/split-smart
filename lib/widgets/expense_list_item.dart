import 'package:flutter/material.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: isPaid ? Colors.green : theme.colorScheme.primary,
          child: Icon(
            isPaid ? Icons.check : Icons.receipt,
            color: Colors.white,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Group: $groupName',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Paid by: $paidByName'),
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(description!, overflow: TextOverflow.ellipsis, maxLines: 2),
            ],
            const SizedBox(height: 4),
            Text(
              '${createdAt.day}/${createdAt.month}/${createdAt.year}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (isPaid ? Colors.green : Colors.orange).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isPaid ? 'Paid' : 'Pending',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isPaid ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'View Details',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            if (!isPaid && onMarkPaid != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
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
          ],
        ),
      ),
    );
  }
}
