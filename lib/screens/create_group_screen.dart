import 'package:flutter/material.dart';
import '../services/chat_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _users = [];
  final List<String> _selectedUserIds = [];
  bool _isLoading = true;
  bool _isCreatingGroup = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _chatService.getUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onUserSelected(bool? selected, String userId) {
    setState(() {
      if (selected == true) {
        if (!_selectedUserIds.contains(userId)) {
          _selectedUserIds.add(userId);
        }
      } else {
        _selectedUserIds.remove(userId);
      }
    });
  }

  Future<void> _createGroup() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedUserIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one member.')),
        );
        return;
      }

      setState(() {
        _isCreatingGroup = true;
      });

      try {
        await _chatService.createGroup(
          name: _groupNameController.text.trim(),
          memberIds: _selectedUserIds,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group created successfully!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error creating group: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isCreatingGroup = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Group')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextFormField(
                        controller: _groupNameController,
                        decoration: const InputDecoration(
                          labelText: 'Group Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a group name';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                      ).copyWith(bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Select Members (${_selectedUserIds.length}/5)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    Expanded(
                      child:
                          _users.isEmpty
                              ? const Center(child: Text('No users to select.'))
                              : ListView.builder(
                                itemCount: _users.length,
                                itemBuilder: (context, index) {
                                  final user = _users[index];
                                  final isSelected = _selectedUserIds.contains(
                                    user['id'],
                                  );
                                  final canSelectMore =
                                      _selectedUserIds.length < 5;

                                  return CheckboxListTile(
                                    title: Text(
                                      user['display_name'] ?? 'Unknown User',
                                    ),
                                    subtitle: Text(user['username'] ?? ''),
                                    value: isSelected,
                                    onChanged:
                                        !isSelected && !canSelectMore
                                            ? null
                                            : (bool? selected) {
                                              _onUserSelected(
                                                selected,
                                                user['id'],
                                              );
                                            },
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreatingGroup ? null : _createGroup,
        label:
            _isCreatingGroup
                ? const Text('Creating...')
                : const Text('Create Group'),
        icon:
            _isCreatingGroup
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : const Icon(Icons.check),
      ),
    );
  }
}
