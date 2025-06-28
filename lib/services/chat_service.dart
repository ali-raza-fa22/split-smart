import 'package:split_smart_supabase/utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'balance_service.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final BalanceService _balanceService = BalanceService();

  // Get all users except current user
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .neq('id', _supabase.auth.currentUser!.id);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  // Get all users with their last message
  Future<List<Map<String, dynamic>>> getUsersWithLastMessage() async {
    try {
      final response = await _supabase.rpc(
        'get_user_chats_with_last_message',
        params: {'current_user_id': _supabase.auth.currentUser!.id},
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  // Create a new group
  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    try {
      if (memberIds.length > AppConstants.maxMembersAllowed) {
        throw Exception(
          'Group can have maximum ${AppConstants.maxMembersAllowed} more members',
        );
      }

      // Create the group
      final groupResponse =
          await _supabase
              .from('groups')
              .insert({
                'name': name,
                'created_by': _supabase.auth.currentUser!.id,
                'created_at': DateTime.now().toUtc().toIso8601String(),
              })
              .select('id')
              .single();

      final groupId = groupResponse['id'];

      // Add members to the group
      final members = [
        {
          'group_id': groupId,
          'user_id': _supabase.auth.currentUser!.id,
          'is_admin': true,
        }, // Add creator
        ...memberIds.map(
          (id) => {'group_id': groupId, 'user_id': id, 'is_admin': false},
        ),
      ];

      await _supabase.from('group_members').insert(members);

      return groupId;
    } catch (e) {
      rethrow;
    }
  }

  // Get user's groups
  Future<List<Map<String, dynamic>>> getUserGroups() async {
    try {
      final response = await _supabase
          .from('groups')
          .select('*, group_members!inner(*)')
          .eq('group_members.user_id', _supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  // Get group members
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    try {
      // First get group members
      final membersResponse = await _supabase
          .from('group_members')
          .select('*')
          .eq('group_id', groupId);

      if (membersResponse.isEmpty) {
        return [];
      }

      // Get user IDs from members
      final userIds =
          membersResponse.map((member) => member['user_id']).toList();

      // Get profiles for these users
      final profilesResponse = await _supabase
          .from('profiles')
          .select('*')
          .inFilter('id', userIds);

      // Create a map of user_id to profile
      final profilesMap = <String, Map<String, dynamic>>{};
      for (final profile in profilesResponse) {
        profilesMap[profile['id']] = profile;
      }

      // Combine members with their profiles
      final result = <Map<String, dynamic>>[];
      for (final member in membersResponse) {
        final profile = profilesMap[member['user_id']];
        result.add({...member, 'profiles': profile ?? {}});
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Get group chat history
  Future<List<Map<String, dynamic>>> getGroupChatHistory(String groupId) async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;

      // First get group messages
      final messagesResponse = await _supabase
          .from('group_messages')
          .select('*')
          .eq('group_id', groupId)
          .order('created_at', ascending: true);

      if (messagesResponse.isEmpty) {
        return [];
      }

      // Filter out messages deleted for current user only (but keep messages deleted for everyone)
      final nonDeletedMessages =
          messagesResponse.where((message) {
            final deletedForUsers = List<String>.from(
              message['deleted_for_users'] ?? [],
            );

            // Exclude messages deleted for current user only
            if (deletedForUsers.contains(currentUserId)) return false;

            return true;
          }).toList();

      if (nonDeletedMessages.isEmpty) {
        return [];
      }

      // Get sender IDs from messages
      final senderIds =
          nonDeletedMessages
              .map((message) => message['sender_id'] as String)
              .toSet()
              .toList();

      // Get profiles for all senders
      final profilesResponse = await _supabase
          .from('profiles')
          .select('*')
          .inFilter('id', senderIds);

      // Create a map of sender_id to profile
      final profilesMap = <String, Map<String, dynamic>>{};
      for (final profile in profilesResponse) {
        profilesMap[profile['id']] = profile;
      }

      // Combine messages with profiles
      final result = <Map<String, dynamic>>[];
      for (final message in nonDeletedMessages) {
        final senderProfile = profilesMap[message['sender_id']];
        result.add({...message, 'profiles': senderProfile ?? {}});
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Send a message to group
  Future<void> sendGroupMessage({
    required String groupId,
    required String content,
    String category = 'general',
    Map<String, dynamic>? expenseData,
    Map<String, dynamic>? paymentData,
  }) async {
    try {
      final timestamp = DateTime.now().toUtc().toIso8601String();

      await _supabase.from('group_messages').insert({
        'group_id': groupId,
        'sender_id': _supabase.auth.currentUser!.id,
        'content': content,
        'category': category,
        'created_at': timestamp,
        'expense_data': expenseData,
        'payment_data': paymentData,
      });

      // Small delay to ensure database has processed the insert
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      rethrow;
    }
  }

  // Get direct chat history between two users
  Future<List<Map<String, dynamic>>> getChatHistory(String otherUserId) async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('messages')
          .select()
          .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
          .or('sender_id.eq.$otherUserId,receiver_id.eq.$otherUserId')
          .order('created_at', ascending: true);

      // Client-side filtering to ensure we only get messages between these two users
      // and exclude messages deleted for the current user only
      final filteredResponse =
          response.where((message) {
            final senderId = message['sender_id'];
            final receiverId = message['receiver_id'];
            final deletedForUsers = List<String>.from(
              message['deleted_for_users'] ?? [],
            );

            // Exclude messages deleted for current user only (but keep messages deleted for everyone)
            if (deletedForUsers.contains(currentUserId)) return false;

            // Ensure message is between the two users
            return (senderId == currentUserId && receiverId == otherUserId) ||
                (senderId == otherUserId && receiverId == currentUserId);
          }).toList();

      return List<Map<String, dynamic>>.from(filteredResponse);
    } catch (e) {
      rethrow;
    }
  }

  // Send a direct message
  Future<void> sendMessage({
    required String receiverId,
    required String content,
  }) async {
    try {
      await _supabase.from('messages').insert({
        'sender_id': _supabase.auth.currentUser!.id,
        'receiver_id': receiverId,
        'content': content,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Mark messages as read (backward compatibility)
  Future<void> markMessagesAsRead(String senderId) async {
    try {
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('sender_id', senderId)
          .eq('receiver_id', _supabase.auth.currentUser!.id)
          .eq('is_read', false);
    } catch (e) {
      rethrow;
    }
  }

  // Mark messages as read and return updated unread count
  Future<int> markMessagesAsReadAndGetCount(String senderId) async {
    try {
      final result = await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('sender_id', senderId)
          .eq('receiver_id', _supabase.auth.currentUser!.id)
          .eq('is_read', false);

      // Return the updated unread count immediately
      final count = await getUnreadDirectMessageCount(senderId);
      return count;
    } catch (e) {
      rethrow;
    }
  }

  // Mark group messages as read and return updated unread count
  Future<int> markGroupMessagesAsReadAndGetCount(String groupId) async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;

      // Get all messages in the group not sent by current user
      final allMessages = await _supabase
          .from('group_messages')
          .select('id')
          .eq('group_id', groupId)
          .not('sender_id', 'eq', currentUserId);

      if (allMessages.isNotEmpty) {
        final messageIds = allMessages.map((m) => m['id'] as String).toList();

        // Get existing read receipts for these messages
        final existingReads = await _supabase
            .from('group_message_reads')
            .select('message_id')
            .eq('user_id', currentUserId)
            .inFilter('message_id', messageIds);

        final existingReadMessageIds =
            existingReads.map((r) => r['message_id'] as String).toSet();

        // Only insert read receipts for messages that don't already have them
        final unreadMessageIds =
            messageIds
                .where((id) => !existingReadMessageIds.contains(id))
                .toList();

        if (unreadMessageIds.isNotEmpty) {
          // Create read records for unread messages only
          final inserts =
              unreadMessageIds
                  .map(
                    (messageId) => {
                      'message_id': messageId,
                      'user_id': currentUserId,
                      'read_at': DateTime.now().toUtc().toIso8601String(),
                    },
                  )
                  .toList();

          await _supabase.from('group_message_reads').insert(inserts);
        }
      }

      // Return the updated unread count immediately
      final count = await getUnreadGroupMessageCount(groupId);
      return count;
    } catch (e) {
      // Handle error silently and return current count
      return await getUnreadGroupMessageCount(groupId);
    }
  }

  // Mark group messages as read (backward compatibility)
  Future<void> markGroupMessagesAsRead(String groupId) async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;

      // Get all messages in the group not sent by current user
      final allMessages = await _supabase
          .from('group_messages')
          .select('id')
          .eq('group_id', groupId)
          .not('sender_id', 'eq', currentUserId);

      if (allMessages.isNotEmpty) {
        final messageIds = allMessages.map((m) => m['id'] as String).toList();

        // Get existing read receipts for these messages
        final existingReads = await _supabase
            .from('group_message_reads')
            .select('message_id')
            .eq('user_id', currentUserId)
            .inFilter('message_id', messageIds);

        final existingReadMessageIds =
            existingReads.map((r) => r['message_id'] as String).toSet();

        // Only insert read receipts for messages that don't already have them
        final unreadMessageIds =
            messageIds
                .where((id) => !existingReadMessageIds.contains(id))
                .toList();

        if (unreadMessageIds.isNotEmpty) {
          // Create read records for unread messages only
          final inserts =
              unreadMessageIds
                  .map(
                    (messageId) => {
                      'message_id': messageId,
                      'user_id': currentUserId,
                      'read_at': DateTime.now().toUtc().toIso8601String(),
                    },
                  )
                  .toList();

          await _supabase.from('group_message_reads').insert(inserts);
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // Real-time stream for message read status changes
  Stream<void> getMessageReadStatusStream() {
    final userId = _supabase.auth.currentUser!.id;
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .map((event) {
          // Check if any messages were marked as read
          final hasReadStatusChange = event.any((message) {
            final isRead = message['is_read'] ?? false;
            final receiverId = message['receiver_id'] as String;
            // Only trigger if message is marked as read and is for current user
            return isRead && receiverId == userId;
          });

          // Return a value only if there's a read status change
          if (hasReadStatusChange) {
            return true;
          }
          return null;
        })
        .where((event) => event != null) // Only emit non-null events
        .map((_) => null) // Convert to void stream
        .handleError((error) {
          // Handle errors silently to prevent stream from breaking
          return;
        });
  }

  // Real-time stream for group message read status changes
  Stream<void> getGroupMessageReadStatusStream() {
    final userId = _supabase.auth.currentUser!.id;
    return _supabase
        .from('group_message_reads')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((event) {
          // Any new read record should trigger an update
          return;
        })
        .handleError((error) {
          // Handle errors silently to prevent stream from breaking
          return;
        });
  }

  // Get unread message count
  Future<int> getUnreadMessageCount() async {
    try {
      final response = await _supabase
          .from('messages')
          .select('id')
          .eq('receiver_id', _supabase.auth.currentUser!.id)
          .eq('is_read', false);

      // Filter out deleted messages
      final nonDeletedMessages =
          response.where((message) {
            final isDeleted = message['is_deleted'] ?? false;
            return !isDeleted;
          }).toList();

      return nonDeletedMessages.length;
    } catch (e) {
      return 0;
    }
  }

  // Subscribe to group messages with real-time updates
  Stream<List<Map<String, dynamic>>> subscribeToGroupMessages(String groupId) {
    final currentUserId = _supabase.auth.currentUser!.id;
    return _supabase
        .from('group_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at', ascending: true)
        .map((rows) {
          // Filter out messages deleted for current user only (but keep messages deleted for everyone)
          final messages =
              rows
                  .where((row) {
                    // Exclude messages deleted for current user only
                    final deletedForUsers = List<String>.from(
                      row['deleted_for_users'] ?? [],
                    );
                    if (deletedForUsers.contains(currentUserId)) return false;

                    return true;
                  })
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList();
          return messages;
        })
        .handleError((error) {
          return <Map<String, dynamic>>[];
        });
  }

  // Subscribe to direct messages
  Stream<List<Map<String, dynamic>>> subscribeToMessages(String otherUserId) {
    final userId = _supabase.auth.currentUser!.id;
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((rows) {
          // Filter out messages deleted for current user only (but keep messages deleted for everyone)
          return rows
              .where((row) {
                // Exclude messages deleted for current user only
                final deletedForUsers = List<String>.from(
                  row['deleted_for_users'] ?? [],
                );
                if (deletedForUsers.contains(userId)) return false;

                // Ensure message is between the two users
                final senderId = row['sender_id'];
                final receiverId = row['receiver_id'];
                return (senderId == userId && receiverId == otherUserId) ||
                    (senderId == otherUserId && receiverId == userId);
              })
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
        })
        .handleError((error) {
          return <Map<String, dynamic>>[];
        });
  }

  // Check if current user is admin of a group
  Future<bool> isGroupAdmin(String groupId) async {
    try {
      final response =
          await _supabase
              .from('group_members')
              .select('is_admin')
              .eq('group_id', groupId)
              .eq('user_id', _supabase.auth.currentUser!.id)
              .single();
      return response['is_admin'] ?? false;
    } catch (e) {
      return false;
    }
  }

  // Add member to group (admin only)
  Future<void> addMemberToGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      // Check if current user is admin
      final isAdmin = await isGroupAdmin(groupId);
      if (!isAdmin) {
        throw Exception('Only admins can add members to the group');
      }

      // Check if group already has max members
      final currentMembers = await getGroupMembers(groupId);
      if (currentMembers.length >= AppConstants.maxMembersAllowed) {
        throw Exception('Group already has maximum members');
      }

      // Check if user is already a member
      final isAlreadyMember = currentMembers.any(
        (member) => member['user_id'] == userId,
      );
      if (isAlreadyMember) {
        throw Exception('User is already a member of this group');
      }

      await _supabase.from('group_members').insert({
        'group_id': groupId,
        'user_id': userId,
        'is_admin': false,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Remove member from group (admin only)
  Future<void> removeMemberFromGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      // Check if current user is admin
      final isAdmin = await isGroupAdmin(groupId);
      if (!isAdmin) {
        throw Exception('Only admins can remove members from the group');
      }

      // Prevent admin from removing themselves
      if (userId == _supabase.auth.currentUser!.id) {
        throw Exception('Admin cannot remove themselves from the group');
      }

      await _supabase
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }

  // Rename group (admin only)
  Future<void> renameGroup({
    required String groupId,
    required String newName,
  }) async {
    try {
      // Check if current user is admin
      final isAdmin = await isGroupAdmin(groupId);
      if (!isAdmin) {
        throw Exception('Only admins can rename the group');
      }

      if (newName.trim().isEmpty) {
        throw Exception('Group name cannot be empty');
      }

      await _supabase
          .from('groups')
          .update({'name': newName.trim()})
          .eq('id', groupId);
    } catch (e) {
      rethrow;
    }
  }

  // Delete group and all related data (admin only)
  Future<void> deleteGroup(String groupId) async {
    try {
      // Check if current user is admin
      final isAdmin = await isGroupAdmin(groupId);
      if (!isAdmin) {
        throw Exception('Only admins can delete the group');
      }

      // Delete in the correct order to respect foreign key constraints
      // 1. Get expense IDs first, then delete expense shares
      final expenseIds = await _supabase
          .from('expenses')
          .select('id')
          .eq('group_id', groupId);

      if (expenseIds.isNotEmpty) {
        final expenseIdList = expenseIds.map((e) => e['id']).toList();
        await _supabase
            .from('expense_shares')
            .delete()
            .inFilter('expense_id', expenseIdList);
      }

      // 2. Delete expenses
      await _supabase.from('expenses').delete().eq('group_id', groupId);

      // 3. Delete group messages
      await _supabase.from('group_messages').delete().eq('group_id', groupId);

      // 4. Delete group members
      await _supabase.from('group_members').delete().eq('group_id', groupId);

      // 5. Finally delete the group itself
      await _supabase.from('groups').delete().eq('id', groupId);
    } catch (e) {
      rethrow;
    }
  }

  // Test if user can send messages to group (for debugging RLS policies)
  Future<bool> canSendMessageToGroup(String groupId) async {
    try {
      // Check if user is a member of the group
      final response =
          await _supabase
              .from('group_members')
              .select('id')
              .eq('group_id', groupId)
              .eq('user_id', _supabase.auth.currentUser!.id)
              .single();
      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get available users to add to group (users not already in the group)
  Future<List<Map<String, dynamic>>> getAvailableUsersForGroup(
    String groupId,
  ) async {
    try {
      final currentMembers = await getGroupMembers(groupId);
      final currentMemberIds =
          currentMembers.map((member) => member['user_id']).toList();

      final allUsers = await getUsers();
      return allUsers
          .where((user) => !currentMemberIds.contains(user['id']))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Debug method to test message sending and receiving
  Future<Map<String, dynamic>> testMessageFlow(String groupId) async {
    try {
      // Test sending a message
      await sendGroupMessage(
        groupId: groupId,
        content: 'Test message ${DateTime.now().millisecondsSinceEpoch}',
      );

      // Test getting messages
      final messages = await getGroupChatHistory(groupId);

      // Test getting members
      final members = await getGroupMembers(groupId);

      return {
        'success': true,
        'message_sent': true,
        'messages_count': messages.length,
        'members_count': members.length,
        'current_user': _supabase.auth.currentUser?.id,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'current_user': _supabase.auth.currentUser?.id,
      };
    }
  }

  // Simple test to check if tables exist and are accessible
  Future<String> testTableAccess() async {
    try {
      // Test each table individually
      await _supabase.from('profiles').select('count').limit(1);
      await _supabase.from('groups').select('count').limit(1);
      await _supabase.from('group_members').select('count').limit(1);
      await _supabase.from('group_messages').select('count').limit(1);

      return 'All tables are accessible';
    } catch (e) {
      return 'Error: $e';
    }
  }

  // Debug method to test database connectivity and table existence
  Future<Map<String, dynamic>> debugDatabaseConnection() async {
    try {
      // Test profiles table
      final profilesTest = await _supabase
          .from('profiles')
          .select('count')
          .limit(1);

      // Test groups table
      final groupsTest = await _supabase
          .from('groups')
          .select('count')
          .limit(1);

      // Test group_members table
      final groupMembersTest = await _supabase
          .from('group_members')
          .select('count')
          .limit(1);

      // Test group_messages table
      final groupMessagesTest = await _supabase
          .from('group_messages')
          .select('count')
          .limit(1);

      return {
        'profiles': profilesTest.isNotEmpty,
        'groups': groupsTest.isNotEmpty,
        'group_members': groupMembersTest.isNotEmpty,
        'group_messages': groupMessagesTest.isNotEmpty,
        'current_user': _supabase.auth.currentUser?.id,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'current_user': _supabase.auth.currentUser?.id,
      };
    }
  }

  // Test real-time subscription
  Stream<List<Map<String, dynamic>>> testGroupMessagesStream(String groupId) {
    return _supabase
        .from('group_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at', ascending: true)
        .map((rows) {
          return rows.map((row) => Map<String, dynamic>.from(row)).toList();
        });
  }

  // Get user's groups with last message and member info
  Future<List<Map<String, dynamic>>> getUserGroupsWithDetails() async {
    try {
      final groups = await getUserGroups();
      final groupsWithDetails = <Map<String, dynamic>>[];
      final currentUserId = _supabase.auth.currentUser!.id;

      for (final group in groups) {
        try {
          // Get last message
          final messagesResponse = await _supabase
              .from('group_messages')
              .select('*')
              .eq('group_id', group['id'])
              .order('created_at', ascending: false)
              .limit(
                10,
              ); // Get more messages to ensure we find a non-deleted one

          // Filter out messages deleted for current user at database level
          final nonDeletedMessages =
              messagesResponse.where((message) {
                final isDeleted = message['is_deleted'] ?? false;
                final deletedForUsers = List<String>.from(
                  message['deleted_for_users'] ?? [],
                );

                // Exclude messages deleted for everyone (is_deleted = true)
                if (isDeleted) return false;

                // Exclude messages deleted for current user only
                if (deletedForUsers.contains(currentUserId)) return false;

                return true;
              }).toList();

          Map<String, dynamic>? lastMessageWithSender;
          if (nonDeletedMessages.isNotEmpty) {
            final lastMessage =
                nonDeletedMessages.first; // Most recent non-deleted message

            // Fetch sender's profile
            final senderProfile =
                await _supabase
                    .from('profiles')
                    .select('display_name')
                    .eq('id', lastMessage['sender_id'])
                    .maybeSingle();
            lastMessageWithSender = {
              ...lastMessage,
              'sender_display_name':
                  senderProfile != null
                      ? senderProfile['display_name']
                      : 'Unknown',
            };
          }

          // Get all members for this group
          final members = await getGroupMembers(group['id']);

          // Get member names (first 3 members)
          final memberNames = <String>[];
          for (int i = 0; i < members.length && i < 3; i++) {
            final member = members[i];
            if (member['profiles'] != null) {
              memberNames.add(member['profiles']['display_name'] ?? 'Unknown');
            } else {
              memberNames.add('Unknown');
            }
          }

          groupsWithDetails.add({
            ...group,
            'last_message': lastMessageWithSender,
            'member_names': memberNames,
            'member_count': members.length,
          });
        } catch (e) {
          // If there's an error getting details, just add the basic group info
          groupsWithDetails.add({
            ...group,
            'last_message': null,
            'member_count': 0,
            'member_names': [],
          });
        }
      }

      return groupsWithDetails;
    } catch (e) {
      rethrow;
    }
  }

  // Real-time stream for group messages that will trigger group list updates
  Stream<void> getGroupMessagesStream() {
    final userId = _supabase.auth.currentUser!.id;
    return _supabase
        .from('group_messages')
        .stream(primaryKey: ['id'])
        .map((event) {
          // Filter to only trigger updates for messages in groups where user is a member
          // This is a simplified check - in a production app, you might want to cache user's groups
          // So we'll trigger for all non-deleted messages and let the UI handle filtering
          final hasRelevantMessage = event.any((message) {
            final isDeleted = message['is_deleted'] ?? false;

            // Only trigger if message is not deleted
            return !isDeleted;
          });

          // Only emit if there's a relevant message
          if (hasRelevantMessage) {
            return;
          }
        })
        .handleError((error) {
          // Handle errors silently to prevent stream from breaking

          return;
        });
  }

  // Real-time stream for specific group messages
  Stream<List<Map<String, dynamic>>> getGroupMessagesStreamForGroup(
    String groupId,
  ) {
    final currentUserId = _supabase.auth.currentUser!.id;
    return _supabase
        .from('group_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at', ascending: true)
        .map((rows) {
          // Filter out messages deleted for current user only (but keep messages deleted for everyone)
          return rows
              .where((row) {
                // Exclude messages deleted for current user only
                final deletedForUsers = List<String>.from(
                  row['deleted_for_users'] ?? [],
                );
                if (deletedForUsers.contains(currentUserId)) return false;

                return true;
              })
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
        })
        .handleError((error) {
          return <Map<String, dynamic>>[];
        });
  }

  // Expense Management Methods

  // Create a new expense
  Future<String> createExpense({
    required String groupId,
    required String title,
    required double totalAmount,
    required String paidBy,
    String? description,
  }) async {
    try {
      final response =
          await _supabase
              .from('expenses')
              .insert({
                'group_id': groupId,
                'title': title,
                'description': description,
                'total_amount': totalAmount,
                'paid_by': paidBy,
                'created_by': _supabase.auth.currentUser!.id,
                'created_at': DateTime.now().toUtc().toIso8601String(),
              })
              .select('id')
              .single();

      final expenseId = response['id'];

      // Small delay to ensure the database trigger has processed the expense shares
      await Future.delayed(const Duration(milliseconds: 500));

      // Get the expense data with profile information using manual join
      final expenseData =
          await _supabase
              .from('expenses')
              .select('*')
              .eq('id', expenseId)
              .single();

      // Get the profile of the person who paid
      final paidByProfile =
          await _supabase
              .from('profiles')
              .select('*')
              .eq('id', paidBy)
              .single();

      // Combine the data
      final combinedExpenseData = {...expenseData, 'profiles': paidByProfile};

      // Send an expense message to the group with expense data
      await sendGroupMessage(
        groupId: groupId,
        content:
            '💰 New expense: $title - Rs ${totalAmount.toStringAsFixed(2)}',
        category: 'expense',
        expenseData: combinedExpenseData,
      );

      return expenseId;
    } catch (e) {
      rethrow;
    }
  }

  // Get all expenses for a group
  Future<List<Map<String, dynamic>>> getGroupExpenses(String groupId) async {
    try {
      final expenses = await _supabase
          .from('expenses')
          .select('*')
          .eq('group_id', groupId)
          .order('created_at', ascending: false);

      // Get all unique user IDs from expenses
      final userIds = <String>{};
      for (final expense in expenses) {
        userIds.add(expense['paid_by']);
        userIds.add(expense['created_by']);
      }

      // Get profiles for all users
      final profiles = await _supabase
          .from('profiles')
          .select('*')
          .inFilter('id', userIds.toList());

      // Create a map of user_id to profile
      final profilesMap = <String, Map<String, dynamic>>{};
      for (final profile in profiles) {
        profilesMap[profile['id']] = profile;
      }

      // Combine expenses with profiles
      final result = <Map<String, dynamic>>[];
      for (final expense in expenses) {
        final paidByProfile = profilesMap[expense['paid_by']];
        result.add({...expense, 'profiles': paidByProfile ?? {}});
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Get user's expense shares (what they owe)
  Future<List<Map<String, dynamic>>> getUserExpenseShares() async {
    try {
      final expenseShares = await _supabase
          .from('expense_shares')
          .select('*')
          .eq('user_id', _supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);

      if (expenseShares.isEmpty) {
        return [];
      }

      // Get all expense IDs
      final expenseIds =
          expenseShares.map((share) => share['expense_id']).toList();

      // Get expenses with group info
      final expenses = await _supabase
          .from('expenses')
          .select('*')
          .inFilter('id', expenseIds);

      // Get all user IDs from expenses
      final userIds = <String>{};
      for (final expense in expenses) {
        userIds.add(expense['paid_by']);
        userIds.add(expense['created_by']);
      }

      // Get group IDs
      final groupIds =
          expenses.map((expense) => expense['group_id']).toSet().toList();

      // Get profiles for all users
      final profiles = await _supabase
          .from('profiles')
          .select('*')
          .inFilter('id', userIds.toList());

      // Get groups
      final groups = await _supabase
          .from('groups')
          .select('*')
          .inFilter('id', groupIds);

      // Create maps for easy lookup
      final expensesMap = <String, Map<String, dynamic>>{};
      for (final expense in expenses) {
        expensesMap[expense['id']] = expense;
      }

      final profilesMap = <String, Map<String, dynamic>>{};
      for (final profile in profiles) {
        profilesMap[profile['id']] = profile;
      }

      final groupsMap = <String, Map<String, dynamic>>{};
      for (final group in groups) {
        groupsMap[group['id']] = group;
      }

      // Combine all data
      final result = <Map<String, dynamic>>[];
      for (final share in expenseShares) {
        final expense = expensesMap[share['expense_id']];
        if (expense != null) {
          final paidByProfile = profilesMap[expense['paid_by']];
          final group = groupsMap[expense['group_id']];

          result.add({
            ...share,
            'expenses': {
              ...expense,
              'groups': group ?? {},
              'profiles': paidByProfile ?? {},
            },
          });
        }
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Get all expenses created by the current user
  Future<List<Map<String, dynamic>>> getUserCreatedExpenses() async {
    try {
      final expenses = await _supabase
          .from('expenses')
          .select('*')
          .eq('created_by', _supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);

      if (expenses.isEmpty) {
        return [];
      }

      // Get all user IDs from expenses
      final userIds = <String>{};
      for (final expense in expenses) {
        userIds.add(expense['paid_by']);
        userIds.add(expense['created_by']);
      }

      // Get group IDs
      final groupIds =
          expenses.map((expense) => expense['group_id']).toSet().toList();

      // Get profiles for all users
      final profiles = await _supabase
          .from('profiles')
          .select('*')
          .inFilter('id', userIds.toList());

      // Get groups
      final groups = await _supabase
          .from('groups')
          .select('*')
          .inFilter('id', groupIds);

      // Create maps for easy lookup
      final profilesMap = <String, Map<String, dynamic>>{};
      for (final profile in profiles) {
        profilesMap[profile['id']] = profile;
      }

      final groupsMap = <String, Map<String, dynamic>>{};
      for (final group in groups) {
        groupsMap[group['id']] = group;
      }

      // Combine all data
      final result = <Map<String, dynamic>>[];
      for (final expense in expenses) {
        final paidByProfile = profilesMap[expense['paid_by']];
        final group = groupsMap[expense['group_id']];

        result.add({
          ...expense,
          'groups': group ?? {},
          'profiles': paidByProfile ?? {},
        });
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Mark an expense share as paid with balance integration
  Future<Map<String, dynamic>> markExpenseShareAsPaid(
    String expenseShareId,
  ) async {
    try {
      // First, get the expense share details to find the group and expense info
      final expenseShare =
          await _supabase
              .from('expense_shares')
              .select('*, expenses(*)')
              .eq('id', expenseShareId)
              .eq('user_id', _supabase.auth.currentUser!.id)
              .single();

      final amountOwed = (expenseShare['amount_owed'] as num).toDouble();
      final expenseTitle = expenseShare['expenses']['title'] as String;
      final groupId = expenseShare['expenses']['group_id'] as String;

      // Use balance service to handle payment
      final paymentResult = await _balanceService.spendFromBalance(
        amount: amountOwed,
        title: 'Payment for $expenseTitle',
        description: 'Expense share payment',
        expenseShareId: expenseShareId,
        groupId: groupId,
      );

      // Update the expense share as paid
      await _supabase
          .from('expense_shares')
          .update({
            'is_paid': true,
            'paid_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', expenseShareId)
          .eq('user_id', _supabase.auth.currentUser!.id);

      // Get the current user's profile
      final currentUserProfile =
          await _supabase
              .from('profiles')
              .select('*')
              .eq('id', _supabase.auth.currentUser!.id)
              .single();

      // Create payment data for the message with balance information
      final paymentData = {
        'expense_id': expenseShare['expense_id'],
        'expense_title': expenseTitle,
        'amount_paid': amountOwed,
        'paid_by': _supabase.auth.currentUser!.id,
        'paid_by_name': currentUserProfile['display_name'],
        'expense_share_id': expenseShareId,
        'paid_at': DateTime.now().toUtc().toIso8601String(),
        'payment_method': paymentResult['payment_method'],
        'amount_paid_from_balance': paymentResult['amount_paid_from_balance'],
        'amount_paid_from_loan': paymentResult['amount_paid_from_loan'],
        'remaining_balance': paymentResult['remaining_balance'],
      };

      // Create appropriate message content based on payment method
      String messageContent;
      // Simplified message - don't show loan information
      messageContent =
          '✅ ${currentUserProfile['display_name']} paid Rs ${amountOwed.toStringAsFixed(2)} for $expenseTitle';

      // Send a payment message to the group
      await sendGroupMessage(
        groupId: groupId,
        content: messageContent,
        category: 'payment',
        paymentData: paymentData,
      );

      return paymentResult;
    } catch (e) {
      rethrow;
    }
  }

  // Get expense summary for a group
  Future<Map<String, dynamic>> getGroupExpenseSummary(String groupId) async {
    try {
      final expenses = await getGroupExpenses(groupId);
      final members = await getGroupMembers(groupId);

      double totalExpenses = 0;
      Map<String, double> memberTotals = {};

      // Initialize member totals
      for (final member in members) {
        memberTotals[member['user_id']] = 0;
      }

      // Calculate totals
      for (final expense in expenses) {
        totalExpenses += (expense['total_amount'] as num).toDouble();
        final paidBy = expense['paid_by'];
        memberTotals[paidBy] =
            (memberTotals[paidBy] ?? 0) +
            (expense['total_amount'] as num).toDouble();
      }

      final perPersonShare = totalExpenses / members.length;

      // Calculate what each person owes or is owed
      Map<String, double> memberBalances = {};
      for (final member in members) {
        final userId = member['user_id'];
        final paid = memberTotals[userId] ?? 0;
        memberBalances[userId] = paid - perPersonShare;
      }

      return {
        'total_expenses': totalExpenses,
        'per_person_share': perPersonShare,
        'member_balances': memberBalances,
        'member_totals': memberTotals,
        'expense_count': expenses.length,
        'members': members, // Include full member data with profiles
      };
    } catch (e) {
      rethrow;
    }
  }

  // Get messages by category
  Future<List<Map<String, dynamic>>> getGroupMessagesByCategory(
    String groupId,
    String category,
  ) async {
    try {
      final messages = await _supabase
          .from('group_messages')
          .select('*')
          .eq('group_id', groupId)
          .eq('category', category)
          .order('created_at', ascending: true);

      if (messages.isEmpty) {
        return [];
      }

      // Filter out deleted messages
      final nonDeletedMessages =
          messages.where((message) {
            final isDeleted = message['is_deleted'] ?? false;
            return !isDeleted;
          }).toList();

      if (nonDeletedMessages.isEmpty) {
        return [];
      }

      // Get all sender IDs
      final senderIds =
          nonDeletedMessages
              .map((message) => message['sender_id'])
              .toSet()
              .toList();

      // Get profiles for all senders
      final profiles = await _supabase
          .from('profiles')
          .select('*')
          .inFilter('id', senderIds);

      // Create a map of sender_id to profile
      final profilesMap = <String, Map<String, dynamic>>{};
      for (final profile in profiles) {
        profilesMap[profile['id']] = profile;
      }

      // Combine messages with profiles
      final result = <Map<String, dynamic>>[];
      for (final message in nonDeletedMessages) {
        final profile = profilesMap[message['sender_id']];
        result.add({...message, 'profiles': profile ?? {}});
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Get expense details with payment status for all members
  Future<List<Map<String, dynamic>>> getExpenseDetailsWithPaymentStatus(
    String expenseId,
  ) async {
    try {
      final expenseShares = await _supabase
          .from('expense_shares')
          .select('*')
          .eq('expense_id', expenseId)
          .order('created_at', ascending: true);

      if (expenseShares.isEmpty) {
        return [];
      }

      // Get all user IDs from expense shares
      final userIds = expenseShares.map((share) => share['user_id']).toList();

      // Get profiles for all users
      final profiles = await _supabase
          .from('profiles')
          .select('*')
          .inFilter('id', userIds);

      // Create a map of user_id to profile
      final profilesMap = <String, Map<String, dynamic>>{};
      for (final profile in profiles) {
        profilesMap[profile['id']] = profile;
      }

      // Combine expense shares with profiles
      final result = <Map<String, dynamic>>[];
      for (final share in expenseShares) {
        final profile = profilesMap[share['user_id']];
        result.add({...share, 'profiles': profile ?? {}});
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Debug method to test expense creation
  Future<Map<String, dynamic>> debugExpenseCreation(String groupId) async {
    try {
      // Test if we can access the expenses table
      final tableTest = await _supabase
          .from('expenses')
          .select('count')
          .limit(1);

      // Test if we can access the expense_shares table
      final sharesTest = await _supabase
          .from('expense_shares')
          .select('count')
          .limit(1);

      // Test if we can access the profiles table
      final profilesTest = await _supabase
          .from('profiles')
          .select('count')
          .limit(1);

      // Test if we can access the groups table
      final groupsTest = await _supabase
          .from('groups')
          .select('count')
          .limit(1);

      // Test if we can access the group_members table
      final membersTest = await _supabase
          .from('group_members')
          .select('count')
          .limit(1);

      return {
        'success': true,
        'expenses_table': tableTest.isNotEmpty,
        'expense_shares_table': sharesTest.isNotEmpty,
        'profiles_table': profilesTest.isNotEmpty,
        'groups_table': groupsTest.isNotEmpty,
        'group_members_table': membersTest.isNotEmpty,
        'current_user': _supabase.auth.currentUser?.id,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'current_user': _supabase.auth.currentUser?.id,
      };
    }
  }

  // Get all expenses from all groups the user is a member of
  Future<List<Map<String, dynamic>>> getAllUserExpenses() async {
    try {
      // First get all groups the user is a member of
      final userGroups = await _supabase
          .from('group_members')
          .select('group_id')
          .eq('user_id', _supabase.auth.currentUser!.id);

      if (userGroups.isEmpty) {
        return [];
      }

      final groupIds = userGroups.map((group) => group['group_id']).toList();

      // Get all expenses from these groups
      final expenses = await _supabase
          .from('expenses')
          .select('*')
          .inFilter('group_id', groupIds)
          .order('created_at', ascending: false);

      if (expenses.isEmpty) {
        return [];
      }

      // Get all user IDs from expenses
      final userIds = <String>{};
      for (final expense in expenses) {
        userIds.add(expense['paid_by']);
        userIds.add(expense['created_by']);
      }

      // Get group IDs
      final expenseGroupIds =
          expenses.map((expense) => expense['group_id']).toSet().toList();

      // Get profiles for all users
      final profiles = await _supabase
          .from('profiles')
          .select('*')
          .inFilter('id', userIds.toList());

      // Get groups
      final groups = await _supabase
          .from('groups')
          .select('*')
          .inFilter('id', expenseGroupIds);

      // Create maps for easy lookup
      final profilesMap = <String, Map<String, dynamic>>{};
      for (final profile in profiles) {
        profilesMap[profile['id']] = profile;
      }

      final groupsMap = <String, Map<String, dynamic>>{};
      for (final group in groups) {
        groupsMap[group['id']] = group;
      }

      // Combine all data
      final result = <Map<String, dynamic>>[];
      for (final expense in expenses) {
        final paidByProfile = profilesMap[expense['paid_by']];
        final group = groupsMap[expense['group_id']];

        result.add({
          ...expense,
          'groups': group ?? {},
          'profiles': paidByProfile ?? {},
        });
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Get existing paid members without payment messages
  Future<List<Map<String, dynamic>>> getExistingPaidMembersWithoutMessages(
    String groupId,
  ) async {
    try {
      // Get all expenses for this group
      final expenses = await getGroupExpenses(groupId);
      final existingPaymentMessages = await getGroupMessagesByCategory(
        groupId,
        'payment',
      );

      // Create a set of expense share IDs that already have payment messages
      final existingPaymentShareIds = <String>{};
      for (final message in existingPaymentMessages) {
        final paymentData = message['payment_data'] as Map<String, dynamic>?;
        if (paymentData != null && paymentData['expense_share_id'] != null) {
          existingPaymentShareIds.add(paymentData['expense_share_id']);
        }
      }

      // Get all paid expense shares that don't have payment messages
      final paidSharesWithoutMessages = <Map<String, dynamic>>[];

      for (final expense in expenses) {
        final expenseShares = await getExpenseDetailsWithPaymentStatus(
          expense['id'],
        );

        for (final share in expenseShares) {
          if (share['is_paid'] == true &&
              !existingPaymentShareIds.contains(share['id'])) {
            // This is a paid share without a payment message
            paidSharesWithoutMessages.add({...share, 'expense': expense});
          }
        }
      }

      return paidSharesWithoutMessages;
    } catch (e) {
      rethrow;
    }
  }

  // Generate payment messages for existing paid members
  Future<void> generatePaymentMessagesForExistingPaidMembers(
    String groupId,
  ) async {
    try {
      final paidSharesWithoutMessages =
          await getExistingPaidMembersWithoutMessages(groupId);

      for (final share in paidSharesWithoutMessages) {
        final profile = share['profiles'] as Map<String, dynamic>?;
        final memberName = profile?['display_name'] ?? 'Unknown';
        final expense = share['expense'] as Map<String, dynamic>;

        // Create payment data for the message
        final paymentData = {
          'expense_id': share['expense_id'],
          'expense_title': expense['title'],
          'amount_paid': share['amount_owed'],
          'paid_by': share['user_id'],
          'paid_by_name': memberName,
          'expense_share_id': share['id'],
          'paid_at':
              share['paid_at'] ?? DateTime.now().toUtc().toIso8601String(),
          'is_historical': true, // Mark as historical payment
        };

        // Send a payment message to the group
        await sendGroupMessage(
          groupId: groupId,
          content:
              '✅ $memberName paid Rs ${share['amount_owed'].toStringAsFixed(2)} for ${expense['title']}',
          category: 'payment',
          paymentData: paymentData,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get group information by ID
  Future<Map<String, dynamic>?> getGroupInfo(String groupId) async {
    try {
      final response =
          await _supabase.from('groups').select('*').eq('id', groupId).single();
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<int> getGroupExpensesCount(String groupId) async {
    try {
      final response = await Supabase.instance.client
          .from('expenses')
          .select('id')
          .eq('group_id', groupId);

      if (response is List) {
        return response.length;
      }
      return 0;
    } catch (e) {
      // Rethrow the error to be handled by the caller
      rethrow;
    }
  }

  // Delete message for current user only (soft delete)
  Future<void> deleteMessageForMe(String messageId) async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;

      // Get current deleted_for_users array
      final message =
          await _supabase
              .from('messages')
              .select('deleted_for_users')
              .eq('id', messageId)
              .single();

      final deletedForUsers = List<String>.from(
        message['deleted_for_users'] ?? [],
      );
      if (!deletedForUsers.contains(currentUserId)) {
        deletedForUsers.add(currentUserId);
      }

      // Update with new array
      await _supabase
          .from('messages')
          .update({'deleted_for_users': deletedForUsers})
          .eq('id', messageId);
    } catch (e) {
      rethrow;
    }
  }

  // Delete message for everyone (soft delete)
  Future<void> deleteMessageForEveryone(String messageId) async {
    try {
      await _supabase
          .from('messages')
          .update({'is_deleted': true, 'content': 'This message was deleted'})
          .eq('id', messageId);
    } catch (e) {
      rethrow;
    }
  }

  // Delete group message for current user only (soft delete)
  Future<void> deleteGroupMessageForMe(String messageId) async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;

      // Get current deleted_for_users array
      final message =
          await _supabase
              .from('group_messages')
              .select('deleted_for_users')
              .eq('id', messageId)
              .single();

      final deletedForUsers = List<String>.from(
        message['deleted_for_users'] ?? [],
      );
      if (!deletedForUsers.contains(currentUserId)) {
        deletedForUsers.add(currentUserId);
      }

      // Update with new array
      await _supabase
          .from('group_messages')
          .update({'deleted_for_users': deletedForUsers})
          .eq('id', messageId);
    } catch (e) {
      rethrow;
    }
  }

  // Delete group message for everyone (soft delete)
  Future<void> deleteGroupMessageForEveryone(String messageId) async {
    try {
      await _supabase
          .from('group_messages')
          .update({'is_deleted': true, 'content': 'This message was deleted'})
          .eq('id', messageId);
    } catch (e) {
      rethrow;
    }
  }

  // Legacy methods for backward compatibility
  Future<void> softDeleteGroupMessage(String messageId) async {
    // Default to delete for everyone for backward compatibility
    await deleteGroupMessageForEveryone(messageId);
  }

  Future<void> softDeleteDirectMessage(String messageId) async {
    // Default to delete for everyone for backward compatibility
    await deleteMessageForEveryone(messageId);
  }

  // Real-time stream for direct messages that will trigger chat list updates
  Stream<void> getDirectMessagesStream() {
    final userId = _supabase.auth.currentUser!.id;
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .map((event) {
          // Filter to only trigger updates for messages involving the current user
          final hasRelevantMessage = event.any((message) {
            final senderId = message['sender_id'] as String;
            final receiverId = message['receiver_id'] as String;
            final isDeleted = message['is_deleted'] ?? false;

            // Only trigger if message involves current user and is not deleted
            return (senderId == userId || receiverId == userId) && !isDeleted;
          });

          // Only emit if there's a relevant message
          if (hasRelevantMessage) {
            return;
          }
        })
        .handleError((error) {
          // Handle errors silently to prevent stream from breaking

          return;
        });
  }

  // Get unread message count for a direct chat with another user
  Future<int> getUnreadDirectMessageCount(String otherUserId) async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('messages')
          .select('id, is_deleted, deleted_for_users')
          .eq('receiver_id', currentUserId)
          .eq('sender_id', otherUserId)
          .eq('is_read', false);

      final nonDeletedMessages =
          response.where((message) {
            final isDeleted = message['is_deleted'] ?? false;
            final deletedForUsers = List<String>.from(
              message['deleted_for_users'] ?? [],
            );

            // Exclude messages deleted for everyone
            if (isDeleted) return false;

            // Exclude messages deleted for current user
            if (deletedForUsers.contains(currentUserId)) return false;

            return true;
          }).toList();

      return nonDeletedMessages.length;
    } catch (e) {
      return 0;
    }
  }

  // Get unread message count for a group
  Future<int> getUnreadGroupMessageCount(String groupId) async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;
      // Get all group messages for this group
      final messages = await _supabase
          .from('group_messages')
          .select('id, is_deleted, deleted_for_users, sender_id')
          .eq('group_id', groupId)
          .order('created_at', ascending: true);

      if (messages.isEmpty) return 0;

      // Filter out messages sent by current user and deleted messages
      final relevantMessages =
          messages.where((message) {
            final isDeleted = message['is_deleted'] ?? false;
            final deletedForUsers = List<String>.from(
              message['deleted_for_users'] ?? [],
            );
            final senderId = message['sender_id'] as String;

            // Exclude messages sent by current user
            if (senderId == currentUserId) return false;

            // Exclude messages deleted for everyone
            if (isDeleted) return false;

            // Exclude messages deleted for current user
            if (deletedForUsers.contains(currentUserId)) return false;

            return true;
          }).toList();

      if (relevantMessages.isEmpty) return 0;

      final messageIds =
          relevantMessages.map((m) => m['id'] as String).toList();

      // Get all read receipts for this user in this group
      final reads = await _supabase
          .from('group_message_reads')
          .select('message_id')
          .eq('user_id', currentUserId)
          .inFilter('message_id', messageIds);

      final readMessageIds =
          reads.map((r) => r['message_id'] as String).toSet();

      // Unread = messages not in readMessageIds
      final unreadCount =
          messageIds.where((id) => !readMessageIds.contains(id)).length;
      return unreadCount;
    } catch (e) {
      return 0;
    }
  }

  // Get unread counts for all groups for the current user
  Future<Map<String, int>> getUnreadCountsForAllGroups(
    List<String> groupIds,
  ) async {
    final Map<String, int> result = {};
    for (final groupId in groupIds) {
      result[groupId] = await getUnreadGroupMessageCount(groupId);
    }
    return result;
  }

  // Get the timestamp when user last read messages in a direct chat
  Future<DateTime?> getLastReadTimestamp(String otherUserId) async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;

      // Get the most recent message that was read by the current user
      final response =
          await _supabase
              .from('messages')
              .select('created_at')
              .eq('sender_id', otherUserId)
              .eq('receiver_id', currentUserId)
              .eq('is_read', true)
              .order('created_at', ascending: false)
              .limit(1)
              .single();

      if (response != null) {
        return DateTime.parse(response['created_at']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get the timestamp when user last read messages in a group chat
  Future<DateTime?> getLastReadGroupTimestamp(String groupId) async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;

      // Get the most recent group message read receipt for this group
      final response =
          await _supabase
              .from('group_message_reads')
              .select('read_at')
              .eq('user_id', currentUserId)
              .order('read_at', ascending: false)
              .limit(1)
              .single();

      if (response != null) {
        return DateTime.parse(response['read_at']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
