import 'package:flutter/material.dart';
import '../utils/avatar_utils.dart';
import '../utils/date_formatter.dart';
import 'ui/unread_badge.dart';

class ChatListItem extends StatelessWidget {
  final String id;
  final String name;
  final String? lastMessage;
  final String? lastMessageSenderName;
  final String? lastMessageSenderId;
  final String? lastMessageTime;
  final int unreadCount;
  final bool isGroup;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  const ChatListItem({
    super.key,
    required this.id,
    required this.name,
    this.lastMessage,
    this.lastMessageSenderName,
    this.lastMessageSenderId,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isGroup = false,
    required this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = _getCurrentUserId();

    // Build subtitle
    String subtitle = _buildSubtitle(currentUserId);

    // Build trailing widget
    Widget trailingWidget = trailing ?? _buildDefaultTrailing(context, theme);

    return ListTile(
      leading: AvatarUtils.buildAvatar(id, name, theme, isGroup: isGroup),
      title: Text(
        name,
        style: isGroup ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color:
              lastMessage != null
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: trailingWidget,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  String _buildSubtitle(String? currentUserId) {
    if (lastMessage != null) {
      final senderName =
          lastMessageSenderId == currentUserId
              ? 'You'
              : (lastMessageSenderName ?? 'Unknown');
      return '$senderName: $lastMessage';
    } else {
      return 'No messages yet';
    }
  }

  Widget _buildDefaultTrailing(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (unreadCount > 0) ...[UnreadBadge.warning(count: unreadCount)],
        const SizedBox(width: 8),
        if (lastMessageTime != null)
          Text(
            DateFormatter.formatChatListTimestamp(lastMessageTime),
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
      ],
    );
  }

  String? _getCurrentUserId() {
    // This would need to be passed from the parent or accessed via a service
    // For now, we'll use the lastMessageSenderId pattern from the original code
    return null; // Will be handled by parent
  }
}
