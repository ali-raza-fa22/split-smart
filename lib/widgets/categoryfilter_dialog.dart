import 'package:flutter/material.dart';

class CategoryFilterDialog extends StatelessWidget {
  final String selected;
  const CategoryFilterDialog({super.key, required this.selected});
  @override
  Widget build(BuildContext context) {
    final options = [
      {'value': 'all', 'label': 'All Categories'},
      {'value': 'add', 'label': 'Add'},
      {'value': 'spend', 'label': 'Spend'},
      {'value': 'loan', 'label': 'Loan'},
      {'value': 'repay', 'label': 'Repay'},
    ];
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Category Filter',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ...options.map((opt) {
              final isSelected = selected == opt['value'];
              return ListTile(
                onTap: () => Navigator.pop(context, opt['value']),
                title: Text(
                  opt['label']!,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing:
                    isSelected
                        ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                        : null,
                selected: isSelected,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor:
                    isSelected
                        ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08)
                        : null,
              );
            }),
          ],
        ),
      ),
    );
  }
}
