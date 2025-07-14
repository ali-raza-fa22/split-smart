import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/balance_service.dart';
import '../widgets/expense_details_modal.dart';
import '../utils/avatar_utils.dart';

class AllExpenseSharesScreen extends StatefulWidget {
  const AllExpenseSharesScreen({super.key});

  @override
  State<AllExpenseSharesScreen> createState() => _AllExpenseSharesScreenState();
}

class _AllExpenseSharesScreenState extends State<AllExpenseSharesScreen> {
  final ChatService _chatService = ChatService();
  final BalanceService _balanceService = BalanceService();
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
      // Get the expense share details first
      final expenseShare = _expenseShares.firstWhere(
        (share) => share['id'] == expenseShareId,
      );
      final amountOwed = (expenseShare['amount_owed'] as num).toDouble();

      // Check current balance
      final currentBalance = await _balanceService.getCurrentBalance();
      final hasSufficientBalance = await _balanceService.hasSufficientBalance(
        amountOwed,
      );

      // Show confirmation dialog if insufficient balance
      if (!hasSufficientBalance && mounted) {
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Insufficient Balance'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You need to pay Rs ${amountOwed.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    Text(
                      'Your current balance: Rs ${(currentBalance < 0 ? 0.0 : currentBalance).toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This will create a loan for the remaining amount. Do you want to proceed?',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    child: const Text('Proceed with Loan'),
                  ),
                ],
              ),
        );

        if (shouldProceed != true) {
          return; // User cancelled
        }
      }

      final paymentResult = await _chatService.markExpenseShareAsPaid(
        expenseShareId,
      );
      await _loadExpenseShares(); // Reload data

      if (mounted) {
        String message;
        if (paymentResult['payment_method'] == 'balance') {
          message =
              'Paid from balance! Remaining balance: Rs ${paymentResult['remaining_balance'].toStringAsFixed(2)}';
        } else if (paymentResult['payment_method'] == 'mixed') {
          final fromBalance = paymentResult['amount_paid_from_balance'];
          final fromLoan = paymentResult['amount_paid_from_loan'];
          message =
              'Paid Rs ${fromBalance.toStringAsFixed(2)} from balance and Rs ${fromLoan.toStringAsFixed(2)} from loan';
        } else {
          message =
              'Paid from loan! Outstanding loan: Rs ${paymentResult['amount_paid_from_loan'].toStringAsFixed(2)}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
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
                      'Roses are red, violets are blue.\nYou haven\'nt any expenses,\nyou know what to do.',
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
                      leading: AvatarUtils.buildUserAvatar(
                        paidByProfile?['id'],
                        paidByName,
                        Theme.of(context),
                        radius: 20,
                        fontSize: 16,
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
                            'Amount owed: Rs ${amountOwed.toStringAsFixed(2)}',
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
                            'Rs ${amountOwed.toStringAsFixed(2)}',
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
