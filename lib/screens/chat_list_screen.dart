import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/auth.dart';
import '../utils/date_formatter.dart';
import 'chat_detail_screen.dart';
import 'create_group_screen.dart';
import 'group_chat_detail_screen.dart';
import 'profile_screen.dart';
import 'stats_screen.dart';
import 'all_expenses_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'verify_email_screen.dart';
import 'group_management_screen.dart';
import '../widgets/edit_group_name_dialog.dart';
import '../widgets/unread_badge.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _groups = [];
  Map<String, int> _directUnreadCounts = {};
  Map<String, int> _groupUnreadCounts = {};
  bool _isLoading = true;
  late TabController _tabController;
  StreamSubscription? _groupMessagesSubscription;
  StreamSubscription? _directMessagesSubscription;
  StreamSubscription? _messageReadStatusSubscription;
  StreamSubscription? _groupMessageReadStatusSubscription;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _checkEmailVerification();
    _loadData();
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _groupMessagesSubscription?.cancel();
    _directMessagesSubscription?.cancel();
    _messageReadStatusSubscription?.cancel();
    _groupMessageReadStatusSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Only refresh when app becomes active to ensure data is current
    if (state == AppLifecycleState.resumed && mounted) {
      _loadData(); // This already includes unread counts
    }
  }

  // No manual refresh on tab changes - rely on real-time streams
  void _onTabChanged() {
    // Real-time streams handle updates automatically
  }

  void _setupRealtimeSubscriptions() {
    // Listen for new group messages and update the group list automatically
    _groupMessagesSubscription = _chatService.getGroupMessagesStream().listen(
      (_) {
        // When a new message is detected, refresh the groups list with debouncing
        if (mounted) {
          _debounceRefresh(() => _refreshGroupsOnly());
        }
      },
      onError: (error) {
        // Handle error silently
      },
    );

    // Listen for new direct messages and update the users list automatically
    _directMessagesSubscription = _chatService.getDirectMessagesStream().listen(
      (_) {
        // When a new message is detected, refresh the users list immediately
        if (mounted) {
          _refreshUsersOnly();
        }
      },
      onError: (error) {
        // Handle error silently
      },
    );

    // Listen for message read status changes
    _messageReadStatusSubscription = _chatService
        .getMessageReadStatusStream()
        .listen(
          (_) {
            // When a message read status changes, refresh the users list immediately
            if (mounted) {
              _refreshUsersOnly();
            }
          },
          onError: (error) {
            // Handle error silently
          },
        );

    // Listen for group message read status changes
    _groupMessageReadStatusSubscription = _chatService
        .getGroupMessageReadStatusStream()
        .listen(
          (_) {
            // When a group message read status changes, refresh the groups list immediately
            if (mounted) {
              _refreshGroupsOnly();
            }
          },
          onError: (error) {
            // Handle error silently
          },
        );
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final users = await _chatService.getUsersWithLastMessage();
      final groups = await _chatService.getUserGroupsWithDetails();
      // Fetch unread counts for direct chats
      final directUnreadCounts = <String, int>{};
      for (final user in users) {
        final count = await _chatService.getUnreadDirectMessageCount(
          user['id'],
        );
        directUnreadCounts[user['id']] = count;
      }
      // Fetch unread counts for group chats
      final groupIds = groups.map((g) => g['id'] as String).toList();
      final groupUnreadCounts = await _chatService.getUnreadCountsForAllGroups(
        groupIds,
      );
      if (mounted) {
        setState(() {
          _users = users;
          _groups = groups;
          _directUnreadCounts = directUnreadCounts;
          _groupUnreadCounts = groupUnreadCounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshGroupsOnly() async {
    try {
      final groups = await _chatService.getUserGroupsWithDetails();
      // Also refresh unread counts for groups
      final groupIds = groups.map((g) => g['id'] as String).toList();
      final groupUnreadCounts = await _chatService.getUnreadCountsForAllGroups(
        groupIds,
      );
      if (mounted) {
        setState(() {
          _groups = groups;
          _groupUnreadCounts = groupUnreadCounts;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _refreshUsersOnly() async {
    try {
      final users = await _chatService.getUsersWithLastMessage();
      // Also refresh unread counts for direct chats
      final directUnreadCounts = <String, int>{};
      for (final user in users) {
        final count = await _chatService.getUnreadDirectMessageCount(
          user['id'],
        );
        directUnreadCounts[user['id']] = count;
      }
      if (mounted) {
        setState(() {
          _users = users;
          _directUnreadCounts = directUnreadCounts;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _checkEmailVerification() async {
    // Check if user's email is verified
    final isVerified = await _authService.isCurrentUserEmailVerified();
    if (!isVerified && mounted) {
      // Redirect to email verification screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => VerifyEmailScreen(
                email: _authService.currentUser?.email ?? '',
              ),
        ),
      );
    }
  }

  // Debounce refresh calls to prevent too many rapid updates
  void _debounceRefresh(VoidCallback refreshCallback) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), refreshCallback);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SplitSmart'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                  break;
                case 'stats':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StatsScreen(),
                    ),
                  );
                  break;
                case 'expenses':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllExpensesScreen(),
                    ),
                  );
                  break;
                case 'logout':
                  _authService
                      .logout()
                      .then((_) {
                        if (mounted) {
                          Navigator.of(context).pushReplacementNamed('/login');
                        }
                      })
                      .catchError((e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error logging out: $e')),
                          );
                        }
                      });
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person),
                        SizedBox(width: 8),
                        Text('Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'stats',
                    child: Row(
                      children: [
                        Icon(Icons.analytics),
                        SizedBox(width: 8),
                        Text('Stats'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'expenses',
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long),
                        SizedBox(width: 8),
                        Text('All Expenses'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.more_vert),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Direct'),
            Tab(icon: Icon(Icons.group), text: 'Groups'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [_buildUserList(), _buildGroupList()],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
          );
          // Reload data if a group was created or something changed
          if (result != false || mounted) {
            _loadData();
          }
        },
        tooltip: 'Create Group',
        child: const Icon(Icons.group_add),
      ),
    );
  }

  Widget _buildUserList() {
    if (_users.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: const Center(child: Text('No other users found.')),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final lastMessage = user['last_message_content'];
          final lastMessageTime = user['last_message_created_at'];
          final lastMessageSenderId = user['last_message_sender_id'];
          final lastMessageSenderName =
              user['last_message_sender_display_name'];
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          final unreadCount = _directUnreadCounts[user['id']] ?? 0;

          String subtitle;
          if (lastMessage != null) {
            final senderName =
                lastMessageSenderId == currentUserId
                    ? 'You'
                    : (lastMessageSenderName ?? 'Unknown');
            subtitle = '$senderName: $lastMessage';
          } else {
            subtitle = 'No messages yet';
          }

          return ListTile(
            leading: _buildUserAvatar(
              user['id'],
              user['display_name'] ?? 'Unknown User',
              Theme.of(context),
            ),
            title: Text(user['display_name'] ?? 'Unknown User'),
            subtitle: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  UnreadBadge(
                    count: unreadCount,
                    color: Theme.of(context).colorScheme.errorContainer,
                  ),
                ],
                const SizedBox(width: 8),
                if (lastMessageTime != null)
                  Text(
                    DateFormatter.formatChatListTimestamp(lastMessageTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => ChatDetailScreen(
                        otherUserId: user['id'],
                        otherUserName: user['display_name'] ?? 'Unknown User',
                      ),
                ),
              );
              // Mark messages as read and get updated count immediately
              if (mounted) {
                final count = await _chatService.markMessagesAsReadAndGetCount(
                  user['id'],
                );
                setState(() {
                  _directUnreadCounts[user['id']] = count;
                });
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildGroupList() {
    if (_groups.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: const Center(child: Text('No groups found. Create one!')),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _groups.length,
        itemBuilder: (context, index) {
          final group = _groups[index];
          final lastMessage = group['last_message'];
          final unreadCount = _groupUnreadCounts[group['id']] ?? 0;

          // Create subtitle with last message and sender
          String subtitle = '';
          if (lastMessage != null) {
            final currentUserId = Supabase.instance.client.auth.currentUser?.id;
            final senderName =
                lastMessage['sender_id'] == currentUserId
                    ? 'You'
                    : (lastMessage['sender_display_name'] ?? 'Unknown');
            subtitle = '$senderName: ${lastMessage['content']}';
          } else {
            subtitle = 'No messages yet';
          }

          return ListTile(
            leading: _buildGroupAvatar(
              group['name'] ?? 'Unknown Group',
              Theme.of(context),
            ),
            title: Text(
              group['name'] ?? 'Unknown Group',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    lastMessage != null
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lastMessage != null)
                  Text(
                    DateFormatter.formatChatListTimestamp(
                      lastMessage['created_at'],
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  UnreadBadge(count: unreadCount),
                ],
              ],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => GroupChatDetailScreen(
                        groupId: group['id'],
                        groupName: group['name'] ?? 'Unknown Group',
                      ),
                ),
              );
              // Mark group messages as read and get updated count immediately
              if (mounted) {
                final count = await _chatService
                    .markGroupMessagesAsReadAndGetCount(group['id']);
                setState(() {
                  _groupUnreadCounts[group['id']] = count;
                });
              }
            },
            onLongPress: () async {
              final isAdmin = await _chatService.isGroupAdmin(group['id']);
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (context) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('View Group Details'),
                          onTap: () async {
                            Navigator.pop(context);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => GroupManagementScreen(
                                      groupId: group['id'],
                                      groupName:
                                          group['name'] ?? 'Unknown Group',
                                    ),
                              ),
                            );
                            if (mounted) _refreshGroupsOnly();
                          },
                        ),
                        if (isAdmin) ...[
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('Edit Group'),
                            onTap: () async {
                              Navigator.pop(context);
                              final newName = await showDialog<String>(
                                context: context,
                                builder:
                                    (context) => EditGroupNameDialog(
                                      initialName:
                                          group['name'] ?? 'Unknown Group',
                                    ),
                              );
                              if (newName != null &&
                                  newName.isNotEmpty &&
                                  newName != group['name']) {
                                try {
                                  await _chatService.renameGroup(
                                    groupId: group['id'],
                                    newName: newName,
                                  );
                                  if (mounted) _refreshGroupsOnly();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Group renamed successfully!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error renaming group: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.delete,
                              color: Colors.red,
                            ),
                            title: const Text(
                              'Delete Group',
                              style: TextStyle(color: Colors.red),
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Delete Group?'),
                                      content: const Text(
                                        'Are you sure you want to delete this group and all its data? This cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                              );
                              if (confirm == true) {
                                try {
                                  await _chatService.deleteGroup(group['id']);
                                  if (mounted) _refreshGroupsOnly();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Group deleted successfully!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error deleting group: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Generate a unique gradient for each user based on their ID
  List<Color> _getUserGradient(String userId, ThemeData theme) {
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
  List<Color> _getGroupGradient(String groupName, ThemeData theme) {
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

  // Build user avatar with gradient background
  Widget _buildUserAvatar(String userId, String userName, ThemeData theme) {
    final gradient = _getUserGradient(userId, theme);

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
        radius: 20,
        backgroundColor: Colors.transparent,
        child: Text(
          userName[0].toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Build group avatar with gradient background
  Widget _buildGroupAvatar(String groupName, ThemeData theme) {
    final gradient = _getGroupGradient(groupName, theme);

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
        radius: 20,
        backgroundColor: Colors.transparent,
        child: Text(
          groupName[0].toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
