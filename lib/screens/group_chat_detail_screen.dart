import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import 'group_management_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
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
          Expanded(
            child:
                _isLoadingMembers
                    ? const Center(child: CircularProgressIndicator())
                    : _currentMessages.isEmpty
                    ? const Center(child: Text('No messages yet. Say hi!'))
                    : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: _currentMessages.length,
                      itemBuilder: (context, index) {
                        final message =
                            _currentMessages[_currentMessages.length -
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
    // Format the message time

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
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isMe
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      senderName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            isMe
                                ? theme.colorScheme.onPrimary.withOpacity(0.8)
                                : theme.colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  if (!isMe) const SizedBox(height: 4),
                  Text(
                    message['content'],
                    style: TextStyle(
                      color:
                          isMe
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Generate a unique gradient for each user based on their ID
  List<Color> _getUserGradient(String userId) {
    // Create a hash from the user ID to get consistent colors
    final hash = userId.hashCode;
    final colors = [
      [Colors.blue, Colors.purple],
      [Colors.green, Colors.teal],
      [Colors.orange, Colors.red],
      [Colors.pink, Colors.purple],
      [Colors.indigo, Colors.blue],
      [Colors.teal, Colors.green],
      [Colors.red, Colors.orange],
      [Colors.purple, Colors.pink],
      [Colors.amber, Colors.orange],
      [Colors.cyan, Colors.blue],
    ];

    // Use the hash to select a consistent gradient for each user
    final index = (hash.abs() % colors.length);
    return colors[index];
  }

  // Get user avatar with gradient background
  Widget _buildUserAvatar(String userId, String userName, ThemeData theme) {
    final gradient = _getUserGradient(userId);

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
            color: Colors.white,
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send),
                color: theme.colorScheme.onPrimary,
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
