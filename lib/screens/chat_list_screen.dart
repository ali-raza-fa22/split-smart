import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/auth.dart';
import 'chat_detail_screen.dart';
import 'create_group_screen.dart';
import 'group_chat_detail_screen.dart';
import 'profile_screen.dart';
import 'stats_screen.dart';
import 'all_expenses_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

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
      final users = await _chatService.getUsers();
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
          return ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  user['avatar_url'] != null
                      ? NetworkImage(user['avatar_url'])
                      : null,
              child:
                  user['avatar_url'] == null
                      ? Text(user['display_name'][0].toUpperCase())
                      : null,
            ),
            title: Text(user['display_name'] ?? 'Unknown User'),
            subtitle: Text(user['username'] ?? ''),
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
                lastMessage['sender_id'] == currentUserId ? 'You' : 'Someone';
            subtitle = '$senderName: ${lastMessage['content']}';
          } else {
            subtitle = 'No messages yet';
          }

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                group['name'][0].toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                      _formatMessageTime(lastMessage['created_at']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    )
                    : null,
            onTap: () async {
              final result = await Navigator.push(
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

  String _formatMessageTime(String? createdAt) {
    if (createdAt == null) return '';

    try {
      final messageTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(messageTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'now';
      }
    } catch (e) {
      return '';
    }
  }
}
