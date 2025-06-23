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
  bool _isLoading = true;
  late TabController _tabController;
  StreamSubscription? _groupMessagesSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _checkEmailVerification();
    _loadData();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _groupMessagesSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh groups when app becomes active (user returns to app)
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshGroupsOnly();
    }
  }

  // Refresh groups when tab changes to groups tab
  void _onTabChanged() {
    if (_tabController.index == 1) {
      // Groups tab
      _refreshGroupsOnly();
    }
  }

  void _setupRealtimeSubscription() {
    // Listen for new group messages and update the group list automatically
    _groupMessagesSubscription = _chatService.getGroupMessagesStream().listen(
      (_) {
        // When a new message is detected, refresh the groups list
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
      if (mounted) {
        setState(() {
          _users = users;
          _groups = groups;
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
      if (mounted) {
        setState(() {
          _groups = groups;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SplitSmart'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
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
                  const PopupMenuDivider(),
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
            trailing:
                lastMessageTime != null
                    ? Text(
                      DateFormatter.formatChatListTimestamp(lastMessageTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    )
                    : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => ChatDetailScreen(
                        otherUserId: user['id'],
                        otherUserName: user['display_name'] ?? 'Unknown User',
                      ),
                ),
              );
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
            trailing:
                lastMessage != null
                    ? Text(
                      DateFormatter.formatChatListTimestamp(
                        lastMessage['created_at'],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    )
                    : null,
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
              // Refresh groups list when returning from group chat
              // This ensures updated group names are reflected
              if (mounted) {
                _refreshGroupsOnly();
              }
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
