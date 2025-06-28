import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/balance_service.dart';
import '../widgets/expense_details_modal.dart';

class AllExpensesScreen extends StatefulWidget {
  const AllExpensesScreen({super.key});

  @override
  State<AllExpensesScreen> createState() => _AllExpensesScreenState();
}

class _AllExpensesScreenState extends State<AllExpensesScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final BalanceService _balanceService = BalanceService();
  late TabController _tabController;

  List<Map<String, dynamic>> _allExpenses = [];
  List<Map<String, dynamic>> _userExpenseShares = [];
  bool _isLoading = true;

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
      final futures = await Future.wait([
        _chatService.getAllUserExpenses(),
        _chatService.getUserExpenseShares(),
      ]);

      if (mounted) {
        setState(() {
          _allExpenses = futures[0];
          _userExpenseShares = futures[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading expenses: $e')));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsPaid(String expenseShareId) async {
    try {
      // Get the expense share details first
      final expenseShare = _userExpenseShares.firstWhere(
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

      // Update only the specific expense share in the list
      setState(() {
        final index = _userExpenseShares.indexWhere(
          (share) => share['id'] == expenseShareId,
        );
        if (index != -1) {
          // Create a new list to trigger rebuild
          _userExpenseShares = List.from(_userExpenseShares);
          // Update the specific share to mark it as paid
          _userExpenseShares[index] = {
            ..._userExpenseShares[index],
            'is_paid': true,
          };
        }
      });

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Expenses'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'All Expenses'), Tab(text: 'My Shares')],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildAllExpensesTab(theme),
                  _buildMySharesTab(theme),
                ],
              ),
    );
  }

  Widget _buildAllExpensesTab(ThemeData theme) {
    if (_allExpenses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No expenses found'),
            Text('Join groups and create expenses to see them here!'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allExpenses.length,
      itemBuilder: (context, index) {
        final expense = _allExpenses[index];
        final group = expense['groups'] as Map<String, dynamic>? ?? {};
        final paidByProfile =
            expense['profiles'] as Map<String, dynamic>? ?? {};
        final paidByName = paidByProfile['display_name'] ?? 'Unknown';
        final amount = (expense['total_amount'] as num?)?.toDouble() ?? 0.0;
        final title = expense['title'] as String? ?? 'Unknown Expense';
        final description = expense['description'] as String?;

        DateTime createdAt;
        try {
          createdAt = DateTime.parse(expense['created_at'] ?? '');
        } catch (e) {
          createdAt = DateTime.now();
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            onTap: () => _showExpenseDetails(expense),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.receipt, color: Colors.white),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Group: ${group['name'] ?? 'Unknown Group'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('Paid by: $paidByName'),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs ${amount.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'View Details',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMySharesTab(ThemeData theme) {
    if (_userExpenseShares.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text('No expense shares'),
            Text('You don\'t owe anything yet!'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userExpenseShares.length,
      itemBuilder: (context, index) {
        final share = _userExpenseShares[index];
        final expense = share['expenses'] as Map<String, dynamic>? ?? {};
        final group = expense['groups'] as Map<String, dynamic>? ?? {};
        final paidByProfile =
            expense['profiles'] as Map<String, dynamic>? ?? {};
        final paidByName = paidByProfile['display_name'] ?? 'Unknown';
        final amountOwed = (share['amount_owed'] as num?)?.toDouble() ?? 0.0;
        final isPaid = share['is_paid'] as bool? ?? false;
        final title = expense['title'] as String? ?? 'Unknown Expense';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leading avatar
                CircleAvatar(
                  backgroundColor:
                      isPaid ? Colors.green : theme.colorScheme.primary,
                  child: Icon(
                    isPaid ? Icons.check : Icons.pending,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                // Main content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and group
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Group: ${group['name'] ?? 'Unknown Group'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Paid by info
                      Text('Paid by: $paidByName'),
                      const SizedBox(height: 4),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isPaid
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPaid ? 'Paid' : 'Pending',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isPaid ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Amount and button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rs ${amountOwed.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!isPaid) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () => _markAsPaid(share['id']),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Mark Paid',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExpenseDetails(Map<String, dynamic> expense) {
    showExpenseDetailsModal(context, expense);
  }
}
