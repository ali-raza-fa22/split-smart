import 'package:flutter/material.dart';
import 'app_constants.dart';

class AppUtils {
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Calculate average amount from a list of items with amount field
  static double calculateAverageAmount(
    List<Map<String, dynamic>> items,
    String amountField,
  ) {
    if (items.isEmpty) return 0.0;
    return (items.fold(0.0, (sum, item) => sum + (item[amountField] as num)) /
            items.length)
        .roundToDouble();
  }

  // Calculate maximum amount from a list of items with amount field
  static double calculateMaxAmount(
    List<Map<String, dynamic>> items,
    String amountField,
  ) {
    if (items.isEmpty) return 0.0;
    return items.fold(
      0.0,
      (max, item) =>
          (item[amountField] as num) > max
              ? (item[amountField] as num).toDouble()
              : max,
    );
  }

  // Transform expense shares for modals
  static List<Map<String, dynamic>> transformExpenseSharesForModal(
    List<Map<String, dynamic>> shares,
  ) {
    return shares
        .map(
          (share) => {
            'expense_name': share['expenses']?['title'] ?? "Unknown Item",
            'group_name':
                share['expenses']?['groups']?['name'] ?? "Unknown Group",
            'amount_owed': share['amount_owed'],
            'is_paid': share['is_paid'],
          },
        )
        .toList();
  }

  // Transform created expenses for modal
  static List<Map<String, dynamic>> transformCreatedExpensesForModal(
    List<Map<String, dynamic>> expenses,
  ) {
    return expenses
        .map(
          (expense) => {
            'expense_name': expense['title'] ?? "Unknown Item",
            'group_name': expense['groups']?['name'] ?? "Unknown Group",
            'total_amount': expense['total_amount'],
            'is_paid':
                true, // Created expenses are considered "paid" by creator
          },
        )
        .toList();
  }

  // Check if item is active based on last activity date
  static bool isItemActive(Map<String, dynamic> item, String dateField) {
    final lastActivity = item[dateField];
    if (lastActivity == null) return false;

    try {
      final activityTime = DateTime.parse(lastActivity);
      final thresholdDate = DateTime.now().subtract(
        Duration(days: AppConstants.activityThresholdDays),
      );
      return activityTime.isAfter(thresholdDate);
    } catch (e) {
      return false;
    }
  }

  // Calculate rate with bounds checking
  static double calculateRate(double total, double completed) {
    if (total <= 0) return 0.0;
    final effectiveCompleted = completed > total ? total : completed;
    return (effectiveCompleted / total) * 100;
  }

  // Calculate savings rate
  static double calculateSavingsRate(double income, double outflow) {
    if (income <= 0) return 0.0;
    return ((income - outflow) / income) * 100;
  }

  // Calculate percentage change
  static double calculatePercentageChange(double current, double previous) {
    if (previous <= 0) return 0.0;
    return ((current - previous) / previous) * 100;
  }

  // Get status color based on value
  static Color getStatusColor(double value, {bool isPositive = true}) {
    if (isPositive) {
      return value >= 0 ? Colors.green : Colors.red;
    } else {
      return value <= 0 ? Colors.green : Colors.red;
    }
  }

  // Get rate color based on threshold
  static Color getRateColor(double rate) {
    return rate >= AppConstants.goodRateThreshold
        ? Colors.green
        : Colors.orange;
  }

  /// Format currency amount
  static String formatCurrency(double amount) {
    return '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
  }

  // Format percentage
  static String formatPercentage(double percentage) {
    return '${percentage.toStringAsFixed(1)}%';
  }

  // Format percentage with sign
  static String formatPercentageWithSign(double percentage) {
    final sign = percentage >= 0 ? '+' : '';
    return '$sign${formatPercentage(percentage)}';
  }

  // Format date
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Format date time
  static String formatDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
