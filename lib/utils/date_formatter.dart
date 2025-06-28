import 'package:flutter/material.dart';

class DateFormatter {
  // Format timestamp for message bubbles (WhatsApp style)
  static String formatMessageTime(String? createdAt) {
    if (createdAt == null) return '';

    try {
      // Parse as UTC and convert to local time
      final messageTime = DateTime.parse(createdAt).toLocal();
      // Only show time (e.g., "2:30 PM")
      return _formatTime(messageTime);
    } catch (e) {
      return '';
    }
  }

  // Format time (e.g., "2:30 PM")
  static String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  // Format date (e.g., "Jan 15")
  static String formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  // Get day name (e.g., "Monday")
  static String _getDayName(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[date.weekday - 1];
  }

  // Format day separator (e.g., "Today", "Yesterday", "Monday, January 15")
  static String formatDaySeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return _getDayName(date);
    } else {
      return formatDate(date);
    }
  }

  // Format timestamp for chat list (e.g., "2:30 PM", "Yesterday", "Mon", "1/21/24")
  static String formatChatListTimestamp(String? createdAt) {
    if (createdAt == null) return '';

    try {
      // Parse as UTC and convert to local time
      final messageTime = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(
        messageTime.year,
        messageTime.month,
        messageTime.day,
      );

      if (messageDate == today) {
        // Just time, e.g., "2:30 PM"
        final hour = messageTime.hour;
        final minute = messageTime.minute;
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        return '${displayHour.toString()}:${minute.toString().padLeft(2, '0')} $period';
      } else if (messageDate == today.subtract(const Duration(days: 1))) {
        return 'Yesterday';
      } else if (now.difference(messageTime).inDays < 7) {
        // Day of the week
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[messageTime.weekday - 1];
      } else {
        // Full date, e.g., "M/d/yy"
        return '${messageTime.month}/${messageTime.day}/${messageTime.year.toString().substring(2)}';
      }
    } catch (e) {
      return '';
    }
  }

  // Check if two dates are the same day
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Parse message timestamp to local DateTime
  static DateTime parseMessageTimestamp(String? createdAt) {
    if (createdAt == null) return DateTime.now();
    try {
      // Parse as UTC and convert to local time
      return DateTime.parse(createdAt).toLocal();
    } catch (e) {
      return DateTime.now();
    }
  }

  // Build day separator widget
  static Widget buildDaySeparator(String text, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  // Debug method to check timezone conversion
  static String debugTimezoneConversion(String? createdAt) {
    if (createdAt == null) return 'No timestamp';

    try {
      final utcTime = DateTime.parse(createdAt);
      final localTime = utcTime.toLocal();
      final now = DateTime.now();

      return '''
UTC: ${utcTime.toIso8601String()}
Local: ${localTime.toIso8601String()}
Now: ${now.toIso8601String()}
Offset: ${localTime.timeZoneOffset}
''';
    } catch (e) {
      return 'Error: $e';
    }
  }

  // Format full date and time (e.g., "Jan 15, 2024 2:30 PM")
  static String formatFullDateTime(dynamic dt) {
    if (dt == null) return '-';
    try {
      final date =
          dt is DateTime
              ? dt.toLocal()
              : DateTime.parse(dt.toString()).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final month = months[date.month - 1];
      final day = date.day;
      final year = date.year;
      int hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      hour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$month $day, $year $hour:$minute $period';
    } catch (_) {
      return dt.toString();
    }
  }
}
