import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

class TransactionExportService {
  // Get the documents directory path for transactions
  Future<String> _getDocumentsPath() async {
    if (Platform.isAndroid) {
      final parentPath = AppConstants.documentsPath;
      final transactionsPath = '$parentPath/transactions';

      // Create the transactions subdirectory if it doesn't exist
      final transactionsDir = Directory(transactionsPath);
      if (!await transactionsDir.exists()) {
        await transactionsDir.create(recursive: true);
      }

      return transactionsPath;
    } else {
      // For other platforms, use the app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final transactionsPath =
          '${directory.path}/split_smart_expenses/transactions';

      // Create the transactions subdirectory if it doesn't exist
      final transactionsDir = Directory(transactionsPath);
      if (!await transactionsDir.exists()) {
        await transactionsDir.create(recursive: true);
      }

      return transactionsPath;
    }
  }

  // Export a single transaction to CSV
  Future<String?> exportTransactionToCsv(
    Map<String, dynamic> transaction,
  ) async {
    try {
      final documentsPath = await _getDocumentsPath();
      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final fileName =
          'transaction-${transaction['id'] ?? timestamp}-$timestamp.csv';
      final filePath = '$documentsPath/$fileName';

      final csvContent = _generateTransactionCsvContent(transaction);
      final file = File(filePath);
      await file.writeAsString(csvContent, encoding: utf8);

      return filePath;
    } catch (e) {
      rethrow;
    }
  }

  // Export multiple transactions to CSV
  Future<String?> exportTransactionsToCsv(
    List<Map<String, dynamic>> transactions,
  ) async {
    try {
      if (transactions.isEmpty) {
        throw Exception('No transactions to export');
      }

      final documentsPath = await _getDocumentsPath();
      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final fileName = 'transactions-batch-$timestamp.csv';
      final filePath = '$documentsPath/$fileName';

      final csvContent = _generateTransactionsCsvContent(transactions);
      final file = File(filePath);
      await file.writeAsString(csvContent, encoding: utf8);

      return filePath;
    } catch (e) {
      rethrow;
    }
  }

  // Generate CSV content for a single transaction
  String _generateTransactionCsvContent(Map<String, dynamic> tx) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('SPLIT SMART - TRANSACTION EXPORT');
    buffer.writeln(
      'Exported: ${DateFormatter.formatFullDateTime(DateTime.now())}',
    );
    buffer.writeln();

    // Transaction details
    buffer.writeln('TRANSACTION DETAILS');
    buffer.writeln('-' * 20);
    buffer.writeln('Transaction ID,${tx['id'] ?? '-'}');
    buffer.writeln('Type,${tx['transaction_type'] ?? '-'}');
    buffer.writeln(
      'Amount,Rs ${(tx['amount'] as num?)?.toStringAsFixed(2) ?? '-'}',
    );
    buffer.writeln('Title,${_escapeCsvField(tx['title'] ?? '-')}');
    buffer.writeln('Description,${_escapeCsvField(tx['description'] ?? '-')}');
    buffer.writeln(
      'Date/Time,${DateFormatter.formatFullDateTime(tx['created_at'])}',
    );
    buffer.writeln(
      'Balance Before,Rs ${((tx['balance_before'] as num?)?.toDouble() ?? 0.0) < 0 ? 0.0 : (tx['balance_before'] as num?)?.toStringAsFixed(2) ?? '-'}',
    );
    buffer.writeln(
      'Balance After,Rs ${((tx['balance_after'] as num?)?.toDouble() ?? 0.0) < 0 ? 0.0 : (tx['balance_after'] as num?)?.toStringAsFixed(2) ?? '-'}',
    );

    // Related expense information if available
    if (tx['expense_shares']?['expenses'] != null) {
      buffer.writeln();
      buffer.writeln('RELATED EXPENSE');
      buffer.writeln('-' * 20);
      buffer.writeln(
        'Expense Title,${_escapeCsvField(tx['expense_shares']['expenses']['title'])}',
      );
      if (tx['expense_shares']?['groups'] != null) {
        buffer.writeln(
          'Group,${_escapeCsvField(tx['expense_shares']['groups']['name'])}',
        );
      }
    }

    buffer.writeln();
    buffer.writeln('=' * 20);
    buffer.writeln('END OF TRANSACTION EXPORT');
    buffer.writeln('=' * 20);

    return buffer.toString();
  }

  // Generate CSV content for multiple transactions
  String _generateTransactionsCsvContent(
    List<Map<String, dynamic>> transactions,
  ) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('SPLIT SMART - TRANSACTIONS BATCH EXPORT');
    buffer.writeln(
      'Exported: ${DateFormatter.formatFullDateTime(DateTime.now())}',
    );
    buffer.writeln('Total Transactions: ${transactions.length}');
    buffer.writeln();

    // Summary section
    buffer.writeln('SUMMARY');
    buffer.writeln('-' * 20);

    double totalAmount = 0;
    Map<String, int> typeCounts = {};
    Map<String, double> typeAmounts = {};

    for (final tx in transactions) {
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final type = tx['transaction_type'] as String? ?? 'unknown';

      totalAmount += amount;
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      typeAmounts[type] = (typeAmounts[type] ?? 0) + amount;
    }

    buffer.writeln('Total Amount,Rs ${totalAmount.toStringAsFixed(2)}');
    buffer.writeln('Transaction Count,${transactions.length}');
    buffer.writeln();

    // Type breakdown
    buffer.writeln('TYPE BREAKDOWN');
    buffer.writeln('Type,Count,Total Amount');
    typeCounts.forEach((type, count) {
      final amount = typeAmounts[type] ?? 0;
      buffer.writeln('$type,$count,Rs ${amount.toStringAsFixed(2)}');
    });
    buffer.writeln();

    // Individual transactions
    buffer.writeln('TRANSACTIONS');
    buffer.writeln('-' * 20);
    buffer.writeln(
      'ID,Type,Amount,Title,Description,Date/Time,Balance Before,Balance After',
    );

    for (final tx in transactions) {
      buffer.writeln(
        [
          tx['id'] ?? '-',
          tx['transaction_type'] ?? '-',
          'Rs ${(tx['amount'] as num?)?.toStringAsFixed(2) ?? '-'}',
          _escapeCsvField(tx['title'] ?? '-'),
          _escapeCsvField(tx['description'] ?? '-'),
          DateFormatter.formatFullDateTime(tx['created_at']),
          'Rs ${((tx['balance_before'] as num?)?.toDouble() ?? 0.0) < 0 ? 0.0 : (tx['balance_before'] as num?)?.toStringAsFixed(2) ?? '-'}',
          'Rs ${((tx['balance_after'] as num?)?.toDouble() ?? 0.0) < 0 ? 0.0 : (tx['balance_after'] as num?)?.toStringAsFixed(2) ?? '-'}',
        ].join(','),
      );
    }

    buffer.writeln();
    buffer.writeln('=' * 20);
    buffer.writeln('END OF TRANSACTIONS EXPORT');
    buffer.writeln('=' * 20);

    return buffer.toString();
  }

  // Escape CSV field to handle commas and quotes
  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  // Get the documents directory path (public method for other services)
  Future<String> getDocumentsPath() async {
    return await _getDocumentsPath();
  }
}
