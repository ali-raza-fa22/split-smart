import 'package:flutter/material.dart';
import '../utils/avatar_utils.dart';

class UserListItem extends StatelessWidget {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? amount;

  const UserListItem({
    super.key,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => {print("Tapped on user: $name")},
      leading: AvatarUtils.buildUserAvatar(
        userId,
        name,
        theme,
        avatarUrl: avatarUrl,
        radius: 20,
      ),
      title: Text(
        name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      trailing:
          amount != null
              ? Text(
                amount!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              )
              : null,
    );
  }
}
