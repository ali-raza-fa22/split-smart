import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import '../utils/date_formatter.dart';
import '../widgets/expense_details_modal.dart';
import '../widgets/csv_export_button.dart';
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

class _GroupChatDetailScreenState extends State<GroupChatDetailScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Map<String, Map<String, dynamic>> _memberProfiles = {};
  List<Map<String, dynamic>> _membersInfo = [];
  Map<String, dynamic> _groupInfo = {};
  bool _isLoadingSummary = true;
  int _expensesCount = 0;
  List<Map<String, dynamic>> _currentMessages = [];
  StreamSubscription? _messagesSubscription;
  final List<String> _selectedMessageIds = [];
  final Set<String> _locallyDeletedMessageIds = {};
  String _selectedCategory = 'all';
  late String _currentGroupName;
  late TabController _tabController;
  DateTime? _lastReadTimestamp;

  @override
  void initState() {
    super.initState();
    _currentGroupName = widget.groupName;
    _tabController = TabController(length: 4, vsync: this);
    _loadGroupSummary();
    _loadInitialMessages();
    _loadLastReadTimestamp();
    _setupRealtimeSubscription();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh group name when dependencies change (e.g., when returning from other screens)
    _refreshGroupName();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupSummary() async {
    if (mounted) {
      setState(() {
        _isLoadingSummary = true;
      });
    }
    try {
      // Fetch all data in parallel
      final results = await Future.wait([
        _chatService.getGroupMembers(widget.groupId),
        _chatService.getGroupExpensesCount(widget.groupId),
        _chatService.getGroupInfo(widget.groupId),
      ]);

      final members = results[0] as List<Map<String, dynamic>>;
      final expenseCount = results[1] as int;
      final groupInfo = results[2] as Map<String, dynamic>?;

      final profiles = <String, Map<String, dynamic>>{};
      for (var member in members) {
        if (member['profiles'] != null) {
          profiles[member['user_id']] = member['profiles'];
        }
      }

      if (mounted) {
        setState(() {
          _membersInfo = members;
          _memberProfiles = profiles;
          _expensesCount = expenseCount;
          _groupInfo = groupInfo ?? {};
          _isLoadingSummary = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading group summary: $e')),
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
        // Mark group messages as read after loading
        _markGroupMessagesAsRead();
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadLastReadTimestamp() async {
    try {
      _lastReadTimestamp = await _chatService.getLastReadGroupTimestamp(
        widget.groupId,
      );
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
            // Mark group messages as read in real-time
            _markGroupMessagesAsRead();
          }
        });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageContent = _messageController.text.trim();
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;

    // Create a temporary message to show immediately
    final tempMessage = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'group_id': widget.groupId,
      'sender_id': currentUserId,
      'content': messageContent,
      'category': 'general',
      'created_at': DateTime.now().toUtc().toIso8601String(),
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
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;

    // Filter out messages deleted for current user at database level
    final filteredForDatabaseDeletion = _currentMessages.where((msg) {
      final deletedForUsers = List<String>.from(msg['deleted_for_users'] ?? []);
      return !deletedForUsers.contains(currentUserId);
    });

    // Filter out locally deleted messages (for UI consistency)
    final filteredForLocalDeletion = filteredForDatabaseDeletion.where(
      (msg) => !_locallyDeletedMessageIds.contains(msg['id']),
    );

    if (_selectedCategory == 'all') {
      return filteredForLocalDeletion.toList();
    }
    return filteredForLocalDeletion
        .where((message) => message['category'] == _selectedCategory)
        .toList();
  }

  // Group messages by day
  List<Map<String, dynamic>> _getGroupedMessages() {
    final filteredMessages = _getFilteredMessages();
    final groupedMessages = <Map<String, dynamic>>[];
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;

    DateTime? currentDay;
    bool unreadDividerAdded = false;

    for (final message in filteredMessages) {
      try {
        final messageTime = DateFormatter.parseMessageTimestamp(
          message['created_at'],
        );
        final messageDate = DateTime(
          messageTime.year,
          messageTime.month,
          messageTime.day,
        );

        // Add day separator if it's a new day
        if (currentDay == null ||
            !DateFormatter.isSameDay(currentDay, messageDate)) {
          groupedMessages.add({
            'type': 'day_separator',
            'date': messageDate,
            'display_text': DateFormatter.formatDaySeparator(messageDate),
          });
          currentDay = messageDate;
        }

        // Add unread divider if this is the first unread message
        if (!unreadDividerAdded &&
            _lastReadTimestamp != null &&
            messageTime.isAfter(_lastReadTimestamp!) &&
            message['sender_id'] != currentUserId) {
          groupedMessages.add({
            'type': 'unread_divider',
            'display_text': 'Unread messages',
          });
          unreadDividerAdded = true;
        }

        // Add the message
        groupedMessages.add({'type': 'message', 'data': message});
      } catch (e) {
        // Skip messages with invalid dates
        continue;
      }
    }

    return groupedMessages;
  }

  Future<void> _ensurePaymentMessagesExist() async {
    if (_selectedCategory == 'payment') {
      final paymentMessages = _getFilteredMessages();
      if (paymentMessages.isEmpty) {
        // Check if there are existing paid members without payment messages
        try {
          final existingPaidMembers = await _chatService
              .getExistingPaidMembersWithoutMessages(widget.groupId);
          if (existingPaidMembers.isNotEmpty) {
            // Show a dialog asking if user wants to generate payment messages
            if (mounted) {
              final shouldGenerate = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Existing Paid Members'),
                      content: Text(
                        'Found ${existingPaidMembers.length} existing payment(s) that don\'t have chat messages. Would you like to generate payment messages for them?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Generate'),
                        ),
                      ],
                    ),
              );

              if (shouldGenerate == true) {
                await _chatService
                    .generatePaymentMessagesForExistingPaidMembers(
                      widget.groupId,
                    );
                // Refresh messages after generating
                _loadInitialMessages();
              }
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error checking existing payments: $e')),
            );
          }
        }
      }
    }
  }

  void _onMessageLongPress(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  void _onMessageTap(Map<String, dynamic> message) {
    if (_selectedMessageIds.isNotEmpty) {
      setState(() {
        if (_selectedMessageIds.contains(message['id'])) {
          _selectedMessageIds.remove(message['id']);
        } else {
          _selectedMessageIds.add(message['id']);
        }
      });
    } else if (message['category'] == 'expense') {
      _showExpenseDetails(message);
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedMessageIds.clear();
    });
  }

  Future<void> _deleteMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final canDeleteForEveryone = _selectedMessageIds.every((msgId) {
      final message = _currentMessages.firstWhere((m) => m['id'] == msgId);
      return message['sender_id'] == currentUserId;
    });

    final deleteOption = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Delete ${_selectedMessageIds.length} message${_selectedMessageIds.length > 1 ? 's' : ''}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('me'),
                child: const Text('Delete for me'),
              ),
              if (canDeleteForEveryone)
                TextButton(
                  onPressed: () => Navigator.of(context).pop('everyone'),
                  child: const Text('Delete for Everyone'),
                ),
            ],
          ),
    );

    if (deleteOption == null) return;

    try {
      if (deleteOption == 'everyone') {
        // Delete for everyone - this will show "This message was deleted" for all users
        await Future.wait(
          _selectedMessageIds.map(
            (id) => _chatService.deleteGroupMessageForEveryone(id),
          ),
        );
      } else if (deleteOption == 'me') {
        // Delete for me - this will hide the message from current user only
        await Future.wait(
          _selectedMessageIds.map(
            (id) => _chatService.deleteGroupMessageForMe(id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting messages: $e')));
      }
    } finally {
      _clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final theme = Theme.of(context);
    final filteredMessages = _getFilteredMessages();
    final memberNames =
        _memberProfiles.values
            .map((profile) => profile['display_name'] as String? ?? 'Unknown')
            .toList();
    final subtitleText = memberNames.join(', ');

    return Scaffold(
      appBar:
          _selectedMessageIds.isNotEmpty
              ? _buildSelectionAppBar()
              : AppBar(
                title: GestureDetector(
                  onTap: _showGroupDetailsModal,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        child: Icon(
                          Icons.group,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentGroupName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitleText.isNotEmpty)
                              Text(
                                subtitleText,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  // Category filter
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      setState(() {
                        _selectedCategory = value;
                      });
                      // Check for existing paid members when payment filter is selected
                      if (value == 'payment') {
                        await _ensurePaymentMessagesExist();
                      }
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
                                    groupName: _currentGroupName,
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
                                    groupName: _currentGroupName,
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
                                    groupName: _currentGroupName,
                                  ),
                            ),
                          );
                          // If group was renamed, update the title
                          if (result != null && result is String) {
                            if (result == 'deleted') {
                              // Group was deleted, navigate back to chat list
                              if (mounted) {
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
                              }
                            } else {
                              // Group was renamed
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Group renamed to: $result'),
                                  ),
                                );
                              }
                              setState(() {
                                _currentGroupName = result;
                              });
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
      body: GestureDetector(
        onTap: _selectedMessageIds.isNotEmpty ? _clearSelection : null,
        child: Column(
          children: [
            // Category filter indicator
            if (_selectedCategory != 'all')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                  _isLoadingSummary
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
                                  : _selectedCategory == 'payment'
                                  ? 'No payment confirmations yet'
                                  : 'No ${_selectedCategory} messages',
                            ),
                            if (_selectedCategory == 'payment') ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await _ensurePaymentMessagesExist();
                                },
                                icon: const Icon(Icons.history),
                                label: const Text('Check Existing Payments'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.secondary,
                                  foregroundColor:
                                      theme.colorScheme.onSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                      : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: _getGroupedMessages().length,
                        itemBuilder: (context, index) {
                          final groupedMessages = _getGroupedMessages();
                          final item =
                              groupedMessages[groupedMessages.length -
                                  1 -
                                  index];

                          if (item['type'] == 'day_separator') {
                            return _buildDaySeparator(
                              item['display_text'],
                              theme,
                            );
                          } else if (item['type'] == 'unread_divider') {
                            return _buildUnreadDivider(theme);
                          } else {
                            final message = item['data'];
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
                          }
                        },
                      ),
            ),
            _buildMessageInput(theme),
          ],
        ),
      ),
    );
  }

  AppBar _buildSelectionAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _clearSelection,
      ),
      title: Text('${_selectedMessageIds.length} selected'),
      actions: [
        IconButton(icon: const Icon(Icons.delete), onPressed: _deleteMessages),
      ],
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
    final isPayment = category == 'payment';
    final isDeleted = message['is_deleted'] == true;
    final isSelected = _selectedMessageIds.contains(message['id']);

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
              onLongPress:
                  !isDeleted ? () => _onMessageLongPress(message['id']) : null,
              onTap: () => _onMessageTap(message),
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
                      isSelected
                          ? theme.colorScheme.inversePrimary.withValues(
                            alpha: 0.9,
                          )
                          : isExpense
                          ? theme.colorScheme.tertiaryContainer.withValues(
                            alpha: 0.3,
                          )
                          : isPayment
                          ? theme.colorScheme.secondaryContainer.withValues(
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
                          : isPayment
                          ? Border.all(
                            color: theme.colorScheme.secondary,
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
                                  ? theme.colorScheme.onPrimary.withOpacity(0.9)
                                  : theme.colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    if (!isMe) const SizedBox(height: 4),
                    if (isDeleted)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.block,
                            size: 14,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            message['content'],
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      )
                    else ...[
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
                      if (isPayment) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.payment,
                                size: 14,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                message['payment_data']?['is_historical'] ==
                                        true
                                    ? 'Historical Payment'
                                    : 'Payment',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Show payment details
                        if (message['payment_data'] != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withValues(
                                alpha: 0.05,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.secondary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 16,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Paid by: ${message['payment_data']['paid_by_name'] ?? 'Unknown'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.secondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.attach_money,
                                      size: 16,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Amount: Rs ${(message['payment_data']['amount_paid'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.secondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.receipt,
                                      size: 16,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'For: ${message['payment_data']['expense_title'] ?? 'Unknown Expense'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.secondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                      Text(
                        message['content'],
                        style: TextStyle(
                          color:
                              isMe
                                  ? theme.colorScheme.onPrimary.withOpacity(0.9)
                                  : isExpense
                                  ? theme.colorScheme.onSurface
                                  : isPayment
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    // Timestamp
                    Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Text(
                        DateFormatter.formatMessageTime(message['created_at']),
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              isMe
                                  ? theme.colorScheme.onPrimary.withValues(
                                    alpha: 0.7,
                                  )
                                  : theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                          fontWeight: FontWeight.w400,
                        ),
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

  Future<void> _refreshGroupName() async {
    try {
      final groupInfo = await _chatService.getGroupInfo(widget.groupId);
      if (groupInfo != null && groupInfo['name'] != _currentGroupName) {
        setState(() {
          _currentGroupName = groupInfo['name'];
        });
      }
    } catch (e) {
      // Silently handle errors - group name refresh is not critical
    }
  }

  Widget _buildDaySeparator(String text, ThemeData theme) {
    return DateFormatter.buildDaySeparator(text, theme);
  }

  // Build unread divider widget
  Widget _buildUnreadDivider(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'Unread messages',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupDetailsModal() {
    final theme = Theme.of(context);
    final groupCreatedAt =
        _groupInfo['created_at'] != null
            ? DateTime.parse(_groupInfo['created_at'])
            : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.group,
                      size: 40,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _currentGroupName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (groupCreatedAt != null) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Created on ${DateFormatter.formatDate(groupCreatedAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        theme,
                        Icons.group_outlined,
                        '${_membersInfo.length}',
                        'Members',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        theme,
                        Icons.receipt_long_outlined,
                        '$_expensesCount',
                        'Expenses',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Export CSV Button
                if (_expensesCount > 0)
                  Container(
                    width: double.infinity,
                    child: CsvExportButton(
                      groupId: widget.groupId,
                      groupName: _currentGroupName,
                      expensesCount: _expensesCount,
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Members',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(height: 16),
                ..._membersInfo.map((member) {
                  final profile = member['profiles'];
                  if (profile == null) return const SizedBox.shrink();

                  final userId = member['user_id'];
                  final displayName = profile['display_name'] ?? 'Unknown';
                  final isAdmin = member['is_admin'] ?? false;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _buildUserAvatar(userId, displayName, theme),
                    title: Text(displayName),
                    trailing:
                        isAdmin
                            ? Text(
                              "Admin",
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                            : null,
                  );
                }).toList(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Future<void> _markGroupMessagesAsRead() async {
    try {
      await _chatService.markGroupMessagesAsRead(widget.groupId);
    } catch (e) {
      // Handle error silently
    }
  }
}
