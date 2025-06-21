import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../widgets/expense_details_modal.dart';

class AllCreatedExpensesScreen extends StatefulWidget {
  const AllCreatedExpensesScreen({super.key});

  @override
  State<AllCreatedExpensesScreen> createState() =>
      _AllCreatedExpensesScreenState();
}

class _AllCreatedExpensesScreenState extends State<AllCreatedExpensesScreen> {
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _createdExpenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCreatedExpenses();
  }

  Future<void> _loadCreatedExpenses() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final expenses = await _chatService.getUserCreatedExpenses();
      if (mounted) {
        setState(() {
          _createdExpenses = expenses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading created expenses: $e')),
        );
      }
    }
  }

  void _showExpenseDetails(Map<String, dynamic> expenseData) {
    showExpenseDetailsModal(context, expenseData);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses I Created'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCreatedExpenses,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _createdExpenses.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No expenses created yet',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create expenses in your groups to see them here',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _createdExpenses.length,
                itemBuilder: (context, index) {
                  final expense = _createdExpenses[index];
                  final group = expense['groups'] as Map<String, dynamic>;
                  final paidByProfile =
                      expense['profiles'] as Map<String, dynamic>?;
                  final paidByName =
                      paidByProfile?['display_name'] ?? 'Unknown';
                  final totalAmount =
                      (expense['total_amount'] as num).toDouble();

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      onTap: () => _showExpenseDetails(expense),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.receipt,
                          color: theme.colorScheme.secondary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        expense['title'] ?? 'Untitled Expense',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            '${group['name'] ?? 'Unknown Group'} • Paid by $paidByName',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total: \$${totalAmount.toStringAsFixed(2)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        '\$${totalAmount.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
