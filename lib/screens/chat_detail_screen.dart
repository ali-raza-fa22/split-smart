import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class ChatDetailScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatDetailScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markMessagesAsRead();
    // Start polling every 2 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.getChatHistory(widget.otherUserId);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      // Scroll to bottom after messages load
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _chatService.markMessagesAsRead(widget.otherUserId);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      await _chatService.sendMessage(
        receiverId: widget.otherUserId,
        content: _messageController.text.trim(),
      );
      _messageController.clear();
      _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
      }
    }
  }

  // Format timestamp for message bubbles (WhatsApp style)
  String _formatMessageTime(String? createdAt) {
    if (createdAt == null) return '';

    try {
      final messageTime = DateTime.parse(createdAt);
      // Only show time (e.g., "2:30 PM")
      return _formatTime(messageTime);
    } catch (e) {
      return '';
    }
  }

  // Format time (e.g., "2:30 PM")
  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  // Format date (e.g., "Jan 15")
  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  // Get day name (e.g., "Monday")
  String _getDayName(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[date.weekday - 1];
  }

  // Format day separator (e.g., "Today", "Yesterday", "Monday, January 15")
  String _formatDaySeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return _getDayName(date);
    } else {
      return _formatDate(date);
    }
  }

  // Group messages by day
  List<Map<String, dynamic>> _getGroupedMessages() {
    final groupedMessages = <Map<String, dynamic>>[];

    DateTime? currentDay;

    for (final message in _messages) {
      try {
        final messageTime = DateTime.parse(message['created_at'] ?? '');
        final messageDate = DateTime(
          messageTime.year,
          messageTime.month,
          messageTime.day,
        );

        // Add day separator if it's a new day
        if (currentDay == null || !_isSameDay(currentDay, messageDate)) {
          groupedMessages.add({
            'type': 'day_separator',
            'date': messageDate,
            'display_text': _formatDaySeparator(messageDate),
          });
          currentDay = messageDate;
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

  // Check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Build day separator widget
  Widget _buildDaySeparator(String text, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                widget.otherUserName.isNotEmpty
                    ? widget.otherUserName[0].toUpperCase()
                    : '?',
                style: TextStyle(color: theme.colorScheme.onPrimary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Online',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        image: const DecorationImage(
                          image: AssetImage('assets/chat_bg.jpg'),
                          opacity: 0.1,
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: ListView.builder(
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
                          } else {
                            final message = item['data'];
                            final isMe = message['sender_id'] == currentUserId;
                            final showAvatar =
                                index == groupedMessages.length - 1 ||
                                (groupedMessages[groupedMessages.length -
                                            2 -
                                            index]['type'] ==
                                        'message' &&
                                    groupedMessages[groupedMessages.length -
                                            2 -
                                            index]['data']['sender_id'] !=
                                        message['sender_id']);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment:
                                    isMe
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (!isMe && showAvatar) ...[
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                      child: Text(
                                        widget.otherUserName[0].toUpperCase(),
                                        style: TextStyle(
                                          color: theme.colorScheme.onPrimary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                            0.7,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isMe
                                                ? theme.colorScheme.primary
                                                : theme
                                                    .colorScheme
                                                    .surfaceVariant,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(20),
                                          topRight: const Radius.circular(20),
                                          bottomLeft: Radius.circular(
                                            isMe ? 20 : 4,
                                          ),
                                          bottomRight: Radius.circular(
                                            isMe ? 4 : 20,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            message['content'],
                                            style: TextStyle(
                                              color:
                                                  isMe
                                                      ? theme
                                                          .colorScheme
                                                          .onPrimary
                                                      : theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Timestamp
                                          Align(
                                            alignment:
                                                isMe
                                                    ? Alignment.centerRight
                                                    : Alignment.centerLeft,
                                            child: Text(
                                              _formatMessageTime(
                                                message['created_at'],
                                              ),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    isMe
                                                        ? theme
                                                            .colorScheme
                                                            .onPrimary
                                                            .withValues(
                                                              alpha: 0.7,
                                                            )
                                                        : theme
                                                            .colorScheme
                                                            .onSurfaceVariant
                                                            .withValues(
                                                              alpha: 0.7,
                                                            ),
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isMe && showAvatar) ...[
                                    const SizedBox(width: 8),
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor:
                                          theme.colorScheme.secondary,
                                      child: Text(
                                        'Me',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
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
          ),
        ],
      ),
    );
  }
}
