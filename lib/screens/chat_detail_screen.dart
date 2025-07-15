import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../utils/date_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../widgets/ui/brand_text_form_field.dart';
import '../utils/avatar_utils.dart';

class ChatDetailScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? avatarUrl;

  const ChatDetailScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.avatarUrl,
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
  StreamSubscription? _messagesSubscription;
  DateTime? _lastReadTimestamp;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadLastReadTimestamp();
    _markMessagesAsRead();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    // Listen for real-time message updates
    _messagesSubscription = _chatService
        .subscribeToMessages(widget.otherUserId)
        .listen((messages) {
          if (mounted) {
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
            // Mark messages as read in real-time
            _markMessagesAsRead();
          }
        }, onError: (error) {});
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.getChatHistory(widget.otherUserId);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        // Mark messages as read after loading
        _markMessagesAsRead();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLastReadTimestamp() async {
    try {
      _lastReadTimestamp = await _chatService.getLastReadTimestamp(
        widget.otherUserId,
      );
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _chatService.markMessagesAsReadAndGetCount(widget.otherUserId);
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
      // Real-time stream will handle the update automatically
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Something bad happened')));
      }
    }
  }

  // Group messages by day
  List<Map<String, dynamic>> _getGroupedMessages() {
    final groupedMessages = <Map<String, dynamic>>[];
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;

    DateTime? currentDay;
    bool unreadDividerAdded = false;

    // Filter out messages deleted for current user at database level
    final filteredForDatabaseDeletion = _messages.where((msg) {
      final deletedForUsers = List<String>.from(msg['deleted_for_users'] ?? []);
      return !deletedForUsers.contains(currentUserId);
    });

    // Filter out locally deleted messages (for UI consistency)
    final filteredForLocalDeletion = filteredForDatabaseDeletion.where(
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

  // Build day separator widget
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

    try {
      if (deleteOption == 'everyone') {
        // Delete for everyone - this will show "This message was deleted" for all users
        await Future.wait(
          _selectedMessageIds.map(
            (id) => _chatService.deleteMessageForEveryone(id),
          ),
        );
      } else if (deleteOption == 'me') {
        // Delete for me - this will hide the message from current user only
        await Future.wait(
          _selectedMessageIds.map((id) => _chatService.deleteMessageForMe(id)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete message')));
      }
    } finally {
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
                    AvatarUtils.buildUserAvatar(
                      widget.otherUserId,
                      widget.otherUserName,
                      theme,
                      radius: 20,
                      fontSize: 16,
                      avatarUrl: widget.avatarUrl,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.otherUserName,
                        overflow: TextOverflow.ellipsis,
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
                            } else if (item['type'] == 'unread_divider') {
                              return _buildUnreadDivider(theme);
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
                      child: BrandTextFormField(
                        controller: _messageController,
                        hintText: 'Type a message...',
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        borderRadius: 24.0,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        borderColor: theme.colorScheme.outline.withValues(
                          alpha: 0.2,
                        ),
                        focusedBorderColor: theme.colorScheme.primary,
                        prefixIcon: null,
                        suffixIcon: null,
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
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.3,
                            ),
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
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                        ),
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
