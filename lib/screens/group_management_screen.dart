import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupManagementScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupManagementScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _availableUsers = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final members = await _chatService.getGroupMembers(widget.groupId);
      final isAdmin = await _chatService.isGroupAdmin(widget.groupId);
      final availableUsers = await _chatService.getAvailableUsersForGroup(
        widget.groupId,
      );

      if (mounted) {
        setState(() {
          _members = members;
          _isAdmin = isAdmin;
          _availableUsers = availableUsers;
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

  Future<void> _renameGroup() async {
    final textController = TextEditingController(text: widget.groupName);
    final newName = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rename Group'),
            content: TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(textController.text),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      try {
        await _chatService.renameGroup(
          groupId: widget.groupId,
          newName: newName.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group renamed successfully!')),
          );
          Navigator.of(context).pop(newName.trim());
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Group'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete "${widget.groupName}"?',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This action will permanently delete:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('• All group messages'),
                const Text('• All expenses and expense shares'),
                const Text('• All member relationships'),
                const Text('• The group itself'),
                const SizedBox(height: 16),
                const Text(
                  'This action cannot be undone!',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete Group'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _chatService.deleteGroup(widget.groupId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop('deleted');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting group: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _addMember(Map<String, dynamic> user) async {
    try {
      await _chatService.addMemberToGroup(
        groupId: widget.groupId,
        userId: user['id'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user['display_name']} added to group!')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Member'),
            content: Text(
              'Are you sure you want to remove ${member['profiles']['display_name']} from the group?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Remove'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _chatService.removeMemberFromGroup(
          groupId: widget.groupId,
          userId: member['user_id'],
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${member['profiles']['display_name']} removed from group!',
              ),
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage ${widget.groupName}'),
        bottom:
            _isAdmin
                ? TabBar(
                  controller: _tabController,
                  tabs: const [Tab(text: 'Members'), Tab(text: 'Add Members')],
                )
                : null,
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _renameGroup,
              tooltip: 'Rename Group',
            ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteGroup,
              tooltip: 'Delete Group',
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isAdmin
              ? TabBarView(
                controller: _tabController,
                children: [_buildMembersList(), _buildAddMembersList()],
              )
              : _buildMembersList(),
    );
  }

  Widget _buildMembersList() {
    return ListView.builder(
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final profile = member['profiles'];
        final isCurrentUser =
            member['user_id'] == Supabase.instance.client.auth.currentUser!.id;
        final isMemberAdmin = member['is_admin'] ?? false;

        return ListTile(
          leading: CircleAvatar(
            backgroundImage:
                profile['avatar_url'] != null
                    ? NetworkImage(profile['avatar_url'])
                    : null,
            child:
                profile['avatar_url'] == null
                    ? Text(profile['display_name'][0].toUpperCase())
                    : null,
          ),
          title: Text(profile['display_name'] ?? 'Unknown User'),
          subtitle: Text(
            isMemberAdmin ? 'Admin' : 'Member',
            style: TextStyle(
              color: isMemberAdmin ? Colors.blue : Colors.grey,
              fontWeight: isMemberAdmin ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing:
              _isAdmin && !isCurrentUser
                  ? IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                    onPressed: () => _removeMember(member),
                    tooltip: 'Remove member',
                  )
                  : null,
        );
      },
    );
  }

  Widget _buildAddMembersList() {
    if (_availableUsers.isEmpty) {
      return const Center(
        child: Text('No users available to add to the group.'),
      );
    }

    return ListView.builder(
      itemCount: _availableUsers.length,
      itemBuilder: (context, index) {
        final user = _availableUsers[index];
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
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
            onPressed: () => _addMember(user),
            tooltip: 'Add member',
          ),
        );
      },
    );
  }
}
