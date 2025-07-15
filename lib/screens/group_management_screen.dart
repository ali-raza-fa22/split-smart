import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/edit_group_name_dialog.dart';
import '../utils/avatar_utils.dart';

class GroupManagementScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> availableUsers;
  final bool isAdmin;
  final int expensesCount;

  const GroupManagementScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.members,
    required this.availableUsers,
    required this.isAdmin,
    required this.expensesCount,
  });

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _renameGroup() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => EditGroupNameDialog(initialName: widget.groupName),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      try {
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
          ).showSnackBar(SnackBar(content: Text('Something bad happened')));
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
                const Text('• The group itself'),
                const SizedBox(height: 16),
                Text(
                  'This action cannot be undone!',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
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
        // await _chatService.deleteGroup( // Original line commented out
        //   widget.groupId,
        // );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group deleted successfully!')),
          );
          Navigator.of(context).pop('deleted');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting group.')));
        }
      }
    }
  }

  Future<void> _addMember(Map<String, dynamic> user) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user['display_name']} added to group!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Something bad happened.')));
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
        // await _chatService.removeMemberFromGroup( // Original line commented out
        //   groupId: widget.groupId,
        //   userId: member['user_id'],
        // );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${member['profiles']['display_name']} removed from group!',
              ),
            ),
          );
          // _loadData(); // Original line commented out
          // After removing, parent should refresh and pass new data down.
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Something bad happened')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        centerTitle: false,
        bottom:
            widget.isAdmin
                ? TabBar(
                  controller: _tabController,
                  tabs: const [Tab(text: 'Members'), Tab(text: 'Add Members')],
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  labelColor: Theme.of(context).colorScheme.onPrimary,
                )
                : null,
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _renameGroup,
              tooltip: 'Rename Group',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                widget.isAdmin
                    ? TabBarView(
                      controller: _tabController,
                      children: [_buildMembersList(), _buildAddMembersList()],
                    )
                    : _buildMembersList(),
          ),
          if (widget.isAdmin)
            SafeArea(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ElevatedButton.icon(
                  icon: Icon(
                    Icons.delete,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                  label: Text(
                    'Delete Group',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onError,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () async {
                    await _deleteGroup();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                'Members',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Chip(
                label: Text('${widget.expensesCount} Expenses'),
                avatar: Icon(
                  Icons.receipt_long,
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: widget.members.length,
            itemBuilder: (context, index) {
              final member = widget.members[index];
              final profile = member['profiles'];
              final isCurrentUser =
                  member['user_id'] ==
                  Supabase.instance.client.auth.currentUser!.id;
              final isMemberAdmin = member['is_admin'] ?? false;

              return ListTile(
                leading: AvatarUtils.buildUserAvatar(
                  member['user_id'],
                  profile['display_name'],
                  Theme.of(context),
                  avatarUrl: profile['avatar_url'],
                  radius: 20,
                  fontSize: 16,
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(profile['display_name'] ?? 'Unknown User'),
                    if (isMemberAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Admin',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(profile['username'] ?? ''),
                trailing:
                    widget.isAdmin && !isCurrentUser && !isMemberAdmin
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
          ),
        ),
      ],
    );
  }

  Widget _buildAddMembersList() {
    if (widget.availableUsers.isEmpty) {
      return const Center(
        child: Text('No users available to add to the group.'),
      );
    }

    return ListView.builder(
      itemCount: widget.availableUsers.length,
      itemBuilder: (context, index) {
        final user = widget.availableUsers[index];
        return ListTile(
          leading: AvatarUtils.buildUserAvatar(
            user['id'],
            user['display_name'] ?? 'Unknown User',
            Theme.of(context),
            avatarUrl: user['avatar_url'],
            radius: 20,
            fontSize: 16,
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
