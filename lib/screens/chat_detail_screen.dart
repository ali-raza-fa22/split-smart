import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../utils/date_formatter.dart';
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
  final List<String> _selectedMessageIds = [];
  final Set<String> _locallyDeletedMessageIds = {};
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

  // Group messages by day
  List<Map<String, dynamic>> _getGroupedMessages() {
    final groupedMessages = <Map<String, dynamic>>[];

    DateTime? currentDay;

    final filteredForLocalDeletion = _messages.where(
      (msg) => !_locallyDeletedMessageIds.contains(msg['id']),
    );

    for (final message in filteredForLocalDeletion) {
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

        // Add the message
        groupedMessages.add({'type': 'message', 'data': message});
      } catch (e) {
        // Skip messages with invalid dates
        continue;
      }
    }

    return groupedMessages;
  }

  // Build day separator widget
  Widget _buildDaySeparator(String text, ThemeData theme) {
    return DateFormatter.buildDaySeparator(text, theme);
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

  void _onMessageTap(String messageId) {
    if (_selectedMessageIds.isNotEmpty) {
      setState(() {
        if (_selectedMessageIds.contains(messageId)) {
          _selectedMessageIds.remove(messageId);
        } else {
          _selectedMessageIds.add(messageId);
        }
      });
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
      final message = _messages.firstWhere((m) => m['id'] == msgId);
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

    if (deleteOption == 'everyone') {
      try {
        await Future.wait(
          _selectedMessageIds.map(
            (id) => _chatService.softDeleteDirectMessage(id),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting messages: $e')),
          );
        }
      } finally {
        _clearSelection();
      }
    } else if (deleteOption == 'me') {
      setState(() {
        _locallyDeletedMessageIds.addAll(_selectedMessageIds);
      });
      _clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final theme = Theme.of(context);

    return Scaffold(
      appBar:
          _selectedMessageIds.isNotEmpty
              ? _buildSelectionAppBar()
              : AppBar(
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
      body: GestureDetector(
        onTap: _selectedMessageIds.isNotEmpty ? _clearSelection : null,
        child: Column(
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
                              final isMe =
                                  message['sender_id'] == currentUserId;
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
                              final isDeleted = message['is_deleted'] == true;
                              final isSelected = _selectedMessageIds.contains(
                                message['id'],
                              );

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
                                      child: GestureDetector(
                                        onLongPress:
                                            isMe && !isDeleted
                                                ? () => _onMessageLongPress(
                                                  message['id'],
                                                )
                                                : null,
                                        onTap:
                                            () => _onMessageTap(message['id']),
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxWidth:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width *
                                                0.7,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                isSelected
                                                    ? theme
                                                        .colorScheme
                                                        .secondary
                                                        .withValues(alpha: 0.4)
                                                    : isMe
                                                    ? theme.colorScheme.primary
                                                    : theme
                                                        .colorScheme
                                                        .surfaceVariant,
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(
                                                20,
                                              ),
                                              topRight: const Radius.circular(
                                                20,
                                              ),
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
                                              if (isDeleted)
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.block,
                                                      size: 14,
                                                      color:
                                                          theme
                                                              .textTheme
                                                              .bodySmall
                                                              ?.color,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      message['content'],
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            fontStyle:
                                                                FontStyle
                                                                    .italic,
                                                          ),
                                                    ),
                                                  ],
                                                )
                                              else
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
                                                  DateFormatter.formatMessageTime(
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
                                            color:
                                                theme.colorScheme.onSecondary,
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
}
