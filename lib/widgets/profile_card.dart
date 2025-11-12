import 'package:flutter/material.dart';
import '/utils/avatar_utils.dart';

class ProfileCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final EdgeInsetsGeometry? margin;

  const ProfileCard({super.key, required this.profile, this.margin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.onSecondary.withAlpha(30),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Container(
              child: AvatarUtils.buildUserAvatar(
                profile?['id'],
                profile?['display_name'],
                theme,
                avatarUrl: profile?['avatar_url'],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    profile?['display_name'],
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "@${profile?['username']}",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
