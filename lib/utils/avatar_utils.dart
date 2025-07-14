import 'package:flutter/material.dart';

class AvatarUtils {
  // Generate a unique gradient for each user based on their ID
  static List<Color> getUserGradient(String userId, ThemeData theme) {
    // Create a hash from the user ID to get consistent colors
    final hash = userId.hashCode;
    final colors = [
      [
        theme.colorScheme.primary,
        theme.colorScheme.secondary,
      ], // Primary to Secondary
      [
        theme.colorScheme.tertiary,
        theme.colorScheme.primary,
      ], // Tertiary to Primary
      [
        theme.colorScheme.secondary,
        theme.colorScheme.tertiary,
      ], // Secondary to Tertiary
      [
        theme.colorScheme.primary,
        theme.colorScheme.primary.withValues(alpha: 0.6),
      ], // Primary variants
      [
        theme.colorScheme.secondary,
        theme.colorScheme.secondary.withValues(alpha: 0.6),
      ], // Secondary variants
      [
        theme.colorScheme.tertiary,
        theme.colorScheme.tertiary.withValues(alpha: 0.6),
      ], // Tertiary variants
      [
        theme.colorScheme.primary,
        theme.colorScheme.tertiary,
      ], // Primary to Tertiary
      [
        theme.colorScheme.secondary,
        theme.colorScheme.primary,
      ], // Secondary to Primary
      [
        theme.colorScheme.tertiary,
        theme.colorScheme.secondary,
      ], // Tertiary to Secondary
      [
        theme.colorScheme.primary.withValues(alpha: 0.6),
        theme.colorScheme.secondary.withValues(alpha: 0.6),
      ], // Muted variants
    ];

    // Use the hash to select a consistent gradient for each user
    final index = (hash.abs() % colors.length);
    return colors[index];
  }

  // Generate a unique gradient for each group based on their name
  static List<Color> getGroupGradient(String groupName, ThemeData theme) {
    // Create a hash from the group name to get consistent colors
    final hash = groupName.hashCode;
    final colors = [
      [Colors.purple, Colors.pink], // Purple to Pink
      [Colors.blue, Colors.cyan], // Blue to Cyan
      [Colors.green, Colors.teal], // Green to Teal
      [Colors.orange, Colors.red], // Orange to Red
      [Colors.indigo, Colors.purple], // Indigo to Purple
      [Colors.teal, Colors.green], // Teal to Green
      [Colors.pink, Colors.orange], // Pink to Orange
      [Colors.cyan, Colors.blue], // Cyan to Blue
      [Colors.red, Colors.pink], // Red to Pink
      [Colors.purple, Colors.indigo], // Purple to Indigo
      [Colors.green, Colors.blue], // Green to Blue
      [Colors.orange, Colors.yellow], // Orange to Yellow
      [Colors.pink, Colors.purple], // Pink to Purple
      [Colors.blue, Colors.green], // Blue to Green
      [Colors.red, Colors.orange], // Red to Orange
    ];

    // Use the hash to select a consistent gradient for each group
    final index = (hash.abs() % colors.length);
    return colors[index];
  }

  // Build user avatar with avatarUrl if present, fallback to Vercel avatar, then gradient
  static Widget buildUserAvatar(
    String userId,
    String userName,
    ThemeData theme, {
    double radius = 20,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.bold,
    String? avatarUrl, // <-- new optional param
  }) {
    final gradient = getUserGradient(userId, theme);
    final initials = userName.isNotEmpty ? userName[0].toUpperCase() : null;
    final fallbackUrl = getVercelAvatarUrl(userId, initials: initials);
    final useUrl =
        (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : fallbackUrl;
    final isVercelAvatar = (avatarUrl == null || avatarUrl.isEmpty);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.transparent,
        backgroundImage: NetworkImage(useUrl),
        onBackgroundImageError: (_, __) {}, // fallback to text if image fails
        child:
            isVercelAvatar
                ? Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  ),
                )
                : null,
      ),
    );
  }

  // Build group avatar with gradient background
  static Widget buildGroupAvatar(
    String groupName,
    ThemeData theme, {
    double radius = 20,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.bold,
  }) {
    final gradient = getGroupGradient(groupName, theme);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.transparent,
        child: Text(
          groupName.isNotEmpty ? groupName[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }

  // Generic avatar builder that can be used for any entity
  static Widget buildAvatar(
    String id,
    String name,
    ThemeData theme, {
    double radius = 20,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.bold,
    bool isGroup = false,
  }) {
    if (isGroup) {
      return buildGroupAvatar(
        name,
        theme,
        radius: radius,
        fontSize: fontSize,
        fontWeight: fontWeight,
      );
    } else {
      return buildUserAvatar(
        id,
        name,
        theme,
        radius: radius,
        fontSize: fontSize,
        fontWeight: fontWeight,
      );
    }
  }

  // Get gradient colors for any entity
  static List<Color> getGradient(
    String id,
    String name,
    ThemeData theme, {
    bool isGroup = false,
  }) {
    if (isGroup) {
      return getGroupGradient(name, theme);
    } else {
      return getUserGradient(id, theme);
    }
  }

  /// Returns a Vercel avatar URL for the given username or userId.
  /// Example: https://avatar.vercel.sh/username?size=120&rounded=60
  static String getVercelAvatarUrl(
    String identifier, {
    int size = 120,
    int rounded = 60,
    bool svg = false,
    String? initials,
  }) {
    final base = 'https://avatar.vercel.sh/';
    final ext = svg ? '.svg' : '';
    final params = <String, String>{
      'size': size.toString(),
      'rounded': rounded.toString(),
    };
    if (initials != null && svg) {
      params['text'] = initials;
    }
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$base$identifier$ext?$query';
  }
}
