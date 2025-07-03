import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/balance_service.dart';
import '../widgets/expense_details_modal.dart';
import '../widgets/expense_list_item.dart';
import 'package:split_smart_supabase/widgets/ui/main_scaffold.dart';

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

    return MainScaffold(
      currentIndex: 3,
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

  Widget _buildExpenseList({
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) getTitle,
    required String Function(Map<String, dynamic>) getGroupName,
    required String Function(Map<String, dynamic>) getPaidByName,
    required double Function(Map<String, dynamic>) getAmount,
    required DateTime Function(Map<String, dynamic>) getCreatedAt,
    String? Function(Map<String, dynamic>)? getDescription,
    bool Function(Map<String, dynamic>)? getIsPaid,
    VoidCallback? Function(Map<String, dynamic>)? getOnMarkPaid,
    String? Function(Map<String, dynamic>)? getExpenseShareId,
    void Function(Map<String, dynamic>)? onTap,
    Widget? emptyState,
  }) {
    if (items.isEmpty) {
      return emptyState ?? const Center(child: Text('No items found'));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SafeArea(
        bottom: true,
        child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ExpenseListItem(
              title: getTitle(item),
              groupName: getGroupName(item),
              paidByName: getPaidByName(item),
              amount: getAmount(item),
              createdAt: getCreatedAt(item),
              description: getDescription?.call(item),
              isPaid: getIsPaid?.call(item) ?? true,
              onTap: onTap != null ? () => onTap(item) : null,
              onMarkPaid: getOnMarkPaid?.call(item),
              expenseShareId: getExpenseShareId?.call(item),
              showDivider: index != 0,
            );
          },
        ),
      ),
    );
  }

  Widget _buildAllExpensesTab(ThemeData theme) {
    return _buildExpenseList(
      items: _allExpenses,
      getTitle: (expense) => expense['title'] as String? ?? 'Unknown Expense',
      getGroupName:
          (expense) =>
              (expense['groups'] as Map<String, dynamic>? ?? {})['name'] ??
              'Unknown Group',
      getPaidByName:
          (expense) =>
              (expense['profiles'] as Map<String, dynamic>? ??
                  {})['display_name'] ??
              'Unknown',
      getAmount:
          (expense) => (expense['total_amount'] as num?)?.toDouble() ?? 0.0,
      getCreatedAt: (expense) {
        try {
          return DateTime.parse(expense['created_at'] ?? '');
        } catch (e) {
          return DateTime.now();
        }
      },
      getDescription: (expense) => expense['description'] as String?,
      onTap: (expense) => _showExpenseDetails(expense),
      emptyState: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No expenses found'),
            Text('Join groups and create expenses to see them here!'),
          ],
        ),
      ),
    );
  }

  Widget _buildMySharesTab(ThemeData theme) {
    return _buildExpenseList(
      items: _userExpenseShares,
      getTitle:
          (share) =>
              (share['expenses'] as Map<String, dynamic>? ?? {})['title']
                  as String? ??
              'Unknown Expense',
      getGroupName:
          (share) =>
              ((share['expenses'] as Map<String, dynamic>? ?? {})['groups']
                      as Map<String, dynamic>? ??
                  {})['name'] ??
              'Unknown Group',
      getPaidByName:
          (share) =>
              ((share['expenses'] as Map<String, dynamic>? ?? {})['profiles']
                      as Map<String, dynamic>? ??
                  {})['display_name'] ??
              'Unknown',
      getAmount: (share) => (share['amount_owed'] as num?)?.toDouble() ?? 0.0,
      getCreatedAt: (share) {
        final expense = share['expenses'] as Map<String, dynamic>? ?? {};
        try {
          return DateTime.parse(expense['created_at'] ?? '');
        } catch (e) {
          return DateTime.now();
        }
      },
      getDescription:
          (share) =>
              (share['expenses'] as Map<String, dynamic>? ?? {})['description']
                  as String?,
      getIsPaid: (share) => share['is_paid'] as bool? ?? false,
      getOnMarkPaid:
          (share) =>
              !(share['is_paid'] as bool? ?? false)
                  ? () => _markAsPaid(share['id'])
                  : null,
      getExpenseShareId: (share) => share['id'],
      onTap:
          (share) => _showExpenseDetails(
            (share['expenses'] as Map<String, dynamic>? ?? {}),
          ),
      emptyState: const Center(
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
      ),
    );
  }

  void _showExpenseDetails(Map<String, dynamic> expense) {
    showExpenseDetailsModal(context, expense);
  }
}
