import 'package:flutter/material.dart';
// supabase import removed - not needed in this screen after UI cleanup
import '../widgets/edit_group_name_dialog.dart';
import '../widgets/user_list_item.dart';

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

class _GroupManagementScreenState extends State<GroupManagementScreen> {
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

  // Add/remove member functions removed: this screen no longer exposes add/remove member UI.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        centerTitle: false,
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
          Expanded(child: _buildMembersList()),
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
                    Icons.delete_outlined,
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
        Expanded(
          child: ListView.builder(
            itemCount: widget.members.length,
            itemBuilder: (context, index) {
              final member = widget.members[index];
              final profile = member['profiles'];
              final isMemberAdmin = member['is_admin'] ?? false;

              return UserListItem(
                userId: member['user_id'],
                name: profile['display_name'] ?? 'Unknown User',
                avatarUrl: profile['avatar_url'],
                subtitle: profile['username'] ?? '',
                // show admin badge as a trailing widget when member is admin
                trailingWidget:
                    isMemberAdmin
                        ? Container(
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
                        )
                        : null,
              );
            },
          ),
        ),
      ],
    );
  }

  // Add-members UI removed from this screen.
}
