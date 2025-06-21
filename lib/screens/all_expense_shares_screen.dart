import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../widgets/expense_details_modal.dart';

class AllExpenseSharesScreen extends StatefulWidget {
  const AllExpenseSharesScreen({super.key});

  @override
  State<AllExpenseSharesScreen> createState() => _AllExpenseSharesScreenState();
}

class _AllExpenseSharesScreenState extends State<AllExpenseSharesScreen> {
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _expenseShares = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenseShares();
  }

  Future<void> _loadExpenseShares() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final shares = await _chatService.getUserExpenseShares();
      if (mounted) {
        setState(() {
          _expenseShares = shares;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading expense shares: $e')),
        );
      }
    }
  }

  Future<void> _markAsPaid(String expenseShareId) async {
    try {
      await _chatService.markExpenseShareAsPaid(expenseShareId);
      await _loadExpenseShares(); // Reload data
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Marked as paid!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error marking as paid: $e')));
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
        title: const Text('All Expense Shares'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExpenseShares,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _expenseShares.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No expense shares yet',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When you join groups with expenses, they\'ll appear here',
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
                itemCount: _expenseShares.length,
                itemBuilder: (context, index) {
                  final share = _expenseShares[index];
                  final expense = share['expenses'] as Map<String, dynamic>;
                  final group = expense['groups'] as Map<String, dynamic>;
                  final paidByProfile =
                      expense['profiles'] as Map<String, dynamic>?;
                  final paidByName =
                      paidByProfile?['display_name'] ?? 'Unknown';
                  final amountOwed = (share['amount_owed'] as num).toDouble();
                  final isPaid = share['is_paid'] as bool;

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
                          color:
                              isPaid
                                  ? theme.colorScheme.primary.withValues(
                                    alpha: 0.2,
                                  )
                                  : theme.colorScheme.tertiary.withValues(
                                    alpha: 0.2,
                                  ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isPaid ? Icons.check_circle : Icons.pending,
                          color:
                              isPaid
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.tertiary,
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
                            'Amount owed: \$${amountOwed.toStringAsFixed(2)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${amountOwed.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  isPaid
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.tertiary,
                            ),
                          ),
                          if (!isPaid) ...[
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 28,
                              child: ElevatedButton(
                                onPressed: () => _markAsPaid(share['id']),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Mark Paid',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
