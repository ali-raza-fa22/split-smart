import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const AddExpenseScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ChatService _chatService = ChatService();

  List<Map<String, dynamic>> _members = [];
  String? _selectedPaidBy;
  bool _isLoading = false;
  bool _isLoadingMembers = true;
  String? _loadMembersError;
  VoidCallback? _amountListener;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    // Add listener to amount controller to update UI
    _amountListener = () {
      setState(() {
        // This will trigger a rebuild when amount changes
      });
    };
    _amountController.addListener(_amountListener!);
  }

  @override
  void dispose() {
    _titleController.dispose();
    if (_amountListener != null) {
      _amountController.removeListener(_amountListener!);
    }
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoadingMembers = true;
      _loadMembersError = null;
    });
    try {
      final members = await _chatService.getGroupMembers(widget.groupId);
      if (mounted) {
        setState(() {
          _members = members;
          _isLoadingMembers = false;
          _selectedPaidBy = Supabase.instance.client.auth.currentUser!.id;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMembers = false;
          _loadMembersError = e.toString();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading members: $e')));
      }
    }
  }

  Future<void> _submitExpense() async {
    // Simple validation
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an expense title')),
      );
      return;
    }

    if (_amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
      return;
    }

    if (_selectedPaidBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select who paid for this expense'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);

      await _chatService.createExpense(
        groupId: widget.groupId,
        title: _titleController.text.trim(),
        totalAmount: amount,
        paidBy: _selectedPaidBy!,
        description:
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding expense: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _debugDatabase() async {
    try {
      final result = await _chatService.debugExpenseCreation(widget.groupId);
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Database Debug Info'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Success: ${result['success']}'),
                      Text('Expenses Table: ${result['expenses_table']}'),
                      Text(
                        'Expense Shares Table: ${result['expense_shares_table']}',
                      ),
                      Text('Profiles Table: ${result['profiles_table']}'),
                      Text('Groups Table: ${result['groups_table']}'),
                      Text(
                        'Group Members Table: ${result['group_members_table']}',
                      ),
                      Text('Current User: ${result['current_user']}'),
                      if (result['error'] != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Error:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(result['error']),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Debug error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building AddExpenseScreen'); // Debug print
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        actions: [
          // Debug button
          IconButton(
            onPressed: _debugDatabase,
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug Database',
          ),
        ],
      ),
      body:
          _isLoadingMembers
              ? const Center(child: CircularProgressIndicator())
              : _loadMembersError != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load group members.',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadMembersError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadMembers,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Simple group info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.groupName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_members.length} members',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Simple form
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Expense Title',
                        hintText: 'e.g., Dinner, Movie tickets',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Total Amount',
                        hintText: '0.00',
                        prefixText: '\$',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedPaidBy,
                      decoration: const InputDecoration(
                        labelText: 'Paid by',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          _members.map((member) {
                            final profile =
                                member['profiles'] as Map<String, dynamic>?;
                            final displayName =
                                profile?['display_name'] ?? 'Unknown';
                            return DropdownMenuItem<String>(
                              value: member['user_id'] as String,
                              child: Text(displayName),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPaidBy = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Simple info text
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF0EA5E9)),
                      ),
                      child: Text(
                        'Amount will be split among ${_members.length} members',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitExpense,
                        child:
                            _isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('Add Expense'),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
