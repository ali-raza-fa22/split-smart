import 'package:flutter/material.dart';
import '../services/csv_export_service.dart';

class CsvExportButton extends StatelessWidget {
  final String groupId;
  final String groupName;
  final int expensesCount;
  final VoidCallback? onExportComplete;
  final String? customLabel;
  final IconData? customIcon;
  final bool isCompact;

  const CsvExportButton({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.expensesCount,
    this.onExportComplete,
    this.customLabel,
    this.customIcon,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isCompact) {
      // Compact version for headers/modals
      return IconButton(
        onPressed: expensesCount > 0 ? () => _exportExpenses(context) : null,
        icon: Icon(customIcon ?? Icons.download, color: Colors.white, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
      );
    }

    // Full button version
    return ElevatedButton.icon(
      onPressed: expensesCount > 0 ? () => _exportExpenses(context) : null,
      icon: Icon(customIcon ?? Icons.download),
      label: Text(customLabel ?? 'Export Expenses to CSV'),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _exportExpenses(BuildContext context) async {
    final csvService = CsvExportService();

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              contentPadding: const EdgeInsets.all(20),
              content: SizedBox(
                width: double.maxFinite,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Exporting expenses...',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );

      final filePath = await csvService.exportGroupExpensesToCsv(
        groupId,
        groupName,
      );

      // Hide loading dialog
      Navigator.of(context).pop();

      if (filePath != null) {
        // Show success dialog
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Export Successful'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Expenses have been exported to:'),
                    const SizedBox(height: 8),
                    Text(
                      filePath,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You can find this file in your device\'s Documents folder under "split_smart_expenses".',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );

        // Call callback if provided
        onExportComplete?.call();
      }
    } catch (e) {
      // Hide loading dialog
      Navigator.of(context).pop();

      // Show error dialog
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Export Failed'),
              content: Text('Error exporting expenses: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }
}
