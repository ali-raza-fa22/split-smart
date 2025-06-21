import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../widgets/expense_details_modal.dart';

class ExpensesScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const ExpensesScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  late TabController _tabController;

  List<Map<String, dynamic>> _expenses = [];
  Map<String, dynamic>? _expenseSummary;
  List<Map<String, dynamic>> _userExpenseShares = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        _chatService.getGroupExpenses(widget.groupId),
        _chatService.getGroupExpenseSummary(widget.groupId),
        _chatService.getUserExpenseShares(),
      ]);

      if (mounted) {
        setState(() {
          _expenses = futures[0] as List<Map<String, dynamic>>;
          _expenseSummary = futures[1] as Map<String, dynamic>;
          _userExpenseShares = futures[2] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading expenses: $e')));
      }
    }
  }

  Future<void> _markAsPaid(String expenseShareId) async {
    try {
      await _chatService.markExpenseShareAsPaid(expenseShareId);
      await _loadData(); // Reload data
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Expenses - ${widget.groupName}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'All Expenses'),
            Tab(text: 'My Shares'),
          ],
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
                  _buildSummaryTab(theme),
                  _buildAllExpensesTab(theme),
                  _buildMySharesTab(theme),
                ],
              ),
    );
  }

  Widget _buildSummaryTab(ThemeData theme) {
    if (_expenseSummary == null) {
      return const Center(child: Text('No expense data available'));
    }

    final summary = _expenseSummary!;
    final totalExpenses = summary['total_expenses'] as double;
    final perPersonShare = summary['per_person_share'] as double;
    final memberBalances = summary['member_balances'] as Map<String, double>;
    final expenseCount = summary['expense_count'] as int;
    final members = summary['members'] as List<Map<String, dynamic>>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Total summary card
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Total Group Expenses',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '\$${totalExpenses.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      'Expenses',
                      expenseCount.toString(),
                      Icons.receipt,
                      theme.colorScheme.onPrimary,
                    ),
                    _buildSummaryItem(
                      'Per Person',
                      '\$${perPersonShare.toStringAsFixed(2)}',
                      Icons.person,
                      theme.colorScheme.onPrimary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Member balances
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Member Balances',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...memberBalances.entries.map((entry) {
                  final balance = entry.value;
                  final isPositive = balance > 0;
                  final isZero = balance == 0;

                  // Find member profile
                  final member = members.firstWhere(
                    (m) => m['user_id'] == entry.key,
                    orElse:
                        () => {
                          'profiles': {'display_name': 'Unknown Member'},
                        },
                  );
                  final memberName =
                      member['profiles']?['display_name'] ?? 'Unknown Member';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isZero
                              ? theme.colorScheme.surfaceVariant
                              : isPositive
                              ? theme.colorScheme.primaryContainer.withValues(
                                alpha: 0.3,
                              )
                              : theme.colorScheme.errorContainer.withValues(
                                alpha: 0.3,
                              ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isZero
                                ? theme.colorScheme.outline.withValues(
                                  alpha: 0.2,
                                )
                                : isPositive
                                ? theme.colorScheme.primary.withValues(
                                  alpha: 0.3,
                                )
                                : theme.colorScheme.error.withValues(
                                  alpha: 0.3,
                                ),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            memberName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          isZero
                              ? 'Settled up'
                              : '${isPositive ? '+' : ''}\$${balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                isZero
                                    ? theme.colorScheme.onSurfaceVariant
                                    : isPositive
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),

        // Payment Statistics with tappable sections
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.payment,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Payment Statistics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildPaymentStatistics(theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  Widget _buildAllExpensesTab(ThemeData theme) {
    if (_expenses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No expenses yet'),
            Text('Add your first expense to get started!'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final expense = _expenses[index];
        final paidByProfile = expense['profiles'] as Map<String, dynamic>?;
        final paidByName = paidByProfile?['display_name'] ?? 'Unknown';
        final amount = (expense['total_amount'] as num).toDouble();
        final createdAt = DateTime.parse(expense['created_at']);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => _showExpenseDetails(expense),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: const Icon(Icons.receipt, color: Colors.white),
              ),
              title: Text(expense['title'], style: theme.textTheme.titleMedium),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Paid by: $paidByName'),
                  if (expense['description'] != null)
                    Text(
                      expense['description'],
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              trailing: Text(
                '\$${amount.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: [_buildExpensePaymentStatus(expense['id'], theme)],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpensePaymentStatus(String expenseId, ThemeData theme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _chatService.getExpenseDetailsWithPaymentStatus(expenseId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Error loading payment status: ${snapshot.error}',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        final paymentDetails = snapshot.data ?? [];
        final paidMembers =
            paymentDetails
                .where((member) => member['is_paid'] == true)
                .toList();
        final unpaidMembers =
            paymentDetails
                .where((member) => member['is_paid'] == false)
                .toList();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Paid members section
              if (paidMembers.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Paid (${paidMembers.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children:
                      paidMembers.map((member) {
                        final profile =
                            member['profiles'] as Map<String, dynamic>?;
                        final displayName =
                            profile?['display_name'] ?? 'Unknown';
                        final amount =
                            (member['amount_owed'] as num).toDouble();

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '$displayName (\$${amount.toStringAsFixed(2)})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Unpaid members section
              if (unpaidMembers.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.pending, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Pending (${unpaidMembers.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children:
                      unpaidMembers.map((member) {
                        final profile =
                            member['profiles'] as Map<String, dynamic>?;
                        final displayName =
                            profile?['display_name'] ?? 'Unknown';
                        final amount =
                            (member['amount_owed'] as num).toDouble();

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '$displayName (\$${amount.toStringAsFixed(2)})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],

              // Summary
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Members:', style: theme.textTheme.bodySmall),
                    Text(
                      '${paymentDetails.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        final expense = share['expenses'] as Map<String, dynamic>;
        final group = expense['groups'] as Map<String, dynamic>;
        final paidByProfile = expense['profiles'] as Map<String, dynamic>?;
        final paidByName = paidByProfile?['display_name'] ?? 'Unknown';
        final amountOwed = (share['amount_owed'] as num).toDouble();
        final isPaid = share['is_paid'] as bool;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isPaid ? Colors.green : theme.colorScheme.primary,
              child: Icon(
                isPaid ? Icons.check : Icons.pending,
                color: Colors.white,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense['title'],
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Group: ${group['name']}',
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Paid by: $paidByName',
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isPaid ? 'Paid' : 'Pending',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isPaid ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '\$${amountOwed.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!isPaid)
                      Container(
                        constraints: const BoxConstraints(
                          maxWidth: 70,
                          minHeight: 24,
                        ),
                        child: TextButton(
                          onPressed: () => _markAsPaid(share['id']),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Mark Paid',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentStatistics(ThemeData theme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllExpenseSharesForGroup(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text(
            'Error loading payment statistics: ${snapshot.error}',
            style: TextStyle(color: theme.colorScheme.error),
          );
        }

        final allShares = snapshot.data ?? [];
        final totalShares = allShares.length;
        final paidShares =
            allShares.where((share) => share['is_paid'] == true).toList();
        final unpaidShares =
            allShares.where((share) => share['is_paid'] == false).toList();
        final paymentRate =
            totalShares > 0 ? (paidShares.length / totalShares * 100) : 0.0;

        return Column(
          children: [
            // Payment rate
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Rate',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${paymentRate.toStringAsFixed(1)}%',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.trending_up,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payment breakdown with tappable sections
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap:
                        () => _showMemberDetails(
                          paidShares,
                          'Paid Members',
                          theme,
                        ),
                    child: _buildStatCard(
                      'Paid',
                      paidShares.length.toString(),
                      Icons.check_circle,
                      theme.colorScheme.primary,
                      theme,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap:
                        () => _showMemberDetails(
                          unpaidShares,
                          'Pending Members',
                          theme,
                        ),
                    child: _buildStatCard(
                      'Pending',
                      unpaidShares.length.toString(),
                      Icons.pending,
                      theme.colorScheme.tertiary,
                      theme,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                unpaidShares.isNotEmpty
                    ? '${unpaidShares.length} expense shares still need to be paid'
                    : 'All expense shares have been paid! 🎉',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getAllExpenseSharesForGroup() async {
    try {
      // Get all expenses for this group
      final expenses = await _chatService.getGroupExpenses(widget.groupId);

      // Get all expense shares for these expenses
      final allShares = <Map<String, dynamic>>[];

      for (final expense in expenses) {
        final expenseShares = await _chatService
            .getExpenseDetailsWithPaymentStatus(expense['id']);
        allShares.addAll(expenseShares);
      }

      return allShares;
    } catch (e) {
      print('Error getting expense shares: $e');
      return [];
    }
  }

  void _showExpenseDetails(Map<String, dynamic> expense) {
    showExpenseDetailsModal(context, expense);
  }

  void _showMemberDetails(
    List<Map<String, dynamic>> shares,
    String title,
    ThemeData theme,
  ) {
    if (shares.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No $title to display')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 32,
                  offset: const Offset(0, -12),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  width: 56,
                  height: 6,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),

                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onPrimary.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          title.contains('Paid')
                              ? Icons.check_circle
                              : Icons.pending,
                          color: theme.colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onPrimary.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${shares.length} members',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: shares.length,
                    itemBuilder: (context, index) {
                      final share = shares[index];
                      final profile =
                          share['profiles'] as Map<String, dynamic>?;
                      final memberName =
                          profile?['display_name'] ?? 'Unknown Member';
                      final amount = (share['amount_owed'] as num).toDouble();
                      final isPaid = share['is_paid'] as bool;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isPaid
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.tertiary)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isPaid
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.tertiary)
                                    .withValues(alpha: 0.2),
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
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    memberName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    'Amount owed: \$${amount.toStringAsFixed(2)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              isPaid ? 'Paid' : 'Pending',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    isPaid
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.tertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
