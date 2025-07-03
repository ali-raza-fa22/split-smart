import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/auth.dart';
import 'chat_detail_screen.dart';
import 'create_group_screen.dart';
import 'group_chat_detail_screen.dart';
import 'dart:async';
import 'verify_email_screen.dart';
import '../widgets/chat_list_item.dart';
import '../widgets/empty_chat_state.dart';
import '../widgets/group_actions_bottom_sheet.dart';
import 'package:split_smart_supabase/widgets/ui/main_scaffold.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You may press on Resend Code to get a new code'),
        ),
      );
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
    return MainScaffold(
      currentIndex: 2,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [Tab(text: 'Direct'), Tab(text: 'Groups')],
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
        child: EmptyChatState.forDirectChats(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final unreadCount = _directUnreadCounts[user['id']] ?? 0;

          return ChatListItem(
            id: user['id'],
            name: user['display_name'] ?? 'Unknown User',
            lastMessage: user['last_message_content'],
            lastMessageSenderName: user['last_message_sender_display_name'],
            lastMessageSenderId: user['last_message_sender_id'],
            lastMessageTime: user['last_message_created_at'],
            unreadCount: unreadCount,
            isGroup: false,
            onTap: () => _onUserTap(user),
          );
        },
      ),
    );
  }

  Widget _buildGroupList() {
    if (_groups.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: EmptyChatState.forGroups(
          onActionPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateGroupScreen(),
              ),
            );
            if (result != false && mounted) {
              _loadData();
            }
          },
        ),
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

          return ChatListItem(
            id: group['id'],
            name: group['name'] ?? 'Unknown Group',
            lastMessage: lastMessage?['content'],
            lastMessageSenderName: lastMessage?['sender_display_name'],
            lastMessageSenderId: lastMessage?['sender_id'],
            lastMessageTime: lastMessage?['created_at'],
            unreadCount: unreadCount,
            isGroup: true,
            onTap: () => _onGroupTap(group),
            onLongPress: () => _onGroupLongPress(group),
          );
        },
      ),
    );
  }

  Future<void> _onUserTap(Map<String, dynamic> user) async {
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
  }

  Future<void> _onGroupTap(Map<String, dynamic> group) async {
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
      final count = await _chatService.markGroupMessagesAsReadAndGetCount(
        group['id'],
      );
      setState(() {
        _groupUnreadCounts[group['id']] = count;
      });
    }
  }

  void _onGroupLongPress(Map<String, dynamic> group) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => GroupActionsBottomSheet(
            groupId: group['id'],
            groupName: group['name'] ?? 'Unknown Group',
            onGroupUpdated: _refreshGroupsOnly,
            onGroupDeleted: _refreshGroupsOnly,
          ),
    );
  }
}
