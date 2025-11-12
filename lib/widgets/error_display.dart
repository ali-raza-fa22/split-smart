import 'package:flutter/material.dart';
import '../utils/app_exceptions.dart';

class ErrorDisplay {
  static String _getErrorMessage(dynamic error) {
    if (error is AppException) return error.message;
    return 'An unexpected error occurred. Please try again.';
  }

  static void showErrorSnackBar(
    BuildContext context,
    dynamic error, {
    Duration duration = const Duration(seconds: 4),
  }) {
    final message = _getErrorMessage(error);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: duration,
      ),
    );
  }

  static Future<void> showErrorDialog(
    BuildContext context,
    dynamic error, {
    String? title,
    VoidCallback? onRetry,
  }) async {
    final message = _getErrorMessage(error);
    if (!context.mounted) return;
    return showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title ?? 'Error'),
            content: Text(message),
            actions: [
              if (onRetry != null)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onRetry();
                  },
                  child: const Text('Retry'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}
