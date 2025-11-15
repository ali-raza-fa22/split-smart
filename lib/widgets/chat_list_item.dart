import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final String? avatarUrl;

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
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = _getCurrentUserId();

    // Build trailing widget
    Widget trailingWidget = trailing ?? _buildDefaultTrailing(context, theme);

    // ensure we resolve the real current user id (fallback to _getCurrentUserId())
    final effectiveCurrentUserId =
        (() {
          try {
            return _getCurrentUserId() ?? currentUserId;
          } catch (_) {
            return currentUserId;
          }
        })();

    final Widget subtitleWidget =
        lastMessage != null
            ? RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text:
                        '${lastMessageSenderId != null && lastMessageSenderId == effectiveCurrentUserId ? 'You' : (lastMessageSenderName ?? 'Unknown')}: ',
                    style: TextStyle(
                      color: theme.colorScheme.tertiary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: lastMessage!,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
            : Text(
              'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.colorScheme.onSurface),
            );

    return ListTile(
      leading:
          isGroup
              ? AvatarUtils.buildGroupAvatar(name, theme)
              : AvatarUtils.buildUserAvatar(
                id,
                name,
                theme,
                avatarUrl: avatarUrl,
              ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: subtitleWidget,
      trailing: trailingWidget,
      onTap: onTap,
      onLongPress: onLongPress,
    );
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
    return Supabase.instance.client.auth.currentUser?.id;
  }
}
