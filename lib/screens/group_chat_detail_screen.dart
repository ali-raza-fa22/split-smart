import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import '../widgets/expense_details_modal.dart';
import 'group_management_screen.dart';
import 'add_expense_screen.dart';
import 'expenses_screen.dart';

class GroupChatDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatDetailScreen> createState() => _GroupChatDetailScreenState();
}

class _GroupChatDetailScreenState extends State<GroupChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Map<String, Map<String, dynamic>> _memberProfiles = {};
  bool _isLoadingMembers = true;
  List<Map<String, dynamic>> _currentMessages = [];
  StreamSubscription? _messagesSubscription;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadMemberProfiles();
    _loadInitialMessages();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMemberProfiles() async {
    try {
      final members = await _chatService.getGroupMembers(widget.groupId);
      final profiles = <String, Map<String, dynamic>>{};
      for (var member in members) {
        if (member['profiles'] != null) {
          profiles[member['user_id']] = member['profiles'];
        }
      }
      if (mounted) {
        setState(() {
          _memberProfiles = profiles;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading member info: $e')),
        );
      }
    }
  }

  Future<void> _loadInitialMessages() async {
    try {
      final messages = await _chatService.getGroupChatHistory(widget.groupId);
      if (mounted) {
        setState(() {
          _currentMessages = messages;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _setupRealtimeSubscription() {
    // Listen for real-time message updates
    _messagesSubscription = _chatService
        .getGroupMessagesStreamForGroup(widget.groupId)
        .listen((messages) {
          if (mounted) {
            setState(() {
              _currentMessages = messages;
            });
          }
        });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageContent = _messageController.text.trim();
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final timestamp = DateTime.now().toIso8601String();

    // Create a temporary message to show immediately
    final tempMessage = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'group_id': widget.groupId,
      'sender_id': currentUserId,
      'content': messageContent,
      'category': 'general',
      'created_at': timestamp,
    };

    // Add message to local list immediately
    setState(() {
      _currentMessages.add(tempMessage);
    });

    _messageController.clear();

    try {
      // Send the actual message
      await _chatService.sendGroupMessage(
        groupId: widget.groupId,
        content: messageContent,
        category: 'general',
      );

      // The real-time subscription will handle the update automatically
      // No need for manual intervention
    } catch (e) {
      // Remove the temporary message if sending failed
      setState(() {
        _currentMessages.removeWhere((m) => m['id'] == tempMessage['id']);
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
      }
    }

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredMessages() {
    if (_selectedCategory == 'all') {
      return _currentMessages;
    }
    return _currentMessages
        .where((message) => message['category'] == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final theme = Theme.of(context);
    final filteredMessages = _getFilteredMessages();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          // Category filter
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedCategory = value;
              });
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'all',
                    child: Row(
                      children: [
                        Icon(Icons.all_inbox),
                        SizedBox(width: 8),
                        Text('All Messages'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'general',
                    child: Row(
                      children: [
                        Icon(Icons.chat),
                        SizedBox(width: 8),
                        Text('General'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'expense',
                    child: Row(
                      children: [
                        Icon(Icons.receipt),
                        SizedBox(width: 8),
                        Text('Expenses'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'payment',
                    child: Row(
                      children: [
                        Icon(Icons.payment),
                        SizedBox(width: 8),
                        Text('Payments'),
                      ],
                    ),
                  ),
                ],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _selectedCategory == 'all'
                        ? Icons.all_inbox
                        : _selectedCategory == 'expense'
                        ? Icons.receipt
                        : _selectedCategory == 'payment'
                        ? Icons.payment
                        : Icons.chat,
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'expenses':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ExpensesScreen(
                            groupId: widget.groupId,
                            groupName: widget.groupName,
                          ),
                    ),
                  );
                  break;
                case 'add_expense':
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => AddExpenseScreen(
                            groupId: widget.groupId,
                            groupName: widget.groupName,
                          ),
                    ),
                  );
                  if (result == true) {
                    // Refresh messages if expense was added
                    _loadInitialMessages();
                  }
                  break;
                case 'manage':
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => GroupManagementScreen(
                            groupId: widget.groupId,
                            groupName: widget.groupName,
                          ),
                    ),
                  );
                  // If group was renamed, update the title
                  if (result != null && result is String) {
                    // You might want to update the group name in the parent widget
                    // For now, we'll just show a snackbar
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Group renamed to: $result')),
                      );
                    }
                  }
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'expenses',
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long),
                        SizedBox(width: 8),
                        Text('View Expenses'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'add_expense',
                    child: Row(
                      children: [
                        Icon(Icons.add),
                        SizedBox(width: 8),
                        Text('Add Expense'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'manage',
                    child: Row(
                      children: [
                        Icon(Icons.settings),
                        SizedBox(width: 8),
                        Text('Manage Group'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter indicator
          if (_selectedCategory != 'all')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.primaryContainer,
              child: Row(
                children: [
                  Icon(
                    _selectedCategory == 'expense'
                        ? Icons.receipt
                        : _selectedCategory == 'payment'
                        ? Icons.payment
                        : Icons.chat,
                    size: 16,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Showing ${_selectedCategory} messages',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 'all';
                      });
                    },
                    child: Text(
                      'Show All',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child:
                _isLoadingMembers
                    ? const Center(child: CircularProgressIndicator())
                    : filteredMessages.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedCategory == 'expense'
                                ? Icons.receipt_outlined
                                : _selectedCategory == 'payment'
                                ? Icons.payment_outlined
                                : Icons.chat_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedCategory == 'all'
                                ? 'No messages yet. Say hi!'
                                : 'No ${_selectedCategory} messages',
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredMessages.length,
                      itemBuilder: (context, index) {
                        final message =
                            filteredMessages[filteredMessages.length -
                                1 -
                                index];
                        final senderId = message['sender_id'];
                        final isMe = senderId == currentUserId;
                        final senderProfile = _memberProfiles[senderId];
                        final senderName =
                            senderProfile?['display_name'] ?? 'Unknown';

                        return _buildMessageBubble(
                          context,
                          message,
                          isMe,
                          senderName,
                          theme,
                        );
                      },
                    ),
          ),
          _buildMessageInput(theme),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    Map<String, dynamic> message,
    bool isMe,
    String senderName,
    ThemeData theme,
  ) {
    final category = message['category'] ?? 'general';
    final isExpense = category == 'expense';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildUserAvatar(message['sender_id'], senderName, theme),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onTap: isExpense ? () => _showExpenseDetails(message) : null,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      isExpense
                          ? theme.colorScheme.tertiaryContainer.withValues(
                            alpha: 0.3,
                          )
                          : isMe
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  border:
                      isExpense
                          ? Border.all(
                            color: theme.colorScheme.tertiary,
                            width: 1.5,
                          )
                          : null,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Text(
                        senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              isMe
                                  ? theme.colorScheme.onPrimary.withValues(
                                    alpha: 0.9,
                                  )
                                  : theme.colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    if (!isMe) const SizedBox(height: 4),
                    if (isExpense) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt,
                              size: 14,
                              color: theme.colorScheme.tertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Expense',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.tertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      message['content'],
                      style: TextStyle(
                        color:
                            isMe
                                ? theme.colorScheme.onPrimary
                                : isExpense
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
        theme.colorScheme.primary.withValues(alpha: 0.7),
      ], // Primary variants
      [
        theme.colorScheme.secondary,
        theme.colorScheme.secondary.withValues(alpha: 0.7),
      ], // Secondary variants
      [
        theme.colorScheme.tertiary,
        theme.colorScheme.tertiary.withValues(alpha: 0.7),
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
        theme.colorScheme.primary.withValues(alpha: 0.8),
        theme.colorScheme.secondary.withValues(alpha: 0.8),
      ], // Muted variants
    ];

    // Use the hash to select a consistent gradient for each user
    final index = (hash.abs() % colors.length);
    return colors[index];
  }

  // Get user avatar with gradient background
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
        radius: 16,
        backgroundColor: Colors.transparent,
        child: Text(
          userName[0].toUpperCase(),
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send,
                  size: 20,
                  color: theme.colorScheme.onPrimary,
                ),
                onPressed: _sendMessage,
                style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpenseDetails(Map<String, dynamic> message) {
    // Extract expense information from the message
    final expenseData = message['expense_data'] as Map<String, dynamic>?;
    if (expenseData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense details not available')),
      );
      return;
    }

    showExpenseDetailsModal(context, expenseData);
  }
}
