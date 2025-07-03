import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'edit_group_name_dialog.dart';

class GroupActionsBottomSheet extends StatelessWidget {
  final String groupId;
  final String groupName;
  final VoidCallback onGroupUpdated;
  final VoidCallback onGroupDeleted;

  const GroupActionsBottomSheet({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.onGroupUpdated,
    required this.onGroupDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('View Group Details'),
            onTap: () async {
              Navigator.pop(context);
              await _navigateToGroupManagement(context);
            },
          ),
          FutureBuilder<bool>(
            future: ChatService().isGroupAdmin(groupId),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data == true) {
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit),
                      title: const Text('Edit Group'),
                      onTap: () async {
                        Navigator.pop(context);
                        await _editGroupName(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text(
                        'Delete Group',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await _deleteGroup(context);
                      },
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToGroupManagement(BuildContext context) async {
    // Import would be needed for GroupManagementScreen
    // await Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => GroupManagementScreen(
    //       groupId: groupId,
    //       groupName: groupName,
    //     ),
    //   ),
    // );
    onGroupUpdated();
  }

  Future<void> _editGroupName(BuildContext context) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => EditGroupNameDialog(initialName: groupName),
    );

    if (newName != null && newName.isNotEmpty && newName != groupName) {
      try {
        await ChatService().renameGroup(groupId: groupId, newName: newName);
        onGroupUpdated();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group renamed successfully!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error renaming group: $e')));
        }
      }
    }
  }

  Future<void> _deleteGroup(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Group?'),
            content: const Text(
              'Are you sure you want to delete this group and all its data? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await ChatService().deleteGroup(groupId);
        onGroupDeleted();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group deleted successfully!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting group: $e')));
        }
      }
    }
  }
}
