import 'package:flutter/material.dart';
import '../utils/avatar_utils.dart';

class UserListItem extends StatelessWidget {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? amount;
  final VoidCallback? onTap;

  /// Optional trailing widget. If provided it overrides [amount] and selection checkbox.
  final Widget? trailingWidget;

  /// Selection helpers: when [onSelectedChanged] is provided a Checkbox will be
  /// shown (unless [trailingWidget] is provided). [selected] controls checkbox state.
  final bool selected;
  final ValueChanged<bool?>? onSelectedChanged;

  /// Optional subtitle displayed under the user's name (e.g. email or username)
  final String? subtitle;

  const UserListItem({
    super.key,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.amount,
    this.onTap,
    this.trailingWidget,
    this.selected = false,
    this.onSelectedChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap ?? () => {print("Tapped on user: $name")},
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
      subtitle:
          subtitle != null
              ? Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
              : null,
      trailing:
          trailingWidget != null
              ? trailingWidget
              : (amount != null
                  ? Text(
                    amount!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                  : (onSelectedChanged != null
                      ? Checkbox(value: selected, onChanged: onSelectedChanged)
                      : null)),
    );
  }
}
