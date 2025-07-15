import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import '../widgets/ui/brand_text_form_field.dart';
import '../widgets/ui/brand_filled_button.dart';

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
  String? _titleError;
  String? _amountError;

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

  void _clearTitleError() {
    if (_titleError != null) {
      setState(() {
        _titleError = null;
      });
    }
  }

  void _clearAmountError() {
    if (_amountError != null) {
      setState(() {
        _amountError = null;
      });
    }
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
        ).showSnackBar(SnackBar(content: Text('Error loading membere')));
      }
    }
  }

  Future<void> _submitExpense() async {
    // Simple validation
    bool hasError = false;
    if (_titleController.text.trim().isEmpty) {
      setState(() {
        _titleError = 'Please enter an expense title';
      });
      hasError = true;
    }
    if (_amountController.text.trim().isEmpty) {
      setState(() {
        _amountError = 'Please enter an amount';
      });
      hasError = true;
    } else {
      final amount = double.tryParse(_amountController.text.trim());
      if (amount == null || amount <= 0) {
        setState(() {
          _amountError = 'Please enter a valid amount';
        });
        hasError = true;
      }
    }
    if (hasError) return;

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
        ).showSnackBar(SnackBar(content: Text('Error adding expense')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body:
          _isLoadingMembers
              ? const Center(child: CircularProgressIndicator())
              : _loadMembersError != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Failed to load group members.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadMembersError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
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
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.groupName,
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_members.length} members',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Simple form
                    BrandTextFormField(
                      controller: _titleController,
                      labelText: 'Expense Title',
                      hintText: 'e.g., Dinner, Movie tickets',
                      errorText: _titleError,
                      onChanged: (value) => _clearTitleError(),
                    ),
                    const SizedBox(height: 16),

                    BrandTextFormField(
                      controller: _amountController,
                      labelText: 'Total Amount',
                      hintText: '100.00',
                      keyboardType: TextInputType.number,
                      errorText: _amountError,
                      onChanged: (value) => _clearAmountError(),
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
                      padding: const EdgeInsets.all(8),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiary,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      child: Row(
                        spacing: 8,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          Text(
                            'Amount will be split among ${_members.length} members',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    BrandFilledButton(
                      text: 'Add Expense',
                      onPressed: _isLoading ? null : _submitExpense,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
    );
  }
}
